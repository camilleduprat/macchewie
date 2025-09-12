# MacChewie - Dust.tt AI Integration

A macOS menu bar app that connects to your Dust.tt AI agent for seamless chat interactions.

## Features

- 🖼️ **Image Upload**: Drag & drop or click to upload images
- 💬 **AI Chat**: Real-time conversation with your Dust.tt AI agent
- 🎨 **Native macOS Design**: Clean, modern interface following macOS design guidelines
- ⚡ **Smooth Animations**: Spring animations for conversation UI
- 🔒 **Secure**: API key stored locally in configuration

## Setup Instructions

### 1. Get Your Dust.tt Credentials

1. **API Key**:
   - Go to [Dust.tt Settings](https://dust.tt/settings/api-keys)
   - Click "Create new API Key"
   - Copy the generated key

2. **Workspace ID**:
   - Go to your Dust.tt workspace
   - Look at the URL: `https://dust.tt/w/{WORKSPACE_ID}`
   - Copy the workspace ID from the URL

### 2. Configure the App

1. Open `macchewie/DustConfig.swift` in Xcode
2. Replace the placeholder values:

```swift
struct DustConfig {
    static let apiKey = "YOUR_ACTUAL_API_KEY_HERE"
    static let workspaceId = "YOUR_ACTUAL_WORKSPACE_ID_HERE"
}
```

### 3. Build and Run

1. Open `macchewie.xcodeproj` in Xcode
2. Build and run the project (⌘+R)
3. The app will appear in your menu bar with a gear icon

## Usage

1. **Click the gear icon** in your menu bar to open MacChewie
2. **Upload an image** (optional) by dragging & dropping or clicking the upload area
3. **Start chatting** by typing a message and pressing Enter or clicking Send
4. **View conversation** - the chat history appears with smooth animations

## API Integration Details

The app uses Dust.tt's REST API:

- **Create Conversation**: `POST /api/v1/w/{workspaceId}/assistant/conversations`
- **Send Message**: `POST /api/v1/w/{workspaceId}/assistant/conversations/{conversationId}/messages`

### Features Implemented

- ✅ Automatic conversation creation
- ✅ Message sending with loading states
- ✅ Error handling and user feedback
- ✅ Conversation persistence during app session
- ✅ Clean message formatting ("You:" vs "AI:")

## Architecture

- **MenuBarView**: Main UI container
- **ImageUploadView**: Handles image upload and preview
- **DynamicChatView**: Manages chat input and conversation display
- **DustAPIService**: Handles all Dust.tt API communications
- **DustConfig**: Centralized configuration management

## Security Notes

- API keys are stored locally in the app bundle
- No data is sent to external services except Dust.tt
- All network requests use HTTPS
- Images are processed locally before any API calls

## Troubleshooting

### App Won't Connect to Dust.tt

1. Verify your API key is correct in `DustConfig.swift`
2. Check that your workspace ID is correct
3. Ensure you have internet connectivity
4. Check Dust.tt service status

### Images Not Uploading

1. Make sure you're using supported image formats (JPEG, PNG, etc.)
2. Check file permissions
3. Try smaller image files if uploads fail

### Build Errors

1. Make sure you're using Xcode 15+ and macOS 14+
2. Clean build folder (⌘+Shift+K) and rebuild
3. Check that all files are properly added to the Xcode project

## Development

Built with:
- SwiftUI for UI
- Foundation for networking
- macOS 14+ target
- Xcode 15+ required

## License

This project is for personal use. Please respect Dust.tt's terms of service when using their API.
