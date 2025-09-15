//
//  MenuBarView.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import SwiftUI
import Foundation
import AppKit

// MARK: - Message Structure
enum MessageSender {
    case user
    case agent
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let image: NSImage?
    let sender: MessageSender
    let timestamp: Date
    
    init(text: String, image: NSImage? = nil, sender: MessageSender = .user) {
        self.text = text
        self.image = image
        self.sender = sender
        self.timestamp = Date()
    }
}

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
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    @StateObject private var dustService = DustService()
    @StateObject private var screenCaptureService = ScreenCaptureService()
    @StateObject private var designSelectionManager = DesignSelectionWindowManager()
    @State private var selectedImage: NSImage?
    @State private var loadingMessageIndex: Int = 0
    @State private var loadingTimer: Timer?
    @State private var selectedTags: Set<String> = []
    
    // Loading messages to cycle through
    private let loadingMessages = [
        "Analysing the image",
        "Fetching proper refs", 
        "Mixing it all together",
        "Cooking a dope answer",
        "Sugar coating the truth"
    ]
    
    // Computed property for status message
    private var statusMessage: String {
        if screenCaptureService.isScanning {
            return "🤖 Analyzing screen with AI..."
        } else {
            return ""
        }
    }
    
    // Computed property for placeholder text
    private var placeholderText: String {
        if isLoading {
            return loadingMessages[loadingMessageIndex]
        } else {
            return "What is this design?"
        }
    }
    
    init() {
        print("📱 [DEBUG] MenuBarView initializing")
    }
    
    // Start cycling through loading messages
    private func startLoadingMessages() {
        loadingMessageIndex = 0
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            loadingMessageIndex = (loadingMessageIndex + 1) % loadingMessages.count
        }
    }
    
    // Stop cycling through loading messages
    private func stopLoadingMessages() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        loadingMessageIndex = 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header section
            HStack {
                // Left side: Back chevron + Title
                HStack(spacing: 8) {
                    Button(action: {
                        // Back action - could be used to close or navigate back
                        print("📱 [DEBUG] Back button tapped")
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Fits profiles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Right side: Reset button
                Button(action: {
                    resetConversation()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                        Text("Reset")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            // Main content
            VStack(spacing: 16) {
            // Messages area - animated pop-in above input
            if !messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(messages.indices, id: \.self) { index in
                                let message = messages[index]
                                
                                // Check if this message contains agent output format
                                if message.text.contains("⭐️") || message.text.contains("🔴") || message.text.contains("🟢") || message.text.contains("✅") {
                                    // Parse and display as structured cards
                                    let output = AgentOutputParser.parse(message.text)
                                    AgentOutputView(output: output) { solution in
                                        sendTaggedMessage(solution)
                                    }
                                    .padding(.horizontal, 8)
                                    .id("message-\(index)")
                                } else {
                                    // Display as regular message with optional image
                                    VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 8) {
                                        if let image = message.image {
                                            // Display image
                                            Image(nsImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxHeight: 300)
                                                .cornerRadius(12)
                                                .shadow(radius: 4)
                                        }
                                        
                                        if !message.text.isEmpty {
                                            HStack {
                                                if message.sender == .agent {
                                                    Spacer()
                                                }
                                                
                                                Text(message.text)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 10)
                                                    .background(
                                                        message.sender == .user 
                                                        ? Color.accentColor.opacity(0.8) 
                                                        : Color.accentColor.opacity(0.15), 
                                                        in: RoundedRectangle(cornerRadius: 16)
                                                    )
                                                    .foregroundStyle(
                                                        message.sender == .user 
                                                        ? Color.white 
                                                        : Color.primary
                                                    )
                                                
                                                if message.sender == .user {
                                                    Spacer()
                                                }
                                            }
                                        }
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
            
            
            // Status indicator - under conversation area (only for scanning)
            if screenCaptureService.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                    
                    Text(statusMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.5))
                        .animation(.easeInOut(duration: 0.2), value: statusMessage)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .opacity(0.8)
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // Chat input - always at bottom
            VStack(spacing: 0) {
                
                
                HStack(spacing: 4) {
                    // Screen scan button - only show when no image is uploaded
                    if selectedImage == nil {
                        Button(action: {
                            if !isLoading && !screenCaptureService.isScanning {
                                scanScreen()
                            }
                        }) {
                            Image(systemName: screenCaptureService.isScanning ? "eyeglasses" : "eyeglasses.slash")
                                .font(.system(size: 16))
                                .foregroundColor(isLoading ? .secondary.opacity(0.5) : (screenCaptureService.isScanning ? .green : .secondary))
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isLoading ? Color(NSColor.controlBackgroundColor).opacity(0.5) : (screenCaptureService.isScanning ? Color.green.opacity(0.1) : Color(NSColor.controlBackgroundColor)))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading || screenCaptureService.isScanning)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(screenCaptureService.isScanning ? Color.green.opacity(0.3) : Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                        .help(isLoading ? "Please wait..." : (screenCaptureService.isScanning ? "Scanning screen..." : "Scan screen for designs"))
                    }
                    
                    // Image upload button
                    ZStack {
                        Button(action: {
                            if !isLoading && selectedImage == nil {
                                selectImageFile()
                            }
                        }) {
                            Image(systemName: selectedImage != nil ? "photo.fill" : "photo")
                                .font(.system(size: 16))
                                .foregroundColor(isLoading ? .secondary.opacity(0.5) : (selectedImage != nil ? .blue : .secondary))
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isLoading ? Color(NSColor.controlBackgroundColor).opacity(0.5) : (selectedImage != nil ? .white : Color(NSColor.controlBackgroundColor)))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                        .help(isLoading ? "Please wait..." : (selectedImage != nil ? "Remove image" : "Upload image"))
                        
                        // Red X mark overlay when image is selected
                        if selectedImage != nil {
                            Button(action: {
                                if !isLoading {
                                    selectedImage = nil
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                                    .background(Color.white, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(y: -15)
                            .offset(x: 17)
                        }
                    }
                    
                    // Text field with send button inside
                    ZStack(alignment: .trailing) {
                        VStack(spacing: 8) {
                            // Tags inside text field when image is present
                            if selectedImage != nil {
                                HStack(spacing: 4) {
                                    Button("Component") {
                                        toggleTag("Component")
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedTags.contains("Component") ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedTags.contains("Component") ? Color.accentColor : Color.accentColor.opacity(0.3), lineWidth: selectedTags.contains("Component") ? 1.5 : 0.5)
                                    )
                                    .foregroundStyle(selectedTags.contains("Component") ? Color.accentColor : Color.accentColor.opacity(0.7))
                                    
                                    Button("Screen") {
                                        toggleTag("Screen")
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedTags.contains("Screen") ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedTags.contains("Screen") ? Color.accentColor : Color.accentColor.opacity(0.3), lineWidth: selectedTags.contains("Screen") ? 1.5 : 0.5)
                                    )
                                    .foregroundStyle(selectedTags.contains("Screen") ? Color.accentColor : Color.accentColor.opacity(0.7))
                                    
                                    Button("Flow") {
                                        toggleTag("Flow")
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedTags.contains("Flow") ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedTags.contains("Flow") ? Color.accentColor : Color.accentColor.opacity(0.3), lineWidth: selectedTags.contains("Flow") ? 1.5 : 0.5)
                                    )
                                    .foregroundStyle(selectedTags.contains("Flow") ? Color.accentColor : Color.accentColor.opacity(0.7))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                            }
                            
                            // Text input
                            TextField(placeholderText, text: $chatText)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.vertical, selectedImage != nil ? 16 : 12)
                                .padding(.trailing, 40) // Make space for the send button
                                .background(Color.clear)
                                .disabled(isLoading)
                                .onSubmit {
                                    if !isLoading {
                                        sendMessage()
                                    }
                                }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isLoading ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                        
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
                        .padding(.bottom, selectedImage != nil ? 8 : 0)
                        .disabled((chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedImage == nil) || isLoading)
                    }
                }
            }
            }
            
        }
        .padding(12)
        .frame(minWidth: 380, maxWidth: .infinity)
        .frame(minHeight: messages.isEmpty ? 120 : 720, maxHeight: .infinity)
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
    
    private func openWebpage() {
        // Opens the Chewie AI frontend interface
        guard let url = URL(string: "https://maximegerardin97-max.github.io/chewieai-fe-clean/") else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func resetConversation() {
        print("📱 [DEBUG] Reset conversation button tapped")
        
        // Clear all conversation data
        messages.removeAll()
        chatText = ""
        selectedImage = nil
        selectedTags.removeAll()
        
        // Stop any ongoing loading
        isLoading = false
        stopLoadingMessages()
        
        // Reset screen capture service if needed
        if screenCaptureService.isScanning {
            // Note: You might want to add a method to stop scanning in ScreenCaptureService
            print("📱 [DEBUG] Screen capture was in progress, resetting...")
        }
    }
    
    private func scanScreen() {
        print("📱 [DEBUG] Scan screen button tapped")
        
        Task {
            print("📱 [DEBUG] Starting async screen capture task")
            await screenCaptureService.captureAndAnalyzeScreen()
            
            await MainActor.run {
                print("📱 [DEBUG] Screen capture completed, checking results")
                print("📱 [DEBUG] Detected elements count: \(screenCaptureService.detectedElements.count)")
                print("📱 [DEBUG] Error message: \(screenCaptureService.errorMessage ?? "none")")
                
                if !screenCaptureService.detectedElements.isEmpty {
                    print("📱 [DEBUG] Showing design selection overlay")
                    // Show design selection overlay
                    designSelectionManager.showDesignSelection(
                        elements: screenCaptureService.detectedElements,
                        onElementSelected: { element in
                            print("📱 [DEBUG] Element selected in MenuBarView: \(element.type.rawValue)")
                            handleDesignSelection(element)
                        },
                        onCancel: {
                            print("📱 [DEBUG] Design selection cancelled")
                            // Just close the selection window, no action needed
                        }
                    )
                } else if let errorMessage = screenCaptureService.errorMessage {
                    print("📱 [DEBUG] Adding error message to chat: \(errorMessage)")
                    messages.append(ChatMessage(text: "❌ Scan failed: \(errorMessage)", sender: .agent))
                } else {
                    print("📱 [DEBUG] No elements detected, adding message to chat")
                    messages.append(ChatMessage(text: "❌ No design elements detected on screen", sender: .agent))
                }
            }
        }
    }
    
    private func handleDesignSelection(_ element: DetectedDesignElement) {
        print("📱 [DEBUG] Handling design selection for element: \(element.type.rawValue)")
        
        // Get the cropped image of the selected design
        print("📱 [DEBUG] Attempting to crop selected design")
        guard let croppedImage = screenCaptureService.getImageCrop(for: element) else {
            print("❌ [DEBUG] Failed to crop selected design")
            messages.append(ChatMessage(text: "❌ Failed to capture selected design", sender: .agent))
            return
        }
        
        print("✅ [DEBUG] Design cropped successfully, size: \(croppedImage.size)")
        
        // Create a message describing the selected design
        let designDescription = "📷 Selected Design: \(element.type.rawValue) (confidence: \(Int(element.confidence * 100))%)"
        
        print("📱 [DEBUG] Adding design description to chat: \(designDescription)")
        
        // Add to messages
        messages.append(ChatMessage(text: designDescription, image: croppedImage, sender: .user))
        
        // Set the selected image for the chat input
        selectedImage = croppedImage
        print("📱 [DEBUG] Selected image set for chat input")
        
        // Auto-focus the text field for user input
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("📱 [DEBUG] Auto-focus delay completed")
            // This will be handled by the text field automatically
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
        messages.append(ChatMessage(text: sampleOutput, sender: .agent))
    }
    
    private func sendTaggedMessage(_ content: String) {
        let taggedMessage = "\(content)\n\nTell me more about this"
        
        // Add user message to chat
        messages.append(ChatMessage(text: taggedMessage, sender: .user))
        
        // Send to AI
        isLoading = true
        startLoadingMessages()
        
        Task {
            do {
                let response = try await dustService.sendMessage(taggedMessage, image: nil)
                
                await MainActor.run {
                    let responseMessage = ChatMessage(text: response, sender: .agent)
                    messages.append(responseMessage)
                    isLoading = false
                    stopLoadingMessages()
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(text: "Error: \(error.localizedDescription)", sender: .agent)
                    messages.append(errorMessage)
                    isLoading = false
                    stopLoadingMessages()
                }
            }
        }
    }
    
    private func sendMessage() {
        let trimmedText = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't send if both text and image are empty
        guard !trimmedText.isEmpty || selectedImage != nil else { return }
        
        // Build the message with selected tags
        var messageText = trimmedText.isEmpty ? "" : trimmedText
        
        // Add selected tags to the message
        if !selectedTags.isEmpty {
            let tagsText = "Tags: " + selectedTags.sorted().joined(separator: ", ")
            if messageText.isEmpty {
                messageText = tagsText
            } else {
                messageText = "\(messageText)\n\n\(tagsText)"
            }
        }
        
        // Add user message to chat
        let message = ChatMessage(text: messageText, image: selectedImage, sender: .user)
        messages.append(message)
        
        // Clear input and reset tags
        chatText = ""
        let imageToSend = selectedImage
        selectedImage = nil
        selectedTags.removeAll()
        
        // Send to AI
        isLoading = true
        startLoadingMessages()
        
        Task {
            do {
                let response = try await dustService.sendMessage(
                    messageText.isEmpty ? "Please analyze this image." : messageText,
                    image: imageToSend
                )
                
                await MainActor.run {
                    let responseMessage = ChatMessage(text: response, sender: .agent)
                    messages.append(responseMessage)
                    isLoading = false
                    stopLoadingMessages()
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(text: "Error: \(error.localizedDescription)", sender: .agent)
                    messages.append(errorMessage)
                    isLoading = false
                    stopLoadingMessages()
                }
            }
        }
    }
}
