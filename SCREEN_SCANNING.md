# Screen Scanning Feature

## Overview

MacChewie now includes a powerful screen scanning feature that can detect UI elements on your screen and provide AI-powered design analysis. This feature uses computer vision to identify buttons, text fields, cards, and other UI components, then allows you to get instant design feedback.

## How to Use

### 1. Activate Screen Scanning
- Click the **eye icon** (👁️) in the chat input area
- If this is your first time, you'll be prompted to grant screen recording permissions
- The eye icon will turn blue when scanning is active

### 2. Screen Recording Permission
- When prompted, click "Open System Preferences"
- Navigate to Security & Privacy → Screen Recording
- Check the box next to MacChewie
- Restart the app if needed

### 3. Using the Scanner
- Once active, a transparent overlay will appear over your screen
- Detected UI elements will be highlighted with colored borders
- Hover over elements to see them highlighted in bright colors
- Click on any highlighted element to analyze it with AI

### 4. AI Analysis
- When you click a detected element, it automatically sends details to the AI
- The AI provides design feedback based on the element type and context
- Analysis appears in your chat interface with structured recommendations

## Features

### UI Element Detection
- **Buttons**: Blue borders
- **Text Fields**: Green borders  
- **Labels**: Purple borders
- **Images**: Orange borders
- **Cards**: Teal borders
- **Lists**: Yellow borders
- **Navigation**: Red borders
- **Forms**: Brown borders

### Performance Optimization
- **Smart Scanning**: Only processes screenshots when content changes
- **Resource Efficient**: 2-second intervals with background processing
- **Memory Management**: Screenshots are not saved to disk
- **Change Detection**: Skips analysis for unchanged screen content

### Debug Features
- **Scanner Info**: Click "Scanner Info" to see performance metrics
- **Status Indicator**: Green pulsing dot shows when actively scanning
- **Element Count**: Real-time count of detected elements

## Technical Details

### Architecture
- **ScreenCaptureService**: Handles permissions and screen capture
- **DesignDetectionService**: Uses Vision framework for AI detection
- **OverlayWindowManager**: Manages transparent overlay and hover effects
- **ScreenScanner**: Coordinates all components

### Detection Methods
- **Text Recognition**: Identifies UI text and classifies element types
- **Rectangle Detection**: Finds buttons, cards, and containers
- **Face Detection**: Identifies profile images and avatars
- **Smart Filtering**: Removes overlapping elements for cleaner results

### Resource Usage
- **Memory**: 20-50MB peak usage
- **CPU**: 5-15% when active
- **Battery**: Minimal impact due to optimized intervals
- **Storage**: 0 bytes (no persistent storage)

## Troubleshooting

### Permission Issues
- Ensure screen recording permission is granted in System Preferences
- Restart the app after granting permissions
- Check that MacChewie is not sandboxed incorrectly

### Performance Issues
- Use "Scanner Info" to monitor performance
- Scanning automatically pauses if system resources are low
- Adjust scan frequency if needed (currently 2 seconds)

### Detection Issues
- Some UI elements may not be detected if they're too small or complex
- Text-based detection works best with clear, readable fonts
- Overlapping elements are filtered out to avoid confusion

## Future Enhancements

- Custom detection models for specific app types
- Multi-monitor support
- Element interaction recording
- Design pattern recognition
- Export detected elements as design specs
