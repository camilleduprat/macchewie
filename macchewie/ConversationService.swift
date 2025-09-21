//
//  ConversationService.swift
//  macchewie
//
//  Created by AI Assistant on 10/09/2025.
//

import Foundation

// MARK: - Conversation Models
struct Conversation: Codable, Identifiable {
    let id: String
    let title: String?
    let page_name: String?
    let created_at: String
    let updated_at: String
    let archived: Bool
}

struct Message: Codable, Identifiable {
    let id: Int
    let role: String // 'user', 'assistant', 'system'
    let content: MessageContent
    let is_final: Bool
    let chunk_index: Int?
    let created_at: String
}

struct MessageContent: Codable {
    let type: String // 'text', 'multimodal'
    let value: String
}

// MARK: - Conversation Service
class ConversationService {
    static let shared = ConversationService()
    private init() {}
    
    private let supabaseUrl = "https://iiolvvdnzrfcffudwocp.supabase.co"
    
    // MARK: - Conversation Management
    
    
    func createConversation(email: String) async throws -> Conversation {
        guard !email.isEmpty else {
            throw ConversationServiceError.notAuthenticated
        }
        
        let url = URL(string: "\(supabaseUrl)/functions/v1/llm-proxy-public/conversations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlpb2x2dmRuenJmY2ZmdWR3b2NwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MjE4MDAsImV4cCI6MjA3MzA5NzgwMH0.2-e8Scn26fqsR11h-g4avH8MWybwLTtcf3fCN9qAgVw", forHTTPHeaderField: "apikey")
        
        let body: [String: Any] = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConversationServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 201 {
            let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            if let conversationData = responseData["conversation"] as? [String: Any] {
                let conversationJson = try JSONSerialization.data(withJSONObject: conversationData)
                return try JSONDecoder().decode(Conversation.self, from: conversationJson)
            } else {
                throw ConversationServiceError.apiError("Invalid response format")
            }
        } else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            throw ConversationServiceError.apiError(errorResponse?["error"] ?? "Failed to create conversation")
        }
    }
    
    func listConversations(accessToken: String) async throws -> [Conversation] {
        let url = URL(string: "\(supabaseUrl)/functions/v1/llm-proxy-public/conversations")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConversationServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode([Conversation].self, from: data)
        } else {
            let errorResponse = try? JSONDecoder().decode([String: String].self, from: data)
            throw ConversationServiceError.apiError(errorResponse?["error"] ?? "Failed to list conversations")
        }
    }
    
    func updateConversation(accessToken: String, id: String, title: String) async throws {
        let url = URL(string: "\(supabaseUrl)/functions/v1/llm-proxy-public/conversations/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = ["title": title]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConversationServiceError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode([String: String].self, from: data)
            throw ConversationServiceError.apiError(errorResponse?["error"] ?? "Failed to update conversation")
        }
    }
    
    // MARK: - Message Management
    
    func listMessages(accessToken: String, conversationId: String) async throws -> [Message] {
        let url = URL(string: "\(supabaseUrl)/functions/v1/llm-proxy-public/messages?conversation_id=\(conversationId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConversationServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            if let messagesData = responseData["messages"] as? [[String: Any]] {
                let messagesJson = try JSONSerialization.data(withJSONObject: messagesData)
                return try JSONDecoder().decode([Message].self, from: messagesJson)
            } else {
                return []
            }
        } else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            throw ConversationServiceError.apiError(errorResponse?["error"] ?? "Failed to list messages")
        }
    }
    
    func sendMessage(accessToken: String, conversationId: String, message: String, provider: String?, model: String?) async throws -> Message {
        let url = URL(string: "\(supabaseUrl)/functions/v1/llm-proxy-public")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "message": message,
            "conversation_id": conversationId,
            "provider": provider as Any,
            "model": model as Any
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConversationServiceError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            // The response contains the AI response, not the message object
            // We'll need to create a message object from the response
            let messageContent = MessageContent(type: "text", value: responseData["response"] as? String ?? "")
            return Message(
                id: Int.random(in: 1000...9999), // Temporary ID
                role: "assistant",
                content: messageContent,
                is_final: true,
                chunk_index: nil,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
        } else {
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: String]
            throw ConversationServiceError.apiError(errorResponse?["error"] ?? "Failed to send message")
        }
    }
}

// MARK: - Error Types
enum ConversationServiceError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case apiError(String)
    case networkError(Int)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return "API error: \(message)"
        case .networkError(let statusCode):
            return "Network error: HTTP \(statusCode)"
        }
    }
}
