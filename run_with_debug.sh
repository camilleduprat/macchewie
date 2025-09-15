#!/bin/bash

# Script to run MacChewie with debug output
echo "🚀 Starting MacChewie with debug logging..."
echo "📝 All debug output will be logged to console.log"
echo "⏹️  Press Ctrl+C to stop the app and view logs"
echo ""

# Run the app and capture all output
/Users/camille/Library/Developer/Xcode/DerivedData/macchewie-excmrkmkvozdeebwuonuzqhdcetn/Build/Products/Debug/macchewie.app/Contents/MacOS/macchewie 2>&1 | tee console.log

echo ""
echo "📋 Debug log saved to console.log"
echo "🔍 You can view the log with: cat console.log"
