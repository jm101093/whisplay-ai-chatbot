import { getCurrentTimeTag, splitSentences } from "./../utils/index";
import { get, noop } from "lodash";
import {
  onButtonPressed,
  onButtonReleased,
  display,
  getCurrentStatus,
} from "../device/display";
import { recordAudioManually, recordFileFormat } from "../device/audio";
import {
  recognizeAudio,
  chatWithLLMStream,
  ttsProcessor,
  translateWithDiarization,
} from "../cloud-api/server";
import { extractEmojis } from "../utils";
import { StreamResponser } from "./StreamResponsor";
import { recordingsDir } from "../utils/dir";
import { getLatestGenImg } from "../utils/image";

class ChatFlow {
  currentFlowName: string = "";
  recordingsDir: string = "";
  currentRecordFilePath: string = "";
  asrText: string = "";
  streamResponser: StreamResponser;
  partialThinking: string = "";
  thinkingSentences: string[] = [];
  answerId: number = 0;
  translateMode: boolean = false;

  constructor() {
    console.log(`[${getCurrentTimeTag()}] ChatBot started.`);
    this.recordingsDir = recordingsDir;
    this.setCurrentFlow("sleep");
    this.streamResponser = new StreamResponser(
      ttsProcessor,
      (sentences: string[]) => {
        if (this.currentFlowName !== "answer") return;
        const fullText = sentences.join(" ");
        display({
          status: "answering",
          emoji: extractEmojis(fullText) || "😊",
          text: fullText,
          RGB: "#0000ff",
          scroll_speed: 3,
        });
      },
      (text: string) => {
        if (this.currentFlowName !== "answer") return;
        display({
          status: "answering",
          text: text || undefined,
          scroll_speed: 3,
        });
      }
    );
  }

  partialThinkingCallback = (
    partialThinking: string,
    answerId: number
  ): void => {
    if (this.currentFlowName !== "answer" || answerId < this.answerId) return;
    this.partialThinking += partialThinking;
    const { sentences, remaining } = splitSentences(this.partialThinking);
    if (sentences.length > 0) {
      this.thinkingSentences.push(...sentences);
      const displayText = this.thinkingSentences.join(" ");
      display({
        status: "Thinking",
        emoji: "🤔",
        text: displayText,
        RGB: "#ff6800", // yellow
        scroll_speed: 6,
      });
    }
    this.partialThinking = remaining;
  };

  setCurrentFlow = (flowName: string): void => {
    console.log(`[${getCurrentTimeTag()}] switch to:`, flowName);
    switch (flowName) {
      case "sleep":
        this.currentFlowName = "sleep";
        onButtonPressed(() => {
          this.setCurrentFlow("listening");
        });
        onButtonReleased(noop);
        display({
          status: "idle",
          emoji: "😴",
          RGB: "#000055",
          ...(getCurrentStatus().text === "Listening..."
            ? {
                text: "Press the button to start",
              }
            : {}),
        });
        break;
      case "listening":
        this.currentFlowName = "listening";
        this.currentRecordFilePath = `${
          this.recordingsDir
        }/user-${Date.now()}.${recordFileFormat}`;
        onButtonPressed(noop);
        const { result, stop } = recordAudioManually(
          this.currentRecordFilePath
        );
        onButtonReleased(() => {
          stop();
          display({
            RGB: "#ff6800", // yellow
          });
        });
        result.then(() => {
          this.setCurrentFlow("asr");
        });
        display({
          status: "listening",
          emoji: "😐",
          RGB: "#00ff00",
          text: "Listening...",
        });
        break;
      case "asr":
        this.currentFlowName = "asr";
        display({
          status: "recognizing",
        });
        Promise.race([
          recognizeAudio(this.currentRecordFilePath),
          new Promise<string>((resolve) => {
            onButtonPressed(() => {
              resolve("[UserPress]");
            });
            onButtonReleased(noop);
          }),
        ]).then((result) => {
          if (this.currentFlowName !== "asr") return;
          if (result === "[UserPress]") {
            this.setCurrentFlow("listening");
          } else {
            if (result) {
              console.log("Audio recognized result:", result);
              
              // Check for translate mode activation (exact phrase)
              const lowerResult = result.toLowerCase().trim();
              const isTranslateModeCommand = 
                lowerResult === "translate mode" ||
                lowerResult === "translation mode" ||
                lowerResult === "activate translate mode" ||
                lowerResult === "enable translate mode" ||
                lowerResult === "turn on translate mode";
              
              if (isTranslateModeCommand) {
                this.translateMode = true;
                display({
                  status: "idle",
                  emoji: "🌍",
                  RGB: "#ff00ff", // Purple for translate mode
                  text: "Translate Mode Active",
                });
                console.log("✓ Translate mode activated");
                setTimeout(() => this.setCurrentFlow("sleep"), 2000);
                return;
              }
              
              // Check for translate mode deactivation (exact phrase)
              const isNormalModeCommand =
                lowerResult === "normal mode" ||
                lowerResult === "chat mode" ||
                lowerResult === "disable translate mode" ||
                lowerResult === "deactivate translate mode" ||
                lowerResult === "turn off translate mode";
              
              if (isNormalModeCommand) {
                this.translateMode = false;
                display({
                  status: "idle",
                  emoji: "😊",
                  RGB: "#000055",
                  text: "Normal Chat Mode",
                });
                console.log("✓ Translate mode deactivated");
                setTimeout(() => this.setCurrentFlow("sleep"), 2000);
                return;
              }
              
              this.asrText = result;
              display({ status: "recognizing", text: result });
              
              // Route to translate or answer flow based on mode
              if (this.translateMode) {
                this.setCurrentFlow("translate");
              } else {
                this.setCurrentFlow("answer");
              }
            } else {
              this.setCurrentFlow("sleep");
            }
          }
        });
        break;
      case "answer":
        display({
          RGB: "#00c8a3",
        });
        this.currentFlowName = "answer";
        this.answerId += 1;
        const currentAnswerId = this.answerId;
        onButtonPressed(() => {
          this.setCurrentFlow("listening");
        });
        onButtonReleased(noop);
        const {
          partial,
          endPartial,
          getPlayEndPromise,
          stop: stopPlaying,
        } = this.streamResponser;
        this.partialThinking = "";
        this.thinkingSentences = [];
        chatWithLLMStream(
          [
            {
              role: "user",
              content: this.asrText,
            },
          ],
          (text) => partial(text, currentAnswerId),
          () => endPartial(currentAnswerId),
          (partialThinking) =>
            this.partialThinkingCallback(partialThinking, currentAnswerId)
        );
        getPlayEndPromise().then(() => {
          if (this.currentFlowName === "answer") {
            const img = getLatestGenImg();
            if (img) {
              display({
                image: img,
              });
              this.setCurrentFlow("image");
            } else {
              this.setCurrentFlow("sleep");
            }
          }
        });
        onButtonPressed(() => {
          stopPlaying();
          this.setCurrentFlow("listening");
        });
        onButtonReleased(noop);
        break;
      case "translate":
        display({
          RGB: "#ff00ff", // Purple for translate mode
          emoji: "🌐",
          text: "Translating...",
        });
        this.currentFlowName = "translate";
        this.answerId += 1;
        const translateAnswerId = this.answerId;
        onButtonPressed(() => {
          this.setCurrentFlow("listening");
        });
        onButtonReleased(noop);
        const {
          partial: translatePartial,
          endPartial: translateEndPartial,
          getPlayEndPromise: translateGetPlayEndPromise,
          stop: stopTranslating,
        } = this.streamResponser;
        
        // Run translation with diarization workflow
        translateWithDiarization(
          this.currentRecordFilePath,
          (text) => translatePartial(text, translateAnswerId),
          () => translateEndPartial(translateAnswerId),
          (partialThinking) =>
            this.partialThinkingCallback(partialThinking, translateAnswerId)
        );
        
        translateGetPlayEndPromise().then(() => {
          if (this.currentFlowName === "translate") {
            this.setCurrentFlow("sleep");
          }
        });
        
        onButtonPressed(() => {
          stopTranslating();
          this.setCurrentFlow("listening");
        });
        onButtonReleased(noop);
        break;
      case "image":
        onButtonPressed(() => {
          display({ image: "" });
          this.setCurrentFlow("listening");
        });
        onButtonReleased(noop);
        break;
      default:
        console.error("Unknown flow name:", flowName);
        break;
    }
  };
}

export default ChatFlow;
