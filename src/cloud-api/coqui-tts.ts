import * as fs from "fs";
import * as path from "path";
import { spawn } from "child_process";
import { getWavFileDurationMs } from "../utils";
import dotenv from "dotenv";
import { ttsDir } from "../utils/dir";

dotenv.config();

const pythonCommand = process.env.PYTHON_COMMAND || "python3";
const coquiScript = path.join(__dirname, "../../python/coqui_tts.py");
const coquiModel = process.env.COQUI_TTS_MODEL || "tts_models/en/ljspeech/tacotron2-DDC";
const coquiSpeaker = process.env.COQUI_TTS_SPEAKER || undefined;
const coquiLanguage = process.env.COQUI_TTS_LANGUAGE || undefined;
const coquiGpu = process.env.COQUI_TTS_GPU === "true";

const coquiTTS = async (
  text: string
): Promise<{ data: string; duration: number }> => {
  return new Promise((resolve, reject) => {
    const tempWavFile = path.join(ttsDir, `coqui_${Date.now()}.wav`);
    
    const args = [
      coquiScript,
      "-t", text,
      "-o", tempWavFile,
      "-m", coquiModel,
    ];
    
    if (coquiSpeaker) {
      args.push("-s", coquiSpeaker);
    }
    
    if (coquiLanguage) {
      args.push("-l", coquiLanguage);
    }
    
    if (coquiGpu) {
      args.push("--gpu");
    }
    
    const coquiProcess = spawn(pythonCommand, args);

    let stderrOutput = "";

    coquiProcess.stderr.on("data", (data) => {
      stderrOutput += data.toString();
    });

    coquiProcess.on("close", async (code: number) => {
      if (code !== 0) {
        console.error(`Coqui TTS process exited with code ${code}`);
        console.error("Error output:", stderrOutput);
        resolve({ data: "", duration: 0 });
        return;
      }

      if (fs.existsSync(tempWavFile) === false) {
        console.log("Coqui TTS output file not found:", tempWavFile);
        resolve({ data: "", duration: 0 });
        return;
      }

      try {
        const buffer = await fs.readFileSync(tempWavFile);
        const duration = await getWavFileDurationMs(buffer);

        // Clean up temp file
        await fs.unlinkSync(tempWavFile);

        // For Coqui TTS, keep the WAV header for aplay to auto-detect format
        // Convert to base64 string for playback
        const base64Data = buffer.toString('base64');
        resolve({ data: base64Data, duration });
      } catch (error) {
        console.log("Error processing Coqui TTS output:", `"${text}"`, error);
        resolve({ data: "", duration: 0 });
      }
    });

    coquiProcess.on("error", (error: any) => {
      console.log("Coqui TTS process error:", `"${text}"`, error);
      resolve({ data: "", duration: 0 });
    });
  });
};

export default coquiTTS;
