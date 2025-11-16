const { chatWithLLMStream } = require("../cloud-api/volcengine-llm");
const volcengineTTS = require("../cloud-api/volcengine-tts");
const openaiTTS = require("../cloud-api/openai-tts");
const { createSteamResponser, playAudioData } = require("../device/audio");

const { partial, endPartial, getPlayEndPromise } = createSteamResponser(
  volcengineTTS,
  (text) => {
    console.log("Complete response outside:", text);
  }
);

// main
(async () => {
  const text = "Hello, can you introduce me to some delicious food in Guangzhou?";

  const result = await openaiTTS(text);
  console.log("Synthesis result:", result);
  await playAudioData(result.data, result.duration);

  console.log("Playback finished");
})();
