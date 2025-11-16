import dotenv from "dotenv";
import * as fs from "fs";
import * as path from "path";
import { isEmpty } from "lodash";
import moment from "moment";
import {
  shouldResetChatHistory,
  systemPrompt,
  updateLastMessageTime,
} from "../config/llm-config";
import { FunctionCall, Message } from "../type";
import { combineFunction } from "../utils";
import { openai } from "./openai"; // Assuming openai is exported from openai.ts
import { llmFuncMap, llmTools } from "../config/llm-tools";
import { ChatWithLLMStreamFunction } from "./interface";
import { chatHistoryDir } from "../utils/dir";

dotenv.config();
// OpenAI LLM
const openaiLLMModel = process.env.OPENAI_LLM_MODEL || "gpt-4o"; // Default model
const enableThinking = process.env.ENABLE_THINKING === "true"; // Enable thinking/reasoning mode

const chatHistoryFileName = `openai_chat_history_${moment().format(
  "YYYYMMDD_HHmmss"
)}.json`;

const messages: Message[] = [
  {
    role: "system",
    content: systemPrompt,
  },
];

const resetChatHistory = (): void => {
  messages.length = 0;
  messages.push({
    role: "system",
    content: systemPrompt,
  });
};

const chatWithLLMStream: ChatWithLLMStreamFunction = async (
  inputMessages: Message[] = [],
  partialCallback: (partial: string) => void,
  endCallback: () => void,
  partialThinkingCallback?: (partialThinking: string) => void
): Promise<void> => {
  if (!openai) {
    console.error("OpenAI API key is not set.");
    return;
  }
  if (shouldResetChatHistory()) {
    resetChatHistory();
  }
  updateLastMessageTime();
  let endResolve: () => void = () => {};
  const promise = new Promise<void>((resolve) => {
    endResolve = resolve;
  }).finally(() => {
    fs.writeFileSync(
      path.join(chatHistoryDir, chatHistoryFileName),
      JSON.stringify(messages, null, 2)
    );
  });
  messages.push(...inputMessages);
  
  console.log(`[LLM] Starting chat completion with model: ${openaiLLMModel}`);
  console.log(`[LLM] Thinking mode enabled: ${enableThinking}`);
  console.log(`[LLM] Message count: ${messages.length}`);
  
  const chatCompletion = await openai.chat.completions.create({
    model: openaiLLMModel,
    messages: messages as any,
    stream: true,
    tools: llmTools,
    ...(enableThinking ? { 
      // For reasoning models like Qwen3, enable thinking
      prediction: { type: "content", content: [{ type: "text", text: "" }] }
    } : {})
  });
  
  console.log(`[LLM] Stream started, processing chunks...`);
  
  let partialAnswer = "";
  let partialThinking = "";
  const functionCallsPackages: any[] = [];
  let chunkCount = 0;
  
  for await (const chunk of chatCompletion) {
    chunkCount++;
    if (chunkCount % 10 === 0) {
      console.log(`[LLM] Processed ${chunkCount} chunks`);
    }
    
    // Debug: Log what's in each chunk for first 10 chunks
    if (chunkCount <= 10) {
      console.log(`[LLM DEBUG] Chunk ${chunkCount}:`, JSON.stringify(chunk.choices[0].delta));
    }
    
    // Check for reasoning_content (chain of thought tokens)
    const delta = chunk.choices[0].delta as any;
    if (delta.reasoning_content && partialThinkingCallback) {
      partialThinkingCallback(delta.reasoning_content);
      console.log(`[LLM] Reasoning: ${delta.reasoning_content}`);
    }
    
    // Check if this chunk has tool calls
    if (chunk.choices[0].delta.tool_calls) {
      const toolCalls = chunk.choices[0].delta.tool_calls;
      functionCallsPackages.push(...toolCalls);
      
      // Show thinking with actual tool call details as they stream
      if (partialThinkingCallback) {
        for (const toolCall of toolCalls) {
          if (toolCall.function?.name) {
            partialThinkingCallback(`\nCalling function: ${toolCall.function.name}`);
            console.log(`[LLM] Tool call name: ${toolCall.function.name}`);
          }
          if (toolCall.function?.arguments) {
            // Arguments come in chunks, show them as they arrive
            partialThinkingCallback(toolCall.function.arguments);
            console.log(`[LLM] Tool call args chunk: ${toolCall.function.arguments}`);
          }
        }
      }
    }
    
    if (chunk.choices[0].delta.content) {
      const content = chunk.choices[0].delta.content;
      
      // For reasoning models, the model might think internally without explicit tags
      // Show all content as "thinking" when there's no answer yet and we're early in the response
      if (enableThinking && partialAnswer.length === 0 && chunkCount < 100) {
        // First chunks are likely thinking
        if (partialThinkingCallback) {
          partialThinkingCallback(content);
          console.log(`[LLM] Thinking chunk ${chunkCount}: ${content.substring(0, 50)}...`);
        }
      }
      
      // Always add to answer for final result
      partialCallback(content);
      partialAnswer += content;
    }
  }
  
  console.log(`[LLM] Stream completed after ${chunkCount} chunks`);
  console.log(`[LLM] Answer length: ${partialAnswer.length} chars`);
  console.log(`[LLM] Function calls: ${functionCallsPackages.length}`);
  
  const answer = partialAnswer;
  const functionCalls = combineFunction(functionCallsPackages);
  messages.push({
    role: "assistant",
    content: answer,
    tool_calls: isEmpty(functionCalls) ? undefined : functionCalls,
  });
  if (!isEmpty(functionCalls)) {
    console.log(`[LLM] Executing ${functionCalls.length} function calls`);
    
    // Show thinking while executing functions
    if (partialThinkingCallback) {
      partialThinkingCallback(`\n\nExecuting ${functionCalls.length} action${functionCalls.length > 1 ? 's' : ''}...`);
    }
    
    const results = await Promise.all(
      functionCalls.map(async (call: FunctionCall) => {
        const {
          function: { arguments: argString, name },
          id,
        } = call;
        console.log(`[LLM] Calling function: ${name} with args: ${argString}`);
        let args: Record<string, any> = {};
        try {
          args = JSON.parse(argString || "{}");
        } catch {
          console.error(
            `[LLM ERROR] Error parsing arguments for function ${name}:`,
            argString
          );
        }
        const func = llmFuncMap[name! as string];
        if (func) {
          const result = await func(args);
          console.log(`[LLM] Function ${name} returned: ${typeof result === 'string' ? result.substring(0, 100) : JSON.stringify(result)}`);
          return [id, result];
        } else {
          console.error(`[LLM ERROR] Function ${name} not found`);
          return [id, `Function ${name} not found`];
        }
      })
    );

    console.log(`[LLM] All function calls completed, recursing with results`);
    const newMessages: Message[] = results.map(([id, result]: any) => ({
      role: "tool",
      content: result as string,
      tool_call_id: id as string,
    }));

    await chatWithLLMStream(newMessages, partialCallback, () => {
      endResolve();
      endCallback();
    }, partialThinkingCallback);
    return;
  } else {
    endResolve();
    endCallback();
  }
  return promise;
};

export { chatWithLLMStream, resetChatHistory };
