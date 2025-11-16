import { spawn } from "child_process";
import path from "path";
import fs from "fs";

export interface SpeakerSegment {
  speakerId: number;
  startTime: number;
  endTime: number;
}

export interface DiarizationResult {
  segments: SpeakerSegment[];
  numSpeakers: number;
}

/**
 * Run speaker diarization on an audio file
 * 
 * @param audioPath Path to the audio file (WAV format)
 * @param numSpeakers Optional: number of speakers (auto-detect if not provided)
 * @returns Promise with speaker segments
 */
export const diarizeAudio = async (
  audioPath: string,
  numSpeakers?: number
): Promise<DiarizationResult> => {
  return new Promise((resolve, reject) => {
    if (!fs.existsSync(audioPath)) {
      reject(new Error(`Audio file not found: ${audioPath}`));
      return;
    }

    const scriptPath = path.resolve(__dirname, "../../python/speaker_diarization.py");
    const pythonArgs = [scriptPath, audioPath];

    if (numSpeakers) {
      pythonArgs.push("--num-speakers", String(numSpeakers));
    }

    // Use JSON output format for easy parsing
    pythonArgs.push("--output-json");

    console.log(`[DIARIZATION] Running: python3 ${pythonArgs.join(" ")}`);

    const child = spawn("python3", pythonArgs);

    let stdout = "";
    let stderr = "";

    child.stdout?.setEncoding("utf8");
    child.stdout?.on("data", (chunk: string) => {
      stdout += chunk;
    });

    child.stderr?.setEncoding("utf8");
    child.stderr?.on("data", (chunk: string) => {
      stderr += chunk;
      // Log progress messages
      if (chunk.includes("[") && !chunk.includes("Error")) {
        console.log(`[DIARIZATION] ${chunk.trim()}`);
      }
    });

    child.on("error", (err) => {
      console.error("[DIARIZATION] Failed to start:", err.message);
      reject(err);
    });

    child.on("close", (code) => {
      if (code !== 0) {
        console.error(`[DIARIZATION] Exited with code ${code}`);
        console.error(`[DIARIZATION] stderr:`, stderr);
        reject(new Error(`Diarization failed with code ${code}: ${stderr}`));
        return;
      }

      try {
        // Parse JSON output
        const lines = stdout.trim().split("\n");
        const jsonLine = lines.find(line => line.startsWith("{"));
        
        if (!jsonLine) {
          throw new Error("No JSON output found");
        }

        const result = JSON.parse(jsonLine);
        
        // Convert to our format
        const segments: SpeakerSegment[] = result.segments.map((seg: any) => ({
          speakerId: seg.speaker_id,
          startTime: seg.start_time,
          endTime: seg.end_time,
        }));

        const numDetectedSpeakers = result.num_speakers || 
          new Set(segments.map(s => s.speakerId)).size;

        console.log(`[DIARIZATION] Found ${numDetectedSpeakers} speakers, ${segments.length} segments`);

        resolve({
          segments,
          numSpeakers: numDetectedSpeakers,
        });
      } catch (err: any) {
        console.error("[DIARIZATION] Failed to parse output:", err.message);
        console.error("[DIARIZATION] stdout:", stdout);
        reject(new Error(`Failed to parse diarization output: ${err.message}`));
      }
    });
  });
};

/**
 * Extract audio segment from file
 * Uses sox to extract a specific time range
 */
export const extractAudioSegment = async (
  inputPath: string,
  outputPath: string,
  startTime: number,
  duration: number
): Promise<void> => {
  return new Promise((resolve, reject) => {
    const args = [
      inputPath,
      outputPath,
      "trim",
      String(startTime),
      String(duration),
    ];

    const child = spawn("sox", args);

    let stderr = "";

    child.stderr?.setEncoding("utf8");
    child.stderr?.on("data", (chunk: string) => {
      stderr += chunk;
    });

    child.on("error", (err) => {
      reject(new Error(`sox not available: ${err.message}`));
    });

    child.on("close", (code) => {
      if (code !== 0) {
        reject(new Error(`sox failed: ${stderr}`));
        return;
      }
      resolve();
    });
  });
};
