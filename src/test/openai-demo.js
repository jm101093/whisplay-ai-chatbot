const volcengineTTS = require("../cloud-api/volcengine-tts");
const openaiTTS = require("../cloud-api/openai-tts");
const { chatWithLLM, chatWithLLMStream } = require("../cloud-api/openai-llm");
const { recognizeAudio } = require("../cloud-api/openai-asr");
const {
  recordAudio,
  playAudioData,
  createSteamResponser,
} = require("../device/audio");

const { display } = require("../device/display");
const { extractEmojis } = require("../utils");

const { partial, endPartial, getPlayEndPromise } = createSteamResponser(
  volcengineTTS,
  (sentences) => {
    const fullText = sentences.join("");
    display({
      status: "Answering",
      text: fullText,
      emoji: extractEmojis(fullText),
    });
  },
  (text) => {
    console.log("Complete answer:", text);
  }
);

// main
(async () => {
  display();
  const filePath = "record.mp3";

  while (true) {
    console.log("Listening...");
    display({ status: "Listening", emoji: "😐", text: "" });
    await recordAudio(filePath, 60);
    display({ status: "Recognizing", emoji: "🤔", text: "" });
    const text = await recognizeAudio(filePath);
    // const text = await volcengineASR(filePath);
    // Call ByteDance speech synthesis to announce recognition result
    display({ text });
    if (text) {
      await Promise.all([
        chatWithLLMStream([{
          role: "user",
          content: text,
        }], partial, endPartial),
        getPlayEndPromise(),
      ]);
    } else {
      console.log("Recognition result is empty, please continue speaking");
      display({ status: "Please continue speaking" });
    }
  }
})();
