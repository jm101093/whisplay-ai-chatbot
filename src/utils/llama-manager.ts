import { exec, spawn, execSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import dotenv from "dotenv";

dotenv.config();

const MODELS_DIR = path.join(__dirname, "../../models");
const LLAMA_CPP_DIR = path.join(__dirname, "../../llama.cpp");

interface ModelInfo {
  name: string;
  path: string;
  description: string;
}

/**
 * Get list of available GGUF models in the models directory
 */
export function getAvailableModels(): ModelInfo[] {
  const models: ModelInfo[] = [];
  
  if (!fs.existsSync(MODELS_DIR)) {
    console.error("Models directory not found:", MODELS_DIR);
    return models;
  }

  const files = fs.readdirSync(MODELS_DIR);
  for (const file of files) {
    if (file.endsWith(".gguf")) {
      const modelPath = path.join(MODELS_DIR, file);
      models.push({
        name: file.replace(".gguf", ""),
        path: modelPath,
        description: file,
      });
    }
  }

  return models;
}

/**
 * Stop the currently running llama.cpp server
 */
export async function stopLlamaServer(): Promise<void> {
  console.log('[LlamaManager] Stopping llama.cpp server...');
  
  try {
    // Use systemctl to stop the service (works when running as service)
    try {
      execSync('sudo systemctl stop llama-server', { stdio: 'ignore' });
      console.log('[LlamaManager] Stopped llama-server service');
    } catch (e) {
      console.log('[LlamaManager] systemctl stop failed, trying direct kill');
      // Fallback: Try direct process kill
      try {
        execSync('sudo pkill -9 -f "llama-server"', { stdio: 'ignore' });
      } catch (e2) {
        // Ignore
      }
      // Also try to kill by port
      try {
        execSync('sudo lsof -ti:8080 | xargs sudo kill -9', { stdio: 'ignore' });
      } catch (e3) {
        // Port might not be in use, which is fine
      }
    }
    
    // Wait for the process to fully terminate and port to be released
    await new Promise(resolve => setTimeout(resolve, 5000));
    console.log('[LlamaManager] Server stopped successfully');
  } catch (error) {
    console.log('[LlamaManager] Error stopping server:', error);
  }
}

/**
 * Start llama.cpp server with a specific model
 */
export async function startLlamaServer(modelPath: string): Promise<boolean> {
  return new Promise((resolve) => {
    // Update .env file with new model path
    const envPath = path.join(__dirname, "../../.env");
    let envContent = "";
    
    if (fs.existsSync(envPath)) {
      envContent = fs.readFileSync(envPath, "utf8");
      
      // Replace or add LLAMA_CPP_MODEL_PATH
      if (envContent.includes("LLAMA_CPP_MODEL_PATH=")) {
        envContent = envContent.replace(
          /LLAMA_CPP_MODEL_PATH=.*/,
          `LLAMA_CPP_MODEL_PATH=${modelPath}`
        );
      } else {
        envContent += `\nLLAMA_CPP_MODEL_PATH=${modelPath}\n`;
      }
      
      fs.writeFileSync(envPath, envContent);
    }

    // Use systemctl to start the service (works when running as service)
    try {
      execSync('sudo systemctl start llama-server', { stdio: 'inherit' });
      console.log('[LlamaManager] Started llama-server service via systemctl');
    } catch (e) {
      console.log('[LlamaManager] systemctl start failed, trying direct launch');
      // Fallback: Start directly
      const scriptPath = path.join(__dirname, "../../run_llama_cpp.sh");
      const logPath = path.join(__dirname, "../../llama.log");
      
      const serverProcess = spawn("bash", [scriptPath], {
        detached: true,
        stdio: ["ignore", fs.openSync(logPath, "a"), fs.openSync(logPath, "a")],
      });
      
      serverProcess.unref();
    }
    
    console.log(`Starting llama.cpp server with model: ${modelPath}`);
    console.log(`Server process started, waiting for initialization...`);
    
    // Wait for server to be ready (check log file)
    const logPath = path.join(__dirname, "../../llama.log");
    let attempts = 0;
    const maxAttempts = 60; // 60 seconds timeout (models can take a while to load)
    
    const checkServer = setInterval(() => {
      attempts++;
      
      if (fs.existsSync(logPath)) {
        const logContent = fs.readFileSync(logPath, "utf8");
        if (logContent.includes("server is listening")) {
          clearInterval(checkServer);
          console.log("llama.cpp server reports listening, waiting for model to fully load...");
          // Wait an additional 10 seconds for the model to be fully ready to accept requests
          setTimeout(() => {
            console.log("llama.cpp server is ready!");
            resolve(true);
          }, 10000);
          return;
        }
      }
      
      if (attempts >= maxAttempts) {
        clearInterval(checkServer);
        console.error("Server startup timeout");
        resolve(false);
      }
    }, 1000);
  });
}

/**
 * Switch to a different model
 */
export async function switchModel(modelName: string): Promise<string> {
  const models = getAvailableModels();
  const targetModel = models.find(
    (m) => m.name.toLowerCase().includes(modelName.toLowerCase())
  );

  if (!targetModel) {
    const availableNames = models.map((m) => m.name).join(", ");
    return `Model "${modelName}" not found. Available models: ${availableNames}`;
  }

  console.log(`Switching to model: ${targetModel.name}`);
  
  // Stop current server
  await stopLlamaServer();
  
  // Start new server with selected model
  const success = await startLlamaServer(targetModel.path);
  
  if (success) {
    return `Successfully switched to model: ${targetModel.name}. The model is now ready to use.`;
  } else {
    return `Failed to start server with model: ${targetModel.name}. Please check the logs.`;
  }
}

/**
 * Get current model name from environment
 */
export function getCurrentModel(): string {
  const modelPath = process.env.LLAMA_CPP_MODEL_PATH || "";
  const modelName = path.basename(modelPath, ".gguf");
  return modelName || "Unknown";
}
