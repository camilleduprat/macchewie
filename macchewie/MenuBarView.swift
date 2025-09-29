//
//  MenuBarView.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import SwiftUI
import Foundation
import AppKit
import CoreGraphics
// MARK: - Environment Key for "Go deeper"
private struct SendGoDeeperKey: EnvironmentKey {
    static let defaultValue: ((String) -> Void)? = nil
}

extension EnvironmentValues {
    var sendGoDeeper: ((String) -> Void)? {
        get { self[SendGoDeeperKey.self] }
        set { self[SendGoDeeperKey.self] = newValue }
    }
}

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

// MARK: - New Output Models (Product/Industry/Platform, Solutions, Recommendation, Punchline)
struct NewAgentOutput {
    let product: String?
    let industry: String?
    let platform: String?
    let solutions: [NewSolution]
    let recommendation: String?
    let punchline: String?
}

struct NewSolution {
    let title: String
    let explanation: String?
}

class NewAgentOutputParser {
    static func parse(_ text: String) -> NewAgentOutput {
        let lines = text.components(separatedBy: .newlines)
        var product: String?
        var industry: String?
        var platform: String?
        var solutions: [NewSolution] = []
        var recommendation: String?
        var punchline: String?
        
        // Parse header line: Product: [X] | Industry: [Y] | Platform: [iOS/Android/Web/Desktop]
        if let header = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("Product:") }) {
            let parts = header.components(separatedBy: "|")
            for part in parts {
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("Product:") {
                    product = trimmed.replacingOccurrences(of: "Product:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("Industry:") {
                    industry = trimmed.replacingOccurrences(of: "Industry:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("Platform:") {
                    platform = trimmed.replacingOccurrences(of: "Platform:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Solutions: lines starting with ✅
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("✅") else { continue }
            // Remove the leading checkmark and any following space
            let afterCheck = trimmed.dropFirst(1).trimmingCharacters(in: .whitespaces)
            // Prefer splitting at the first ':' to separate title and explanation
            if let colon = afterCheck.firstIndex(of: ":") {
                let title = afterCheck[..<colon].trimmingCharacters(in: .whitespaces)
                let explanation = afterCheck[afterCheck.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                solutions.append(NewSolution(title: String(title), explanation: explanation.isEmpty ? nil : String(explanation)))
            } else if let eq = afterCheck.firstIndex(of: "=") { // fallback to '=' pattern if present
                let title = afterCheck[..<eq].trimmingCharacters(in: .whitespaces)
                let rest = afterCheck[afterCheck.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                solutions.append(NewSolution(title: String(title), explanation: rest.isEmpty ? nil : String(rest)))
            } else {
                // Entire line is title if no separator
                solutions.append(NewSolution(title: String(afterCheck), explanation: nil))
            }
        }
        
        // Recommendation:
        if let recLine = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("Recommendation:") }) {
            recommendation = recLine.replacingOccurrences(of: "Recommendation:", with: "").trimmingCharacters(in: .whitespaces)
        }
        
        // Punchline:
        if let punchLine = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("Punchline:") }) {
            punchline = punchLine.replacingOccurrences(of: "Punchline:", with: "").trimmingCharacters(in: .whitespaces)
        }
        
        return NewAgentOutput(
            product: product,
            industry: industry,
            platform: platform,
            solutions: solutions,
            recommendation: recommendation,
            punchline: punchline
        )
    }
}

// MARK: - Follow-up Bullets (✨ ...)
struct BulletPoint {
    let text: String
}

class BulletPointParser {
    static func parse(_ text: String) -> [BulletPoint] {
        let lines = text.components(separatedBy: .newlines)
        var bullets: [BulletPoint] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // Filter out Screens/Flows/COMMAND lines
            if trimmed.hasPrefix("👉") || trimmed.uppercased().hasPrefix("COMMAND:") { continue }
            if trimmed.hasPrefix("✨") {
                let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    bullets.append(BulletPoint(text: content))
                }
            }
        }
        return bullets
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
                    .font(.system(size: 14, weight: .regular))
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
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
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
                .font(.system(size: 14))
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary)
            
            Spacer()
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 8)
    }
}

struct ArgumentCard: View {
    let argument: Argument
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(argument.type == .issue ? "🔴" : "🟢")
                .font(.system(size: 14))
            
            Text(argument.text)
                .font(.system(size: 14))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(argument.type == .issue ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(argument.type == .issue ? Color.red.opacity(0.3) : Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Confidence Tag Component
struct ConfidenceTag: View {
    let confidenceLevel: ConfidenceLevel
    
    enum ConfidenceLevel {
        case high
        case medium
        case low
        
        var text: String {
            switch self {
            case .high: return "High Confidence"
            case .medium: return "Medium Confidence"
            case .low: return "Low Confidence"
            }
        }
        
        var iconName: String {
            switch self {
            case .high: return "checkmark.circle.fill"
            case .medium: return "clock.fill"
            case .low: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .high: return .green
            case .medium: return .yellow
            case .low: return .red
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: confidenceLevel.iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(confidenceLevel.color)
            
            Text(confidenceLevel.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
        )
    }
}

struct AgentOutputView: View {
    let output: AgentOutput
    let onSolutionMoreTapped: (String) -> Void
    @Binding var isArgumentsExpanded: Bool
    
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
                
                // Separator under solutions
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 1)
                    .padding(.vertical, 8)
            }
            
            // Arguments in a dedicated card
            if !output.categories.isEmpty && output.categories.contains(where: { !$0.arguments.isEmpty }) {
                VStack(alignment: .leading, spacing: 0) {
                    // Arguments card header with toggle button
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                            isArgumentsExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text("Arguments")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: isArgumentsExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(isArgumentsExpanded ? 0 : 0))
                                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: isArgumentsExpanded)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    
                    // Arguments content (collapsible)
                    if isArgumentsExpanded {
                        VStack(alignment: .leading, spacing: 8) {
            ForEach(output.categories.indices, id: \.self) { categoryIndex in
                let category = output.categories[categoryIndex]
                    
                    ForEach(category.arguments.indices, id: \.self) { argumentIndex in
                        ArgumentCard(argument: category.arguments[argumentIndex])
                    }
                }
            }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.95))
                        ))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                )
                
                // Confidence tag under arguments
                HStack {
                    ConfidenceTag(confidenceLevel: .medium)
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }
}

struct MenuBarView: View {
    @State private var userEmail: String = UserDefaults.standard.string(forKey: "user_email") ?? ""
    @State private var chatText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    // Replaced DustService with ChatService and shared settings
    @State private var currentSystemPrompt: String = ""
    @State private var currentProvider: String = ""
    @State private var currentModel: String = ""
    @State private var selectedImage: NSImage?
    @State private var loadingMessageIndex: Int = 0
    @State private var loadingTimer: Timer?
    @State private var selectedTags: Set<String> = []
    @State private var isAppButtonHovered: Bool = false
    @State private var isResetButtonHovered: Bool = false
    @State private var isScreenshotButtonHovered: Bool = false
    @State private var isUploadButtonHovered: Bool = false
    @State private var isSendButtonHovered: Bool = false
    
    // Multi-step flow state
    @State private var currentStep: Int = 1
    @State private var selectedInputType: String = ""
    @State private var selectedProductType: String = ""
    @State private var descriptionText: String = ""
    @State private var isCapturingScreenshot: Bool = false
    @State private var screenshotTimeoutTimer: Timer?
    @State private var isArgumentsExpanded: Bool = false
    
    // Conversation management (simplified - no UI)
    @State private var currentConversationId: String?
    
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
            return ""
    }
    
    // Computed property for placeholder text
    private var placeholderText: String {
        if isLoading {
            return loadingMessages[loadingMessageIndex]
        } else if selectedImage != nil {
            switch currentStep {
            case 1:
                return "Select input type"
            case 2:
                return "Select product type"
            case 3:
                return "What is the app about?"
            default:
                return "Ask anything"
            }
        } else {
            return "Ask anything"
        }
    }
    
    init() {
        print("📱 [DEBUG] MenuBarView initializing")
    }
    
    // Build last 20 messages (10 turns) history for API
    private func buildHistoryDTO() -> [ChatMessageDTO] {
        let mapped = messages.map { msg in
            ChatMessageDTO(role: msg.sender == .user ? "user" : "assistant", content: msg.text)
        }
        return Array(mapped.suffix(20))
    }

    private func loadUserEmail() {
        let storedEmail = UserDefaults.standard.string(forKey: "user_email") ?? ""
        print("🔍 [MenuBarView] Loading email from UserDefaults: '\(storedEmail)'")
        userEmail = storedEmail
        print("🔍 [MenuBarView] userEmail state updated to: '\(userEmail)'")
        
        // No conversation history loading - Mac app only caches local messages
        if !userEmail.isEmpty {
            // Only create a new conversation when there isn't one already and
            // we're not currently displaying or streaming messages.
            if currentConversationId == nil && messages.isEmpty && !isLoading {
                createNewConversation()
            }
        }
    }
    
    
    // Load shared settings from Supabase
    private func loadSharedSettings() {
        Task {
            do {
                let (systemPrompt, provider, model) = try await SettingsService.shared.loadSharedSettings(email: userEmail)
                await MainActor.run {
                    self.currentSystemPrompt = systemPrompt
                    self.currentProvider = provider
                    self.currentModel = model
                }
            } catch {
                print("⚠️ Failed to load shared settings: \(error)")
            }
        }
    }
    
    // Create new conversation (simplified - no UI)
    private func createNewConversation() {
        guard !userEmail.isEmpty else { return }
        
        Task {
            do {
                let conversation = try await ConversationService.shared.createConversation(email: userEmail)
                await MainActor.run {
                    self.currentConversationId = conversation.id
                }
            } catch {
                print("⚠️ Failed to create conversation: \(error)")
            }
        }
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
        Group {
            if !userEmail.isEmpty {
                VStack(spacing: 16) {
                    headerSection
                    mainContent
                }
                .padding(12)
                .frame(minWidth: 380, maxWidth: .infinity)
                .frame(minHeight: messages.isEmpty ? 120 : 720, maxHeight: .infinity)
                .background(Color.clear) // Ensure transparent background for glass effect
                    .onAppear {
                        loadUserEmail()
                        loadSharedSettings()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                        loadUserEmail()
                        loadSharedSettings()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EmailStored"))) { _ in
                        print("🔍 [MenuBarView] Received EmailStored notification")
                        loadUserEmail()
                        loadSharedSettings()
                    }
            } else {
                AuthView(userEmail: $userEmail)
            }
        }
        // Environment hook to send "Go deeper" programmatically
        .environment(\.sendGoDeeper, { details in
            sendTaggedMessage(details)
        })
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Spacer()
            
            // Right side: Action buttons
            HStack(spacing: 0) {
                // Reset button
                Button(action: {
                    resetConversation()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .regular))
                        
                        if isResetButtonHovered {
                            Text("Reset")
                                .font(.system(size: 14, weight: .regular))
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                    .foregroundColor(.primary.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 80)
                            .fill(isResetButtonHovered ? Color.clear : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 80)
                            .stroke(isResetButtonHovered ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isResetButtonHovered = isHovering
                    }
                }
                
                // App button
                Button(action: {
                    // Open ChewieAI website
                    if let url = URL(string: "https://maximegerardin97-max.github.io/chewieai-fe-clean/") {
                        NSWorkspace.shared.open(url)
                    }
                    print("📱 [DEBUG] App button tapped - opening ChewieAI website")
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.primary.opacity(0.5))
                        
                        if isAppButtonHovered {
                            Text("App")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.primary.opacity(0.5))
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 80)
                            .fill(isAppButtonHovered ? Color.clear : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 80)
                            .stroke(isAppButtonHovered ? Color.white.opacity(0.2) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAppButtonHovered = isHovering
                    }
                }
                
                // Profile button with dropdown
                Menu {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Logged in as")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(userEmail)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    Button(action: {
                        // Clear stored email and reset to auth view
                        UserDefaults.standard.removeObject(forKey: "user_email")
                        userEmail = ""
                        // Clear local messages when signing out
                        messages.removeAll()
                        currentConversationId = nil
                    }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text(userEmail.components(separatedBy: "@").first ?? "User")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Profile & Settings")
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
        .frame(height: 36) // Fixed height to prevent layout shift on hover
    }
    
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 16) {
            messagesArea
            chatInputSection
        }
    }
    
    // MARK: - Messages Area
    private var messagesArea: some View {
        Group {
            if !messages.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(messages.indices, id: \.self) { index in
                                messageView(for: messages[index], at: index)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: messages.count) {
                        // Scroll to the latest message when new messages are added
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("message-\(messages.count - 1)", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Individual Message View
    private func messageView(for message: ChatMessage, at index: Int) -> some View {
        Group {
            // Prefer structured solution rendering when present, to avoid being overridden by a trailing Recommendation line
            if message.text.contains("⭐️") || message.text.contains("🔴") || message.text.contains("🟢") || message.text.contains("✅") || message.text.contains("Product:") {
                let output = NewAgentOutputParser.parse(message.text)
                // If the new-structure parser yields solutions, render with NewAgentOutputView; otherwise fallback to legacy parser
                if !output.solutions.isEmpty || message.text.contains("Product:") {
                    NewAgentOutputView(output: output)
                        .padding(.horizontal, 8)
                        .id("message-\(index)")
                } else {
                    let legacy = AgentOutputParser.parse(message.text)
                    AgentOutputView(
                        output: legacy,
                        onSolutionMoreTapped: { solution in
                            sendTaggedMessage(solution)
                        },
                        isArgumentsExpanded: $isArgumentsExpanded
                    )
                    .padding(.horizontal, 8)
                    .id("message-\(index)")
                }
            } else if message.text.contains("✨") || message.text.contains("Recommendation:") || message.text.contains("Punchline:") {
                // Follow-up bullets & recommendation-only messages
                let bullets = BulletPointParser.parse(message.text)
                let output = NewAgentOutputParser.parse(message.text)
                FollowUpCombinedView(bullets: bullets, recommendation: output.recommendation, punchline: output.punchline)
                    .padding(.horizontal, 8)
                    .id("message-\(index)")
            } else if message.text.contains("Product:") || message.text.contains("Punchline:") {
                let output = NewAgentOutputParser.parse(message.text)
                NewAgentOutputView(output: output)
                    .padding(.horizontal, 8)
                    .id("message-\(index)")
            } else if message.text.contains("⭐️") || message.text.contains("🔴") || message.text.contains("🟢") || message.text.contains("✅") {
                // Parse and display as structured cards
                let output = AgentOutputParser.parse(message.text)
                AgentOutputView(
                    output: output,
                    onSolutionMoreTapped: { solution in
                        sendTaggedMessage(solution)
                    },
                    isArgumentsExpanded: $isArgumentsExpanded
                )
                .padding(.horizontal, 8)
                .id("message-\(index)")
            } else {
                // Display as regular message with optional image
                regularMessageView(for: message, at: index)
            }
        }
    }

    // MARK: - New Output Views
    struct NewAgentOutputView: View {
        let output: NewAgentOutput
        @Environment(\.sendGoDeeper) private var sendGoDeeper
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                if let header = headerText(output: output) {
                    Text(header)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 8)
                }
                
                // Up to 3 solution cards with collapsible explanation
                ForEach(Array(output.solutions.prefix(3)).indices, id: \.self) { idx in
                    NewSolutionCard(solution: output.solutions[idx]) { details in
                        sendGoDeeper?(details)
                    }
                }
                
                if let rec = output.recommendation, !rec.isEmpty {
                    RecommendationCard(text: rec)
                }
                
                if let punch = output.punchline, !punch.isEmpty {
                    PunchlineCard(text: punch)
                }
            }
        }
        
        private func headerText(output: NewAgentOutput) -> String? {
            let parts: [String] = [
                output.product.map { "Product: \($0)" },
                output.industry.map { "Industry: \($0)" },
                output.platform.map { "Platform: \($0)" }
            ].compactMap { $0 }
            guard !parts.isEmpty else { return nil }
            return parts.joined(separator: "  |  ")
        }
    }
    
    struct NewSolutionCard: View {
        let solution: NewSolution
        @State private var expanded: Bool = false
        var onGoDeeper: ((String) -> Void)? = nil
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("✅")
                        .font(.system(size: 16))
                    
                    Text(solution.title)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    Button("Go deeper") {
                        let details = buildDetails()
                        onGoDeeper?(details)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                if let explanation = solution.explanation, !explanation.isEmpty {
                    Button(expanded ? "Hide details" : "Show why") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                            expanded.toggle()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    if expanded {
                        Text(explanation)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        
        private func buildDetails() -> String {
            if let explanation = solution.explanation, !explanation.isEmpty {
                return "\(solution.title)\n\n\(explanation)\n\nTell me more about this"
            } else {
                return "\(solution.title)\n\nTell me more about this"
            }
        }
    }
    
    struct RecommendationCard: View {
        let text: String
        @State private var expanded: Bool = false
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recommendation")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button(expanded ? "Hide" : "Show") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                            expanded.toggle()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                if expanded {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.primary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
            )
        }
    }
    
    struct PunchlineCard: View {
        let text: String
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("💡")
                        .font(.system(size: 16))
                    Text(text)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Bullet Cards View (✨ ...)
    struct BulletCardsView: View {
        let bullets: [BulletPoint]
        @Environment(\.sendGoDeeper) private var sendGoDeeper
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(bullets.indices, id: \.self) { idx in
                    HStack(alignment: .top, spacing: 8) {
                        Text("✨")
                            .font(.system(size: 16))
                        Text(bullets[idx].text)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Button("Go deeper") {
                            let details = buildDetails(text: bullets[idx].text)
                            sendGoDeeper?(details)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    )
                }
            }
        }
        
        private func buildDetails(text: String) -> String {
            return "\(text)\n\nTell me more about this"
        }
    }

    // MARK: - Follow-up Combined View (✨ bullets + optional recommendation/punchline)
    struct FollowUpCombinedView: View {
        let bullets: [BulletPoint]
        let recommendation: String?
        let punchline: String?
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                if !bullets.isEmpty {
                    BulletCardsView(bullets: bullets)
                }
                if let rec = recommendation, !rec.isEmpty {
                    RecommendationCard(text: rec)
                }
                if let p = punchline, !p.isEmpty {
                    PunchlineCard(text: p)
                }
            }
        }
    }
    
    // MARK: - Regular Message View
    private func regularMessageView(for message: ChatMessage, at index: Int) -> some View {
        VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 12) {
            if let image = message.image {
                messageImageView(image: image, sender: message.sender)
            }
            
            if !message.text.isEmpty {
                messageTextView(text: message.text, sender: message.sender)
            }
        }
        .id("message-\(index)")
        .padding(.vertical, 4)
    }
    
    // MARK: - Message Image View
    private func messageImageView(image: NSImage, sender: MessageSender) -> some View {
        VStack(alignment: sender == .user ? .trailing : .leading, spacing: 8) {
            // Image container with enhanced styling
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 240)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .opacity(0.8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            // Optional: Add a subtle caption or timestamp
            if sender == .user {
                Text("Image")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            }
        }
    }
    
    // MARK: - Message Text View
    private func messageTextView(text: String, sender: MessageSender) -> some View {
        HStack {
            if sender == .user {
                Spacer()
            }
            
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .lineLimit(nil)
                .multilineTextAlignment(sender == .user ? .trailing : .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(sender == .user 
                            ? Color.blue.opacity(0.9) 
                            : Color(NSColor.controlBackgroundColor).opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(sender == .user 
                            ? Color.blue.opacity(0.3) 
                            : .white.opacity(0.2), lineWidth: 1)
                )
                .foregroundStyle(
                    sender == .user 
                    ? Color.white 
                    : Color.primary
                )
                .frame(maxWidth: 320, alignment: sender == .user ? .trailing : .leading)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            if sender == .agent {
                Spacer()
            }
        }
    }
    
    // MARK: - Chat Input Section
    private var chatInputSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                screenScanButton
                imageUploadButton
                textInputArea
            }
        }
    }
    
    // MARK: - Screen Scan Button
    private var screenScanButton: some View {
        Group {
            if selectedImage == nil {
                Button(action: {
                    if !isLoading && !isCapturingScreenshot {
                        captureScreenshot()
                    }
                }) {
                    Image(systemName: isCapturingScreenshot ? "camera.fill" : "camera.viewfinder")
                        .font(.system(size: 16))
                        .foregroundColor(isLoading ? .secondary.opacity(0.5) : (isCapturingScreenshot ? .green : .secondary))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.regularMaterial)
                                .opacity(isLoading ? 0.5 : 1.0)
                                .overlay(
                                    isCapturingScreenshot ? 
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.green.opacity(0.2)) : nil
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(isLoading || isCapturingScreenshot)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isCapturingScreenshot ? Color.green.opacity(0.4) : (isScreenshotButtonHovered ? .white.opacity(0.5) : .white.opacity(0.3)), lineWidth: 0.5)
                )
                .help(isLoading ? "Please wait..." : (isCapturingScreenshot ? "Capturing screenshot..." : "Take screenshot of your design"))
                .onHover { isHovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isScreenshotButtonHovered = isHovering
                    }
                }
            }
        }
    }
    
    // MARK: - Image Upload Button
    private var imageUploadButton: some View {
        ZStack {
            Button(action: {
                if !isLoading && selectedImage == nil {
                    selectImageFile()
                }
            }) {
                Image(systemName: selectedImage != nil ? "photo.fill" : "photo")
                    .font(.system(size: 16))
                    .foregroundColor(isLoading ? .secondary.opacity(0.5) : (selectedImage != nil ? .blue : .secondary))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .opacity(isLoading ? 0.5 : 1.0)
                            .overlay(
                                selectedImage != nil ? 
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.2)) : nil
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedImage != nil ? Color.blue.opacity(0.4) : (isUploadButtonHovered ? .white.opacity(0.5) : .white.opacity(0.3)), lineWidth: 0.5)
            )
            .help(isLoading ? "Please wait..." : (selectedImage != nil ? "Remove image" : "Upload image"))
            .onHover { isHovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isUploadButtonHovered = isHovering
                }
            }
            
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
    }
    
    // MARK: - Text Input Area
    private var textInputArea: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                if selectedImage == nil {
                    basicTextInput
                }
                
                if selectedImage != nil {
                    multiStepInput
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .opacity(isLoading ? 0.5 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.3), lineWidth: 0.5)
            )
            
            // Send button - only show when no image (step 3 has its own send button)
            if selectedImage == nil {
                sendButton
            }
            
            // Next button for steps 1 and 2 - positioned on the right side
            if selectedImage != nil && currentStep < 3 {
                nextButton
            }
        }
    }
    
    // MARK: - Basic Text Input
    private var basicTextInput: some View {
        TextField(placeholderText, text: $chatText)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.trailing, 40) // Make space for the send button
            .frame(height: 44)
            .background(Color.clear)
            .disabled(isLoading)
            .onSubmit {
                if !isLoading {
                    sendMessage()
                }
            }
    }
    
    // MARK: - Multi-Step Input
    private var multiStepInput: some View {
        VStack(spacing: 0) {
            stepContent
            progressBar
        }
    }
    
    // MARK: - Step Content
    private var stepContent: some View {
        Group {
            switch currentStep {
            case 1:
                step1Content
            case 2:
                step2Content
            case 3:
                step3Content
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Step 1 Content
    private var step1Content: some View {
        VStack(spacing: 12) {
            // Step title
            HStack {
                Text("Image type?")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.primary .opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Tags
            HStack(spacing: 4) {
                inputTypeButton("Component")
                inputTypeButton("Screen")
                inputTypeButton("Flow")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Step 2 Content
    private var step2Content: some View {
        VStack(spacing: 12) {
            // Step title with back button
            HStack {
                Button(action: {
                    currentStep = 1
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.primary .opacity(0.5))
                }
                .buttonStyle(.plain)
                
                Text("Product type?")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.primary .opacity(0.5))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Tags
            HStack(spacing: 4) {
                productTypeButton("SaaS")
                productTypeButton("Mobile")
                productTypeButton("Ecommerce")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Step 3 Content
    private var step3Content: some View {
        VStack(spacing: 12) {
            // Step title with back button
            HStack {
                Button(action: {
                    currentStep = 2
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.primary .opacity(0.5))
                }
                .buttonStyle(.plain)
                
                Text("Additional context?")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.primary .opacity(0.5))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Text input for step 3 with send button
            ZStack(alignment: .trailing) {
                TextField(placeholderText, text: $descriptionText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.trailing, 40) // Make space for the send button
                    .background(Color.clear)
                    .disabled(isLoading)
                    .onSubmit {
                        if !isLoading {
                            handleStepAction()
                        }
                    }
                
                // Send button for step 3
                Button(action: {
                    handleStepAction()
                }) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isButtonDisabled())
                .padding(.trailing, 12)
            }
        }
    }
    
    // MARK: - Input Type Button
    private func inputTypeButton(_ type: String) -> some View {
        Button(type) {
            selectedInputType = type
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 80)
                .fill(selectedInputType == type ? Color.white : Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 80)
                .stroke(selectedInputType == type ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
        )
        .foregroundStyle(selectedInputType == type ? Color.blue : Color.white.opacity(0.5))
    }
    
    // MARK: - Product Type Button
    private func productTypeButton(_ type: String) -> some View {
        Button(type) {
            selectedProductType = type
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 80)
                .fill(selectedProductType == type ? Color.white : Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 80)
                .stroke(selectedProductType == type ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
        )
        .foregroundStyle(selectedProductType == type ? Color.blue : Color.white.opacity(0.5))
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background bar
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                
                // Progress bar
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * getProgressPercentage(), height: 1)
            }
        }
        .frame(height: 1)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Send Button
    private var sendButton: some View {
        Button(action: {
            sendMessage()
        }) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                // Show send icon for no image
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isSendButtonHovered ? .white.opacity(0.8) : .white)
            }
        }
        .buttonStyle(.borderless)
        .disabled(isButtonDisabled())
        .padding(.trailing, 12)
        .padding(.bottom, 0)
        .onHover { isHovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isSendButtonHovered = isHovering
            }
        }
    }
    
    // MARK: - Next Button
    private var nextButton: some View {
        Button(action: {
            handleStepAction()
        }) {
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color.white.opacity(0.5))
        }
        .buttonStyle(.borderless)
        .disabled(isButtonDisabled())
        .padding(.trailing, 12)
        .padding(.bottom, 8)
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
    
    private func getProgressPercentage() -> Double {
        switch currentStep {
        case 1:
            return 0.33 // 33%
        case 2:
            return 0.66 // 66%
        case 3:
            return 1.0  // 100%
        default:
            return 0.0
        }
    }
    
    private func captureScreenshot() {
        print("📱 [DEBUG] Screenshot capture button tapped")
        
        // Set capturing state
        isCapturingScreenshot = true
        
        // Start timeout timer (30 seconds)
        screenshotTimeoutTimer?.invalidate()
        screenshotTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            print("📱 [DEBUG] Screenshot capture timeout - resetting state")
            self.isCapturingScreenshot = false
        }
        
        // Hide the app window
        if let window = NSApplication.shared.windows.first {
            window.orderOut(nil)
        }
        
        // Use screencapture command line tool for area selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"] // -i for interactive (area selection), -c for clipboard
            
            print("📱 [DEBUG] Launching screencapture command")
            task.launch()
            task.waitUntilExit()
            
            print("📱 [DEBUG] Screencapture command completed with exit code: \(task.terminationStatus)")
            
            // Wait a bit then show the app again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showAppAndCheckForScreenshot()
            }
        }
    }
    
    private func showAppAndCheckForScreenshot() {
        // Show the app window again
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        
        // Check for the most recent screenshot in the clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkClipboardForScreenshot()
        }
    }
    
    private func checkClipboardForScreenshot() {
        let pasteboard = NSPasteboard.general
        
        // Check if there's an image in the clipboard
        if let image = NSImage(pasteboard: pasteboard) {
            print("📱 [DEBUG] Found screenshot in clipboard, size: \(image.size)")
            
            // Cancel timeout timer
            screenshotTimeoutTimer?.invalidate()
            screenshotTimeoutTimer = nil
            
            // Set the image and start the multi-step flow
            selectedImage = image
            currentStep = 1
            selectedInputType = ""
            selectedProductType = ""
            descriptionText = ""
            
            // Clear the clipboard
            pasteboard.clearContents()
            
            // Reset capturing state since screenshot was successfully captured
            isCapturingScreenshot = false
            
            print("📱 [DEBUG] Screenshot added to chat and multi-step flow started")
                } else {
            print("📱 [DEBUG] No screenshot found in clipboard")
            print("📱 [DEBUG] Clipboard types: \(pasteboard.types ?? [])")
            
            // Try again after a short delay in case the screenshot is still being processed
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkClipboardForScreenshot()
            }
        }
    }
    
    private func resetConversation() {
        print("📱 [DEBUG] Reset conversation button tapped")
        
        // Clear all conversation data
        messages.removeAll()
        chatText = ""
        selectedImage = nil
        selectedTags.removeAll()
        
        // Reset multi-step flow
        currentStep = 1
        selectedInputType = ""
        selectedProductType = ""
        descriptionText = ""
        
        // Reset screenshot capturing state
        isCapturingScreenshot = false
        screenshotTimeoutTimer?.invalidate()
        screenshotTimeoutTimer = nil
        
        // Reset arguments expanded state
        isArgumentsExpanded = false
        
        // Stop any ongoing loading
        isLoading = false
        stopLoadingMessages()
        
        // Create new conversation for data sync
        createNewConversation()
    }
    
    private func handleStepAction() {
        switch currentStep {
        case 1:
            // Step 1: Check if input type is selected, then go to step 2
            if !selectedInputType.isEmpty {
                currentStep = 2
            }
        case 2:
            // Step 2: Check if product type is selected, then go to step 3
            if !selectedProductType.isEmpty {
                currentStep = 3
            }
        case 3:
            // Step 3: Send the final message
            sendFinalMessage()
        default:
            break
        }
    }
    
    private func isButtonDisabled() -> Bool {
        if isLoading {
            return true
        }
        
        if selectedImage != nil {
            switch currentStep {
            case 1:
                return selectedInputType.isEmpty
            case 2:
                return selectedProductType.isEmpty
            case 3:
                return descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            default:
                return true
            }
        } else {
            return chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func sendFinalMessage() {
        // Build the final message with all selected options
        var messageText = ""
        
        if !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messageText = descriptionText
        }
        
        // Add selected options
        let options = [selectedInputType, selectedProductType].filter { !$0.isEmpty }
        if !options.isEmpty {
            let optionsText = "Options: " + options.joined(separator: ", ")
            if messageText.isEmpty {
                messageText = optionsText
            } else {
                messageText = "\(messageText)\n\n\(optionsText)"
            }
        }
        
        // Add user message to chat
        let message = ChatMessage(text: messageText, image: selectedImage, sender: .user)
        messages.append(message)
        
        // Clear input and reset flow
        chatText = ""
        let imageToSend = selectedImage
        selectedImage = nil
        selectedTags.removeAll()
        currentStep = 1
        selectedInputType = ""
        selectedProductType = ""
        descriptionText = ""
        
        // Send to AI
        isLoading = true
        startLoadingMessages()
        
        // Streaming call via ChatService
        var assistantIndex: Int?
        messages.append(ChatMessage(text: "", sender: .agent))
        assistantIndex = messages.count - 1
        let historyDTO = buildHistoryDTO()
        
        // Use email-based ChatService with conversation ID
        guard !userEmail.isEmpty else {
            DispatchQueue.main.async {
                if let idx = assistantIndex {
                    messages[idx] = ChatMessage(text: "Error: Not authenticated", sender: .agent)
                }
                isLoading = false
                stopLoadingMessages()
            }
            return
        }
        
        ChatService.shared.sendChat(
            provider: currentProvider,
            model: currentModel,
            systemPrompt: currentSystemPrompt,
            messageText: messageText.isEmpty ? "please analyze this picture" : messageText,
            image: imageToSend,
            history: historyDTO,
            conversationId: currentConversationId,
            email: userEmail,
            onDelta: { delta in
                DispatchQueue.main.async {
                    if let idx = assistantIndex {
                        let existing = messages[idx]
                        messages[idx] = ChatMessage(text: existing.text + delta, sender: .agent)
                    }
                }
            },
            onDone: { finalText in
                DispatchQueue.main.async {
                    isLoading = false
                    stopLoadingMessages()
                }
            },
            onError: { error in
                DispatchQueue.main.async {
                    if let idx = assistantIndex {
                        messages[idx] = ChatMessage(text: "Error: \(error.localizedDescription)", sender: .agent)
                    } else {
                        messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", sender: .agent))
                    }
                    isLoading = false
                    stopLoadingMessages()
                }
            }
        )
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
        
        var assistantIndex: Int?
        messages.append(ChatMessage(text: "", sender: .agent))
        assistantIndex = messages.count - 1
        let historyDTO = buildHistoryDTO()
        
        // Use email-based ChatService with conversation ID
        guard !userEmail.isEmpty else {
            DispatchQueue.main.async {
                if let idx = assistantIndex {
                    messages[idx] = ChatMessage(text: "Error: Not authenticated", sender: .agent)
                }
                isLoading = false
                stopLoadingMessages()
            }
            return
        }
        
        ChatService.shared.sendChat(
            provider: currentProvider,
            model: currentModel,
            systemPrompt: currentSystemPrompt,
            messageText: taggedMessage.isEmpty ? "please analyze this picture" : taggedMessage,
            image: nil,
            history: historyDTO,
            conversationId: currentConversationId,
            email: userEmail,
            onDelta: { delta in
                DispatchQueue.main.async {
                    if let idx = assistantIndex {
                        let existing = messages[idx]
                        messages[idx] = ChatMessage(text: existing.text + delta, sender: .agent)
                    }
                }
            },
            onDone: { _ in
                DispatchQueue.main.async {
                    isLoading = false
                    stopLoadingMessages()
                }
            },
            onError: { error in
                DispatchQueue.main.async {
                    if let idx = assistantIndex {
                        messages[idx] = ChatMessage(text: "Error: \(error.localizedDescription)", sender: .agent)
                    } else {
                        messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", sender: .agent))
                    }
                    isLoading = false
                    stopLoadingMessages()
                }
            }
        )
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
        
        var assistantIndex: Int?
        messages.append(ChatMessage(text: "", sender: .agent))
        assistantIndex = messages.count - 1
        let historyDTO = buildHistoryDTO()
        
        // Use email-based ChatService with conversation ID
        guard !userEmail.isEmpty else {
            DispatchQueue.main.async {
                if let idx = assistantIndex {
                    messages[idx] = ChatMessage(text: "Error: Not authenticated", sender: .agent)
                }
                isLoading = false
                stopLoadingMessages()
            }
            return
        }
        
        ChatService.shared.sendChat(
            provider: currentProvider,
            model: currentModel,
            systemPrompt: currentSystemPrompt,
            messageText: messageText.isEmpty ? "please analyze this picture" : messageText,
            image: imageToSend,
            history: historyDTO,
            conversationId: currentConversationId,
            email: userEmail,
            onDelta: { delta in
                DispatchQueue.main.async {
                    if let idx = assistantIndex {
                        let existing = messages[idx]
                        messages[idx] = ChatMessage(text: existing.text + delta, sender: .agent)
                    }
                }
            },
            onDone: { _ in
                DispatchQueue.main.async {
                    isLoading = false
                    stopLoadingMessages()
                }
            },
            onError: { error in
                DispatchQueue.main.async {
                    if let idx = assistantIndex {
                        messages[idx] = ChatMessage(text: "Error: \(error.localizedDescription)", sender: .agent)
                    } else {
                        messages.append(ChatMessage(text: "Error: \(error.localizedDescription)", sender: .agent))
                    }
                    isLoading = false
                    stopLoadingMessages()
                }
            }
        )
    }
}
