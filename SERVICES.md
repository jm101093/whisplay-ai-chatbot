# Whisplay AI Chatbot - Systemd Services

## Services Installed

Two systemd services have been configured to run automatically on boot:

1. **llama-server.service** - Runs the llama.cpp server
2. **whisplay-chatbot.service** - Runs the main chatbot application

## Service Management

### Start Services
```bash
sudo systemctl start llama-server
sudo systemctl start whisplay-chatbot
```

### Stop Services
```bash
sudo systemctl stop whisplay-chatbot
sudo systemctl stop llama-server
```

### Restart Services
```bash
sudo systemctl restart llama-server
sudo systemctl restart whisplay-chatbot
```

### Check Status
```bash
sudo systemctl status llama-server
sudo systemctl status whisplay-chatbot
```

### View Logs
```bash
# System logs
sudo journalctl -u llama-server -f
sudo journalctl -u whisplay-chatbot -f

# Application logs
tail -f ~/whisplay-ai-chatbot/llama.log
tail -f ~/whisplay-ai-chatbot/chatbot.log
```

### Enable/Disable Auto-start on Boot
```bash
# Disable
sudo systemctl disable llama-server
sudo systemctl disable whisplay-chatbot

# Re-enable
sudo systemctl enable llama-server
sudo systemctl enable whisplay-chatbot
```

## Service Details

### llama-server.service
- **Description**: Llama.cpp Server
- **Working Directory**: `/home/pi/whisplay-ai-chatbot`
- **Start Script**: `run_llama_cpp.sh`
- **Log File**: `~/whisplay-ai-chatbot/llama.log`
- **Auto-restart**: Yes (10 second delay)
- **Runs as**: User `pi`

### whisplay-chatbot.service
- **Description**: Whisplay AI Chatbot
- **Working Directory**: `/home/pi/whisplay-ai-chatbot`
- **Start Command**: `node dist/index.js`
- **Log File**: `~/whisplay-ai-chatbot/chatbot.log`
- **Auto-restart**: Yes (10 second delay)
- **Depends on**: `llama-server.service`
- **Startup Delay**: 30 seconds (waits for llama server)
- **Runs as**: User `pi`

## Startup Sequence

On boot, the following happens:

1. System starts and network comes up
2. **llama-server.service** starts
   - Loads the model specified in `.env`
   - Waits for server to be listening on port 8080
3. **whisplay-chatbot.service** starts (after 30 second delay)
   - Connects to the llama server
   - Initializes audio devices
   - Connects to display HAT
   - Ready to accept voice commands

## Troubleshooting

### Service won't start
```bash
# Check for errors in system logs
sudo journalctl -u llama-server -n 50
sudo journalctl -u whisplay-chatbot -n 50

# Check application logs
tail -100 ~/whisplay-ai-chatbot/llama.log
tail -100 ~/whisplay-ai-chatbot/chatbot.log
```

### Port already in use
```bash
# Find and kill process using port 8080
sudo lsof -ti:8080 | xargs sudo kill -9

# Restart service
sudo systemctl restart llama-server
```

### Service keeps restarting
```bash
# View recent restart attempts
sudo systemctl status llama-server
sudo systemctl status whisplay-chatbot

# Check if .env file is correct
cat ~/whisplay-ai-chatbot/.env

# Verify model path exists
ls -lh ~/whisplay-ai-chatbot/models/
```

### Manual testing without services
```bash
# Stop services
sudo systemctl stop whisplay-chatbot
sudo systemctl stop llama-server

# Run manually for debugging
cd ~/whisplay-ai-chatbot
./run_llama_cpp.sh  # In one terminal
node dist/index.js   # In another terminal
```

## Uninstalling Services

To remove the services:

```bash
# Stop and disable services
sudo systemctl stop whisplay-chatbot llama-server
sudo systemctl disable whisplay-chatbot llama-server

# Remove service files
sudo rm /etc/systemd/system/llama-server.service
sudo rm /etc/systemd/system/whisplay-chatbot.service

# Reload systemd
sudo systemctl daemon-reload
```

## Notes

- Both services run as the `pi` user (not root)
- Services automatically restart on failure
- Logs are appended (won't overwrite on restart)
- The chatbot waits 30 seconds for the llama server to be ready
- Services are enabled by default (start on boot)
