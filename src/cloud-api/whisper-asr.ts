import fs from "fs";
import { spawn } from "child_process";
import { resolve as pathResolve } from "path";
import { ASRServer } from "../type";

const modelSize = process.env.WHISPER_MODEL_SIZE || "tiny";
const language = process.env.WHISPER_LANGUAGE || "";
const device = process.env.WHISPER_DEVICE || "cpu";
const computeType = process.env.WHISPER_COMPUTE_TYPE || "int8";
const asrServer = (process.env.ASR_SERVER || "").toLowerCase() as ASRServer;

let isFasterWhisperInstall = false;
export const checkFasterWhisperInstallation = (): boolean => {
  // Check if faster-whisper Python script is available
  const scriptPath = pathResolve(__dirname, "../../python/faster_whisper_asr.py");
  if (!fs.existsSync(scriptPath)) {
    console.error(
      "faster-whisper script not found at:", scriptPath
    );
    return false;
  }
  isFasterWhisperInstall = true;
  return true;
};

if (asrServer === ASRServer.whisper) {
  checkFasterWhisperInstallation();
}

export const recognizeAudio = async (
  audioFilePath: string
): Promise<string> => {
  if (!isFasterWhisperInstall) {
    console.error("Faster-Whisper is not installed.");
    return "";
  }
  if (!modelSize) {
    console.error("WHISPER_MODEL_SIZE is not set.");
    return "";
  }
  if (!fs.existsSync(audioFilePath)) {
    console.error("Audio file does not exist:", audioFilePath);
    return "";
  }

  return await new Promise<string>((resolve) => {
    const scriptPath = pathResolve(__dirname, "../../python/faster_whisper_asr.py");
    
    // Build command arguments
    const params = [
      scriptPath,
      audioFilePath,
      "--model",
      modelSize,
      "--device",
      device,
      "--compute-type",
      computeType,
    ];
    
    if (language) {
      params.push("--language", language);
    }
    
    // Use python3 to run the script
    const child = spawn("python3", params);

    let stdout = "";
    let stderr = "";

    child.stdout?.setEncoding("utf8");
    child.stdout?.on("data", (chunk: string) => {
      stdout += chunk;
    });

    child.stderr?.setEncoding("utf8");
    child.stderr?.on("data", (chunk: string) => {
      stderr += chunk;
    });

    child.on("error", (err) => {
      console.error("Failed to start faster-whisper:", err?.message ?? err);
      resolve("");
    });

    child.on("close", async (code, signal) => {
      if (stderr && stderr.trim()) {
        // Some warnings may be output to stderr
        console.error("faster-whisper stderr:", stderr.trim());
      }
      if (code !== 0) {
        console.error(
          `faster-whisper exited with code ${code}${signal ? ` (signal ${signal})` : ""}`
        );
        resolve("");
        return;
      }

      const transcription = stdout ? stdout.trim() : "";
      
      if (transcription) {
        resolve(transcription);
        return;
      }

      // No stdout content
      resolve("");
    });
  });
};
