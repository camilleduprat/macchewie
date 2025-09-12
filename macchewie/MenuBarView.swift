//
//  MenuBarView.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import SwiftUI
import Foundation

// MARK: - Agent Output Models
struct AgentOutput {
    let solutions: [String]
    let categories: [Category]
}

struct Category {
    let title: String
    let arguments: [Argument]
}

struct Argument {
    let text: String
    let type: ArgumentType
}

enum ArgumentType {
    case issue
    case good
}

// MARK: - Agent Output Parser
class AgentOutputParser {
    static func parse(_ text: String) -> AgentOutput {
        let lines = text.components(separatedBy: .newlines)
        var solutions: [String] = []
        var categories: [Category] = []
        var currentCategory: Category?
        var currentArguments: [Argument] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            if trimmedLine.hasPrefix("✅") {
                // Solution
                let solutionText = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !solutionText.isEmpty {
                    solutions.append(solutionText)
                }
            } else if trimmedLine.hasPrefix("⭐️") {
                // Category - save previous category if exists
                if let category = currentCategory {
                    categories.append(category)
                }
                
                let categoryTitle = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                currentCategory = Category(title: categoryTitle, arguments: [])
                currentArguments = []
            } else if trimmedLine.hasPrefix("🔴") {
                // Issue argument
                let argumentText = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !argumentText.isEmpty {
                    currentArguments.append(Argument(text: argumentText, type: .issue))
                }
            } else if trimmedLine.hasPrefix("🟢") {
                // Good argument
                let argumentText = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !argumentText.isEmpty {
                    currentArguments.append(Argument(text: argumentText, type: .good))
                }
            }
        }
        
        // Add the last category
        if let category = currentCategory {
            let finalCategory = Category(title: category.title, arguments: currentArguments)
            categories.append(finalCategory)
        }
        
        return AgentOutput(solutions: solutions, categories: categories)
    }
}

// MARK: - Card Components
struct SolutionCard: View {
    let solution: String
    let onMoreTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text("✅")
                    .font(.system(size: 16))
                
                Text(solution)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            HStack {
                Spacer()
                Button("More") {
                    onMoreTapped()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(Color.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct CategoryTitle: View {
    let title: String
    
    var body: some View {
        HStack {
            Text("⭐️")
                .font(.system(size: 16))
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct ArgumentCard: View {
    let argument: Argument
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(argument.type == .issue ? "🔴" : "🟢")
                .font(.system(size: 16))
            
            Text(argument.text)
                .font(.system(size: 14))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(argument.type == .issue ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(argument.type == .issue ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct AgentOutputView: View {
    let output: AgentOutput
    let onSolutionMoreTapped: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Solutions first
            if !output.solutions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(output.solutions.indices, id: \.self) { index in
                        SolutionCard(solution: output.solutions[index]) {
                            onSolutionMoreTapped(output.solutions[index])
                        }
                    }
                }
            }
            
            // Then categories with their arguments
            ForEach(output.categories.indices, id: \.self) { categoryIndex in
                let category = output.categories[categoryIndex]
                
                VStack(alignment: .leading, spacing: 8) {
                    CategoryTitle(title: category.title)
                    
                    ForEach(category.arguments.indices, id: \.self) { argumentIndex in
                        ArgumentCard(argument: category.arguments[argumentIndex])
                    }
                }
            }
        }
    }
}

struct MenuBarView: View {
    @State private var chatText: String = ""
    @State private var messages: [String] = []
    @State private var isLoading: Bool = false
    @StateObject private var dustService = DustService()
    @State private var selectedImage: NSImage?
    @State private var isEyeSelected: Bool = false
    @StateObject private var screenScanner = ScreenScanner()
    @State private var showDebugPanel: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Messages area - animated pop-in above input
            if !messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(messages.indices, id: \.self) { index in
                                let message = messages[index]
                                
                                // Check if this message contains agent output format
                                if message.contains("⭐️") || message.contains("🔴") || message.contains("🟢") || message.contains("✅") {
                                    // Parse and display as structured cards
                                    let output = AgentOutputParser.parse(message)
                                    AgentOutputView(output: output) { solution in
                                        sendTaggedMessage(solution)
                                    }
                                    .padding(.horizontal, 8)
                                    .id("message-\(index)")
                                } else {
                                    // Display as regular message
                                    HStack {
                                        Text(message)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                                            .foregroundStyle(Color.primary)
                                        Spacer()
                                    }
                                    .id("message-\(index)")
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: messages.count) { _ in
                        // Scroll to the latest message when new messages are added
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("message-\(messages.count - 1)", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Debug Panel
            if showDebugPanel {
                DebugPanelView(screenScanner: screenScanner)
                    .padding(.horizontal, 8)
            }
            
            // Image preview area
            if let selectedImage = selectedImage {
                HStack {
                    Image(nsImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 900)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(selectedImage.size.width))×\(Int(selectedImage.size.height))")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                        
                        Button("Remove") {
                            self.selectedImage = nil
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(Color.red)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Chat input - always at bottom
            VStack(spacing: 8) {
                // Debug and scanner info
                HStack {
                    Button("Debug: Add Sample Output") {
                        if !isLoading {
                            addSampleAgentOutput()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(isLoading ? Color.blue.opacity(0.5) : Color.blue)
                    .disabled(isLoading)
                    
                    Button("Scanner Info") {
                        showScannerInfo()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(Color.orange)
                    .disabled(isLoading)
                    
                    Button(showDebugPanel ? "Hide Debug" : "Show Debug") {
                        showDebugPanel.toggle()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(Color.purple)
                    .disabled(isLoading)
                    
                    // Scanner status indicator
                    if screenScanner.isScanning {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .scaleEffect(screenScanner.isScanning ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: screenScanner.isScanning)
                            
                            Text("Scanning")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    // Eye icon button - Screen Scanner
                    Button(action: {
                        if !isLoading {
                            handleEyeButtonTap()
                        }
                    }) {
                        Image(systemName: screenScanner.isScanning ? "eye.fill" : "eye")
                            .font(.system(size: 16))
                            .foregroundColor(isLoading ? .secondary.opacity(0.5) : (screenScanner.isScanning ? .blue : .secondary))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isLoading ? Color(NSColor.controlBackgroundColor).opacity(0.5) : (screenScanner.isScanning ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor)))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(screenScanner.isScanning ? Color.blue.opacity(0.3) : Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                    .help(getEyeButtonTooltip())
                    
                    // Image upload button
                    Button(action: {
                        if !isLoading {
                            selectImageFile()
                        }
                    }) {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundColor(isLoading ? .secondary.opacity(0.5) : .secondary)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isLoading ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
                    .help(isLoading ? "Please wait..." : "Upload image")
                    // Text field with send button inside
                    ZStack(alignment: .trailing) {
                        TextField(isLoading ? "Waiting for the answer..." : "Type your message...", text: $chatText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .padding(.trailing, 40) // Make space for the send button
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isLoading ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                            )
                            .disabled(isLoading)
                            .onSubmit {
                                if !isLoading {
                                    sendMessage()
                                }
                            }
                        
                        // Send button inside the text field
                        Button(action: sendMessage) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.borderless)
                        .padding(.trailing, 12)
                        .disabled((chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil) || isLoading)
                    }
                }
            }
            
        }
        .padding(20)
        .frame(minWidth: 380, maxWidth: .infinity)
        .frame(minHeight: messages.isEmpty ? 100 : 600, maxHeight: .infinity)
        .onAppear {
            setupScreenScannerNotifications()
        }
        .onChange(of: screenScanner.isScanning) { isScanning in
            isEyeSelected = isScanning
        }
    }
    
    private func selectImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedImage = NSImage(contentsOf: url)
        }
    }
    
    private func addSampleAgentOutput() {
        let sampleOutput = """
⭐️ Business: 75/100 :
component A :
issues : add a 🔴
good : add a 🟢
⭐️ Experience: 60/100 :
component B :
issues : add a 🔴
good : add a 🟢
Most impactful improvement :
✅ Solution 1 : Focus on improving the user onboarding flow to reduce drop-off rates
✅ Solution 2 : Implement better error handling and user feedback mechanisms
"""
        messages.append(sampleOutput)
    }
    
    private func showScannerInfo() {
        let infoMessage = """
        🔍 Screen Scanner Status:
        \(screenScanner.getPerformanceInfo())
        
        Permission: \(screenScanner.hasPermission ? "✅ Granted" : "❌ Required")
        Scanning: \(screenScanner.isScanning ? "✅ Active" : "⏸️ Stopped")
        Elements Detected: \(screenScanner.detectedElements.count)
        """
        
        messages.append(infoMessage)
    }
    
    private func sendTaggedMessage(_ content: String) {
        let taggedMessage = "\(content)\n\nTell me more about this"
        
        // Add user message to chat
        messages.append(taggedMessage)
        
        // Send to AI
        isLoading = true
        
        Task {
            do {
                let response = try await dustService.sendMessage(taggedMessage, image: nil)
                
                await MainActor.run {
                    messages.append(response)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append("Error: \(error.localizedDescription)")
                    isLoading = false
                }
            }
        }
    }
    
    private func sendMessage() {
        let trimmedText = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't send if both text and image are empty
        guard !trimmedText.isEmpty || selectedImage != nil else { return }
        
        // Add user message to chat
        var messageText = trimmedText.isEmpty ? "" : trimmedText
        if selectedImage != nil {
            messageText += trimmedText.isEmpty ? "📷 Image" : " [📷 Image attached]"
        }
        
        if !messageText.isEmpty {
            messages.append(messageText)
        }
        
        // Clear input
        chatText = ""
        let imageToSend = selectedImage
        selectedImage = nil
        
        // Send to AI
        isLoading = true
        
        Task {
            do {
                let response = try await dustService.sendMessage(
                    trimmedText.isEmpty ? "Please analyze this image." : trimmedText,
                    image: imageToSend
                )
                
                await MainActor.run {
                    messages.append(response)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append("Error: \(error.localizedDescription)")
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Screen Scanner Integration
    
    private func handleEyeButtonTap() {
        if !screenScanner.hasPermission {
            screenScanner.requestPermissions()
        } else {
            screenScanner.toggleScanning()
        }
    }
    
    private func getEyeButtonTooltip() -> String {
        if isLoading {
            return "Please wait..."
        } else if !screenScanner.hasPermission {
            return "Screen recording permission required"
        } else if screenScanner.isScanning {
            return "Stop screen scanning"
        } else {
            return "Start screen scanning"
        }
    }
    
    private func setupScreenScannerNotifications() {
        // Listen for element selection from screen scanner
        NotificationCenter.default.addObserver(
            forName: .elementSelectedForAnalysis,
            object: nil,
            queue: .main
        ) { notification in
            self.handleElementSelectedForAnalysis(notification)
        }
        
        // Listen for scanner errors
        NotificationCenter.default.addObserver(
            forName: .scannerError,
            object: nil,
            queue: .main
        ) { notification in
            self.handleScannerError(notification)
        }
    }
    
    private func handleScannerError(_ notification: Notification) {
        guard let errorMessage = notification.userInfo?["error"] as? String else { return }
        
        // Add error message to chat
        let errorChatMessage = "🚨 Scanner Error: \(errorMessage)"
        messages.append(errorChatMessage)
        
        // Stop scanning on error
        screenScanner.stopScanning()
    }
    
    private func handleElementSelectedForAnalysis(_ notification: Notification) {
        guard let element = notification.userInfo?["element"] as? UIElement else { return }
        
        // Create a message about the selected element
        let elementMessage = """
        📱 Detected UI Element:
        Type: \(element.type.rawValue)
        Description: \(element.description)
        Confidence: \(String(format: "%.1f", element.confidence * 100))%
        
        Please analyze this UI element and provide design feedback.
        """
        
        // Add to messages
        messages.append(elementMessage)
        
        // Send to AI for analysis
        isLoading = true
        
        Task {
            do {
                let response = try await dustService.sendMessage(elementMessage, image: nil)
                
                await MainActor.run {
                    messages.append(response)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append("Error analyzing element: \(error.localizedDescription)")
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Debug Panel View
struct DebugPanelView: View {
    @ObservedObject var screenScanner: ScreenScanner
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🔍 Debug Panel")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Spacer()
                Text("Live Updates")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            
            // Permission Status
            HStack {
                Text("Permission:")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Text(screenScanner.hasPermission ? "✅ Granted" : "❌ Required")
                    .font(.caption)
                    .foregroundStyle(screenScanner.hasPermission ? Color.green : Color.red)
                Spacer()
            }
            
            // Scanning Status
            HStack {
                Text("Scanning:")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Text(screenScanner.isScanning ? "✅ Active" : "⏸️ Stopped")
                    .font(.caption)
                    .foregroundStyle(screenScanner.isScanning ? Color.green : Color.gray)
                Spacer()
            }
            
            // Performance Metrics
            VStack(alignment: .leading, spacing: 4) {
                Text("Performance:")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                
                HStack {
                    Text("Elements Detected:")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                    Text("\(screenScanner.detectedElements.count)")
                        .font(.caption2)
                        .foregroundStyle(Color.primary)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                HStack {
                    Text("Scan Count:")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                    Text("\(screenScanner.scanCount)")
                        .font(.caption2)
                        .foregroundStyle(Color.primary)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                if let lastScan = screenScanner.lastScanTime {
                    HStack {
                        Text("Last Scan:")
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                        Text(lastScan, style: .time)
                            .font(.caption2)
                            .foregroundStyle(Color.primary)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
            }
            
            // Detected Elements List
            if !screenScanner.detectedElements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Detected Elements:")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(screenScanner.detectedElements, id: \.id) { element in
                                ElementDebugView(element: element)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(maxHeight: 60)
                }
            }
            
            // Design Detection Service Status
            if screenScanner.designDetectionService.isProcessing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing detection...")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                    Spacer()
                }
            }
            
            // Performance Info
            Text(screenScanner.getPerformanceInfo())
                .font(.caption2)
                .foregroundStyle(Color.secondary)
                .padding(.top, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        )
        .onAppear {
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // This will trigger a view refresh by accessing the observed properties
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Element Debug View
struct ElementDebugView: View {
    let element: UIElement
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(element.type.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(element.type.color)
            
            if let text = element.text, !text.isEmpty {
                Text(text.prefix(20) + (text.count > 20 ? "..." : ""))
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            
            Text("\(String(format: "%.0f", element.confidence * 100))%")
                .font(.caption2)
                .foregroundStyle(Color.secondary)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(element.type.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(element.type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
