import { LLMTool } from "../type";
import { readdirSync } from "fs";
import { resolve } from "path";
import { setVolumeByAmixer, getCurrentLogPercent } from "../utils/volume";
import { cloneDeep } from "lodash";
import { transformToGeminiType } from "../utils";
import dotenv from "dotenv";
import { addImageGenerationTools } from "./image-generation";
import {
  getAvailableModels,
  switchModel,
  getCurrentModel,
} from "../utils/llama-manager";
import axios from "axios";

dotenv.config();

const defaultTools: LLMTool[] = [
  {
    type: "function",
    function: {
      name: "setVolume",
      description: "set the volume level",
      parameters: {
        type: "object",
        properties: {
          percent: {
            type: "number",
            description: "the volume level to set (0-100)",
          },
        },
        required: ["percent"],
      },
    },
    func: async (params) => {
      const { percent } = params;
      if (percent >= 0 && percent <= 100) {
        setVolumeByAmixer(percent);
        return `Volume set to ${percent}%`;
      } else {
        console.error("Volume range error");
        return "Volume range error, please set between 0 and 100";
      }
    },
  },
  // increase volume
  {
    type: "function",
    function: {
      name: "increaseVolume",
      description: "increase the volume level by a specified amount",
      parameters: {},
    },
    func: async (params) => {
      const currentLogPercent = getCurrentLogPercent();
      if (currentLogPercent >= 100) {
        return "Volume is already at maximum";
      }
      const newAmixerValue = Math.min(currentLogPercent + 10, 100);
      setVolumeByAmixer(newAmixerValue);
      console.log(
        `Current volume: ${currentLogPercent}%, New volume: ${newAmixerValue}%`
      );
      return `Volume increased by 10%, now at ${newAmixerValue}%`;
    },
  },
  // decrease volume
  {
    type: "function",
    function: {
      name: "decreaseVolume",
      description: "decrease the volume level by a specified amount",
      parameters: {},
    },
    func: async (params) => {
      const currentLogPercent = getCurrentLogPercent();
      if (currentLogPercent <= 0) {
        return "Volume is already at minimum";
      }
      const newAmixerValue = Math.max(currentLogPercent - 10, 0);
      setVolumeByAmixer(newAmixerValue);
      console.log(
        `Current volume: ${currentLogPercent}%, New volume: ${newAmixerValue}%`
      );
      return `Volume decreased by 10%, now at ${newAmixerValue}%`;
    },
  },
  // Web search tool
  {
    type: "function",
    function: {
      name: "webSearch",
      description:
        "Search DuckDuckGo for information when you don't have current or specific information. Use this for: recent events, current facts, specific data you're unsure about, technical documentation, or any information you don't have in your training data.",
      parameters: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description:
              "The search query to look up on DuckDuckGo. Be specific and concise.",
          },
        },
        required: ["query"],
      },
    },
    func: async (params) => {
      const { query } = params;
      try {
        console.log(`[WebSearch] Searching for: ${query}`);
        
        // Use DuckDuckGo's HTML API (no API key required)
        const response = await axios.get("https://html.duckduckgo.com/html/", {
          params: { q: query },
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          },
          timeout: 10000,
        });

        // Parse the HTML response to extract search results
        const html = response.data;
        const results: string[] = [];
        
        // Simple regex to extract result snippets (DuckDuckGo HTML structure)
        // Look for result snippets in the HTML
        const snippetRegex = /<a class="result__snippet"[^>]*>([\s\S]*?)<\/a>/gi;
        let match;
        let count = 0;
        
        while ((match = snippetRegex.exec(html)) !== null && count < 3) {
          // Clean HTML tags and entities
          let snippet = match[1]
            .replace(/<[^>]*>/g, "") // Remove HTML tags
            .replace(/&quot;/g, '"')
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&#39;/g, "'")
            .replace(/\s+/g, " ") // Normalize whitespace
            .trim();
          
          if (snippet && snippet.length > 20) {
            results.push(snippet);
            count++;
          }
        }

        if (results.length === 0) {
          console.log("[WebSearch] No results found");
          return `No search results found for "${query}". The information might not be available or try rephrasing the query.`;
        }

        const resultText = results
          .map((result, index) => `${index + 1}. ${result}`)
          .join("\n\n");
        
        console.log(`[WebSearch] Found ${results.length} results`);
        return `Search results for "${query}":\n\n${resultText}`;
      } catch (error: any) {
        console.error("[WebSearch] Error:", error.message);
        return `Unable to perform web search: ${error.message}. Please try again or rephrase your query.`;
      }
    },
  },
  // Switch LLM model
  {
    type: "function",
    function: {
      name: "switchModel",
      description:
        "Switch to a different language model. Use this when the user asks to change, switch, or use a different model. The model name can be partial (e.g., 'qwen', 'llama', 'mistral').",
      parameters: {
        type: "object",
        properties: {
          modelName: {
            type: "string",
            description:
              "The name or partial name of the model to switch to (e.g., 'Qwen3-1.7B', 'llama-3', 'mistral')",
          },
        },
        required: ["modelName"],
      },
    },
    func: async (params) => {
      const { modelName } = params;
      return await switchModel(modelName);
    },
  },
  // List available models
  {
    type: "function",
    function: {
      name: "listModels",
      description:
        "List all available language models that can be switched to. Use this when the user asks what models are available.",
      parameters: {},
    },
    func: async (params) => {
      const models = getAvailableModels();
      const currentModel = getCurrentModel();
      
      if (models.length === 0) {
        return "No models found in the models directory.";
      }
      
      const modelList = models
        .map((m) => {
          const isCurrent = m.name === currentModel;
          return `${isCurrent ? "➤ " : "  "}${m.name}${isCurrent ? " (current)" : ""}`;
        })
        .join("\n");
      
      return `Available models:\n${modelList}`;
    },
  },
];

addImageGenerationTools(defaultTools);

// If there is a custom-tools folder, collect all tools exported from files in the custom-tools folder
const customTools: LLMTool[] = [];
const customToolsFolderPath = resolve(__dirname, "./custom-tools");
try {
  // Iterate through all files in the custom-tools folder
  readdirSync(customToolsFolderPath).forEach((file) => {
    const filePath = resolve(customToolsFolderPath, file);
    // Only process .ts and .js files
    if (file.endsWith(".ts") || file.endsWith(".js")) {
      try {
        // Dynamically import the file
        const toolModule = require(filePath);
        if (toolModule.default && Array.isArray(toolModule.default)) {
          customTools.push(...toolModule.default);
        } else if (toolModule.llmTools && Array.isArray(toolModule.llmTools)) {
          customTools.push(...toolModule.llmTools);
        }
      } catch (error) {
        console.error(`Error loading tool from ${filePath}:`, error);
      }
    }
  });
} catch (error) {
  console.error("Error loading custom tools:", error);
}

// remove geminiType from parameters for OpenAI compatibility
export const llmTools: LLMTool[] = [...defaultTools, ...customTools];

export const llmToolsForGemini: LLMTool[] = [
  ...defaultTools,
  ...customTools,
].map((tool) => {
  const newTool = cloneDeep(tool);
  if (newTool.function && newTool.function.parameters) {
    newTool.function.parameters = transformToGeminiType(
      newTool.function.parameters
    );
  }
  return newTool;
});

export const llmFuncMap = llmTools.reduce((acc, tool) => {
  acc[tool.function.name] = tool.func;
  return acc;
}, {} as Record<string, (params: any) => Promise<string>>);
