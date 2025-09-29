//
//  ChatService.swift
//  macchewie
//

import Foundation
import AppKit

struct ChatMessageDTO: Codable {
    let role: String
    let content: String
}

struct SSEEvent: Decodable {
    let type: String
    let delta: String?
    let content: String?
}

enum ChatServiceError: Error, LocalizedError {
    case invalidUrl
    case httpError(Int)
    case streamError
    case encodingError
    case notAuthenticated
    case conversationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl: return "Invalid URL"
        case .httpError(let code): return "HTTP error: \(code)"
        case .streamError: return "Streaming error"
        case .encodingError: return "Encoding error"
        case .notAuthenticated: return "User not authenticated"
        case .conversationError(let message): return "Conversation error: \(message)"
        }
    }
}

class ChatService {
    static let shared = ChatService()
    private init() {}
    
    private let supabaseUrl = "https://iiolvvdnzrfcffudwocp.supabase.co"
    
    // Convert NSImage to data URL base64
    private func imageToDataUrl(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }
        return "data:image/jpeg;base64,\(imageData.base64EncodedString())"
    }
    
    // Build message payload (text or multimodal)
    private func buildUserMessagePayload(text: String, image: NSImage?) -> Any {
        if let image = image, let dataUrl = imageToDataUrl(image) {
            return [
                ["type": "text", "text": text.isEmpty ? "Please analyze this image." : text],
                ["type": "image_url", "image_url": ["url": dataUrl, "detail": "auto"]]
            ]
        } else {
            return text
        }
    }
    
    func sendChat(provider: String,
                  model: String,
                  systemPrompt: String,
                  messageText: String,
                  image: NSImage?,
                  history: [ChatMessageDTO],
                  conversationId: String?,
                  email: String,
                  onDelta: @escaping (String) -> Void,
                  onDone: @escaping (String) -> Void,
                  onError: @escaping (Error) -> Void) {
        
        guard !email.isEmpty else {
            onError(ChatServiceError.notAuthenticated)
            return
        }
        
        guard let url = URL(string: "\(supabaseUrl)/functions/v1/llm-proxy-public") else {
            onError(ChatServiceError.invalidUrl)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlpb2x2dmRuenJmY2ZmdWR3b2NwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MjE4MDAsImV4cCI6MjA3MzA5NzgwMH0.2-e8Scn26fqsR11h-g4avH8MWybwLTtcf3fCN9qAgVw", forHTTPHeaderField: "apikey")
        request.setValue("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlpb2x2dmRuenJmY2ZmdWR3b2NwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MjE4MDAsImV4cCI6MjA3MzA5NzgwMH0.2-e8Scn26fqsR11h-g4avH8MWybwLTtcf3fCN9qAgVw", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "email": email,
            "message": buildUserMessagePayload(text: messageText, image: image),
            "provider": provider,
            "model": model,
            "conversation_id": conversationId as Any,
            "system": systemPrompt,
            "history": history.map { [
                "role": $0.role,
                "content": $0.content
            ] }
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = data
        } catch {
            onError(ChatServiceError.encodingError)
            return
        }
        
        // Make the request with simple retry/backoff for transient errors
        Task {
            let transientCodes: Set<Int> = [502, 503, 504]
            let maxAttempts = 3
            var attempt = 0
            var lastError: Error?
            while attempt < maxAttempts {
                do {
                    attempt += 1
                    print("🤖 [ChatService] Starting request to llm-proxy-public (attempt \(attempt))")
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ChatServiceError.invalidUrl
                    }
                    
                    if httpResponse.statusCode == 200 {
                        let responseData = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                        if let responseText = responseData["response"] as? String {
                            let words = responseText.components(separatedBy: " ")
                            var currentText = ""
                            for word in words {
                                let chunk = word + " "
                                currentText += chunk
                                onDelta(chunk)
                                try await Task.sleep(nanoseconds: 50_000_000)
                            }
                            onDone(currentText.trimmingCharacters(in: .whitespaces))
                            return
                        } else {
                            throw ChatServiceError.streamError
                        }
                    } else if transientCodes.contains(httpResponse.statusCode) && attempt < maxAttempts {
                        let backoffMs = UInt64(pow(2.0, Double(attempt - 1)) * 500)
                        try await Task.sleep(nanoseconds: backoffMs * 1_000_000)
                        continue
                    } else {
                        let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: String]
                        throw ChatServiceError.conversationError(errorResponse?["error"] ?? "HTTP error: \(httpResponse.statusCode)")
                    }
                } catch {
                    lastError = error
                    let nsError = error as NSError
                    let isTransientNetwork = (nsError.domain == NSURLErrorDomain) && (nsError.code == NSURLErrorTimedOut || nsError.code == NSURLErrorNetworkConnectionLost)
                    if isTransientNetwork && attempt < maxAttempts {
                        let backoffMs = UInt64(pow(2.0, Double(attempt - 1)) * 500)
                        print("🤖 [ChatService] Transient network error (\(nsError.code)), retrying in \(backoffMs)ms")
                        try await Task.sleep(nanoseconds: backoffMs * 1_000_000)
                        continue
                    } else {
                        print("🤖 [ChatService] Request exception: \(error)")
                        onError(error)
                        return
                    }
                }
            }
            if let lastError = lastError {
                onError(lastError)
            } else {
                onError(ChatServiceError.streamError)
            }
        }
    }
    
    // Legacy method for backward compatibility (with email)
    func sendChat(provider: String,
                  model: String,
                  systemPrompt: String,
                  messageText: String,
                  image: NSImage?,
                  history: [ChatMessageDTO],
                  onDelta: @escaping (String) -> Void,
                  onDone: @escaping (String) -> Void,
                  onError: @escaping (Error) -> Void) {
        
        // Get email from UserDefaults
        let email = UserDefaults.standard.string(forKey: "user_email") ?? ""
        
        // Use the new email-based method
        sendChat(provider: provider,
                model: model,
                systemPrompt: systemPrompt,
                messageText: messageText,
                image: image,
                history: history,
                conversationId: nil,
                email: email,
                onDelta: onDelta,
                onDone: onDone,
                onError: onError)
    }
    
}


