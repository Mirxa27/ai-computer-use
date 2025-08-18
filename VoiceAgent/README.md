# Voice Agent - Sophisticated macOS AI Voice Assistant

A powerful macOS application that combines real-time voice control with advanced AI capabilities, featuring support for multiple AI providers and a customizable Model Context Protocol (MCP).

## Features

### 🎙️ Real-time Voice Control
- **Continuous Active Listening**: Always-on voice detection with configurable activation
- **Instant Speech Recognition**: Real-time transcription using Apple's Speech framework
- **Dynamic Voice Responses**: Natural text-to-speech with customizable voices
- **Silence Detection**: Automatic command processing after speech pauses
- **Voice Activity Detection**: Visual feedback with waveform visualization

### 🤖 AI Integration
- **Multiple Provider Support**:
  - OpenAI (GPT-4, GPT-3.5)
  - Google Gemini (Gemini Pro)
  - Local Models (Ollama, llama.cpp compatible)
- **Provider Hot-Swapping**: Switch between AI providers on-the-fly
- **Automatic Failover**: Falls back to alternative providers on errors
- **Response Streaming**: Real-time response generation

### 🎯 Model Context Protocol (MCP)
- **Customizable Context Parameters**: Define system behavior, domain knowledge, and response styles
- **Context Profiles**: Save and load different context configurations
- **Priority-based Parameter System**: Control which parameters take precedence
- **Conversation Memory**: Maintains context across interactions
- **Dynamic Filtering**: Apply real-time filters to AI responses

### 💻 User Interface
- **Modern SwiftUI Design**: Native macOS look and feel
- **Menu Bar Integration**: Quick access from the system menu bar
- **Floating Window Mode**: Minimal, always-accessible interface
- **Dark Mode Support**: Automatic theme switching
- **Customizable Appearance**: Adjustable fonts, colors, and opacity

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later
- Active internet connection for cloud AI providers
- Microphone access permission

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/VoiceAgent.git
cd VoiceAgent
```

2. Open the project in Xcode:
```bash
open Package.swift
```

3. Build and run:
   - Select your Mac as the build target
   - Press ⌘R to build and run

### Using Swift Package Manager

```bash
swift build -c release
```

The built application will be in `.build/release/VoiceAgent`

## Configuration

### API Keys

Configure your AI provider API keys in Settings:

1. Open Voice Agent
2. Go to Settings (⌘,)
3. Navigate to "AI Providers" tab
4. Enter your API keys:
   - **OpenAI**: Get from [platform.openai.com](https://platform.openai.com)
   - **Gemini**: Get from [makersuite.google.com](https://makersuite.google.com)
   - **Local Models**: Install [Ollama](https://ollama.ai) or llama.cpp server

### Local Model Setup

For local model support:

1. Install Ollama:
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

2. Pull a model:
```bash
ollama pull llama2
```

3. The app will automatically detect running Ollama server at `http://localhost:11434`

## Usage

### Voice Commands

- **Start Listening**: Click the microphone button or press ⌘L
- **Stop Listening**: Click again or press ⌘L
- **Quick Input**: Press ⌘I for text input

### Example Commands

- "What's the weather like today?"
- "Generate a Python script to sort a list"
- "Analyze this code for potential bugs"
- "Switch to Gemini provider"
- "Increase response temperature to 0.8"
- "Clear conversation history"

### Context Parameters

Customize AI behavior through the Context Editor:

1. Click the context button (📄🔍) in the toolbar
2. Add or modify parameters:
   - **System Behavior**: Core assistant personality
   - **Domain Knowledge**: Specialized expertise
   - **Response Style**: Output formatting preferences
   - **Memory Context**: Conversation continuity
   - **Task Specific**: Focused capabilities
   - **User Preferences**: Personal customizations

### Keyboard Shortcuts

- **⌘L**: Toggle listening
- **⌘I**: Quick text input
- **⌘,**: Open settings
- **⌘Q**: Quit application
- **⌘⇧Space**: Global hotkey (configurable)

## Architecture

### Core Components

- **VoiceController**: Manages speech recognition and synthesis
- **AIManager**: Coordinates between different AI providers
- **ModelContextProtocol**: Implements the MCP system
- **SettingsManager**: Handles user preferences and configuration
- **AppState**: Central state management

### Provider Architecture

Each AI provider implements the `AIProviderProtocol`:
- Unified interface for all providers
- Async/await based communication
- Error handling and retry logic
- Response streaming support

### MCP System

The Model Context Protocol enhances AI interactions:
- Pre-processes user input with context
- Maintains conversation history
- Applies contextual filters to responses
- Supports custom parameter types

## Development

### Adding New AI Providers

1. Create a new provider class implementing `AIProviderProtocol`
2. Add to `AIProvider` enum
3. Register in `AIManager.setupProviders()`

### Extending Voice Commands

1. Add new intent types to `IntentType` enum
2. Update `IntentClassifier` with patterns
3. Handle in `AIManager.handleVoiceCommand()`

### Custom Context Parameters

1. Define new parameter types in `ContextParameter.ParameterType`
2. Add UI in `ContextEditorView`
3. Implement processing in `StandardMCP`

## Privacy & Security

- **Local Processing**: Speech recognition happens on-device
- **Secure Storage**: API keys stored in macOS Keychain
- **No Telemetry**: No usage data is collected
- **Open Source**: Full code transparency

## Troubleshooting

### Microphone Not Working
1. Check System Settings > Privacy & Security > Microphone
2. Ensure Voice Agent has permission
3. Restart the application

### AI Provider Connection Issues
1. Verify API keys in Settings
2. Check internet connection
3. Try switching to a different provider

### Local Model Not Responding
1. Ensure Ollama/llama.cpp server is running
2. Verify endpoint URL (default: http://localhost:11434)
3. Check if model is downloaded

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Apple Speech Framework for voice recognition
- OpenAI for GPT models
- Google for Gemini AI
- Ollama team for local model support
- SwiftUI community for UI components

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Contact: support@voiceagent.app
- Documentation: docs.voiceagent.app