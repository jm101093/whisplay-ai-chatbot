import { noop } from "lodash";
import dotenv from "dotenv";
import { ASRServer, ImageGenerationServer, LLMServer, TTSServer } from "../type";
import { recognizeAudio as VolcengineASR } from "./volcengine-asr";
import {
  recognizeAudio as TencentASR,
  synthesizeSpeech as TencentTTS,
} from "./tencent-cloud";
import { recognizeAudio as OpenAIASR } from "./openai-asr";
import { recognizeAudio as GeminiASR } from "./gemini-asr";
import { recognizeAudio as VoskASR } from "./vosk-asr";
import { recognizeAudio as WisperASR } from "./whisper-asr";
import {
  chatWithLLMStream as VolcengineLLMStream,
  resetChatHistory as VolcengineResetChatHistory,
} from "./volcengine-llm";
import {
  chatWithLLMStream as OpenAILLMStream,
  resetChatHistory as OpenAIResetChatHistory,
} from "./openai-llm";
import {
  chatWithLLMStream as GeminiLLMStream,
  resetChatHistory as GeminiResetChatHistory,
} from "./gemini-llm";
import VolcengineTTS from "./volcengine-tts";
import OpenAITTS from "./openai-tts";
import geminiTTS from "./gemini-tts";
import {
  ChatWithLLMStreamFunction,
  RecognizeAudioFunction,
  ResetChatHistoryFunction,
  TTSProcessorFunction,
} from "./interface";
import piperTTS from "./piper-tts";
import coquiTTS from "./coqui-tts";
import { diarizeAudio, extractAudioSegment } from "./diarization";
import { translateModePrompt } from "../config/llm-config";
import path from "path";
import fs from "fs";
import os from "os";

dotenv.config();

let recognizeAudio: RecognizeAudioFunction = noop as any;
let chatWithLLMStream: ChatWithLLMStreamFunction = noop as any;
let ttsProcessor: TTSProcessorFunction = noop as any;
let resetChatHistory: ResetChatHistoryFunction = noop as any;

export const asrServer: ASRServer = (
  process.env.ASR_SERVER || ASRServer.tencent
).toLowerCase() as ASRServer;
export const llmServer: LLMServer = (
  process.env.LLM_SERVER || LLMServer.volcengine
).toLowerCase() as LLMServer;
export const ttsServer: TTSServer = (
  process.env.TTS_SERVER || TTSServer.volcengine
).toLowerCase() as TTSServer;
export const imageGenerationServer: ImageGenerationServer = (
  process.env.IMAGE_GENERATION_SERVER || ""
).toLowerCase() as ImageGenerationServer;

console.log(`Current ASR Server: ${asrServer}`);
console.log(`Current LLM Server: ${llmServer}`);
console.log(`Current TTS Server: ${ttsServer}`);
if (imageGenerationServer) console.log(`Current Image Generation Server: ${imageGenerationServer}`);

switch (asrServer) {
  case ASRServer.volcengine:
    recognizeAudio = VolcengineASR;
    break;
  case ASRServer.tencent:
    recognizeAudio = TencentASR;
    break;
  case ASRServer.openai:
    recognizeAudio = OpenAIASR;
    break;
  case ASRServer.gemini:
    recognizeAudio = GeminiASR;
    break;
  case ASRServer.vosk:
    recognizeAudio = VoskASR;
    break;
  case ASRServer.whisper:
    recognizeAudio = WisperASR;
    break
  default:
    console.warn(
      `unknown asr server: ${asrServer}, should be VOLCENGINE/TENCENT/OPENAI/GEMINI/VOSK/WHISPER`
    );
    break;
}

switch (llmServer) {
  case LLMServer.volcengine:
    chatWithLLMStream = VolcengineLLMStream;
    resetChatHistory = VolcengineResetChatHistory;
    break;
  case LLMServer.openai:
    chatWithLLMStream = OpenAILLMStream;
    resetChatHistory = OpenAIResetChatHistory;
    break;
  case LLMServer.gemini:
    chatWithLLMStream = GeminiLLMStream;
    resetChatHistory = GeminiResetChatHistory;
    break;
  default:
    console.warn(
      `unknown llm server: ${llmServer}, should be VOLCENGINE/OPENAI/GEMINI (use OPENAI for vLLM)`
    );
    break;
}

switch (ttsServer) {
  case TTSServer.volcengine:
    ttsProcessor = VolcengineTTS;
    break;
  case TTSServer.openai:
    ttsProcessor = OpenAITTS;
    break;
  case TTSServer.tencent:
    ttsProcessor = TencentTTS;
    break;
  case TTSServer.gemini:
    ttsProcessor = geminiTTS;
    break;
  case TTSServer.piper:
    ttsProcessor = piperTTS;
    break;
  case TTSServer.coqui:
    ttsProcessor = coquiTTS;
    break;
  default:
    console.warn(
      `unknown tts server: ${ttsServer}, should be VOLCENGINE/TENCENT/OPENAI/GEMINI/PIPER/COQUI`
    );
    break;
}

/**
 * Translate conversation with speaker diarization
 * 
 * This function:
 * 1. Runs speaker diarization on the audio file
 * 2. Extracts each speaker's audio segments
 * 3. Runs ASR on each segment
 * 4. Formats with speaker labels
 * 5. Sends to LLM for translation
 * 
 * @param audioFilePath Path to the recorded audio file
 * @param onPartial Callback for streaming partial translation responses
 * @param onEnd Callback when translation is complete
 * @param onThinking Optional callback for thinking process
 */
export const translateWithDiarization = async (
  audioFilePath: string,
  onPartial: (text: string) => void,
  onEnd: () => void,
  onThinking?: (thinking: string) => void
): Promise<void> => {
  try {
    console.log("[TRANSLATE] Starting diarization...");
    
    // Step 1: Run speaker diarization
    const diarizationResult = await diarizeAudio(audioFilePath);
    
    console.log(`[TRANSLATE] Found ${diarizationResult.numSpeakers} speakers, ${diarizationResult.segments.length} segments`);
    
    // Step 2: Extract and transcribe each speaker segment
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "whisplay-segments-"));
    const transcriptions: Array<{ speakerId: number; text: string; start: number; end: number }> = [];
    
    for (const segment of diarizationResult.segments) {
      const segmentFile = path.join(tmpDir, `speaker${segment.speakerId}_${segment.startTime}.wav`);
      const duration = segment.endTime - segment.startTime;
      
      try {
        // Extract audio segment
        await extractAudioSegment(audioFilePath, segmentFile, segment.startTime, duration);
        
        // Transcribe segment
        const text = await recognizeAudio(segmentFile);
        
        if (text) {
          transcriptions.push({
            speakerId: segment.speakerId,
            text: text.trim(),
            start: segment.startTime,
            end: segment.endTime,
          });
          console.log(`[TRANSLATE] Speaker ${segment.speakerId}: "${text}"`);
        }
        
        // Clean up segment file
        fs.unlinkSync(segmentFile);
      } catch (err) {
        console.error(`[TRANSLATE] Failed to process segment:`, err);
      }
    }
    
    // Clean up temp directory
    fs.rmdirSync(tmpDir);
    
    if (transcriptions.length === 0) {
      console.error("[TRANSLATE] No transcriptions generated");
      onPartial("No speech detected in the audio.");
      onEnd();
      return;
    }
    
    // Step 3: Format speaker-labeled input for LLM
    const speakerTexts = transcriptions
      .map(t => `[Speaker ${t.speakerId}]: ${t.text}`)
      .join("\n");
    
    console.log("[TRANSLATE] Formatted input:\n" + speakerTexts);
    
    // Step 4: Send to LLM with translate mode prompt
    // Temporarily override system prompt for this request
    const originalSystemPrompt = process.env.SYSTEM_PROMPT;
    process.env.SYSTEM_PROMPT = translateModePrompt;
    
    try {
      await chatWithLLMStream(
        [
          {
            role: "user",
            content: speakerTexts,
          },
        ],
        onPartial,
        onEnd,
        onThinking
      );
    } finally {
      // Restore original system prompt
      if (originalSystemPrompt) {
        process.env.SYSTEM_PROMPT = originalSystemPrompt;
      } else {
        delete process.env.SYSTEM_PROMPT;
      }
    }
  } catch (error) {
    console.error("[TRANSLATE] Error:", error);
    onPartial("Translation failed. Please try again.");
    onEnd();
  }
};

export { recognizeAudio, chatWithLLMStream, ttsProcessor, resetChatHistory, translateWithDiarization };

