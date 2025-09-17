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
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl: return "Invalid URL"
        case .httpError(let code): return "HTTP error: \(code)"
        case .streamError: return "Streaming error"
        case .encodingError: return "Encoding error"
        }
    }
}

class ChatService {
    static let shared = ChatService()
    private init() {}
    
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
                  onDelta: @escaping (String) -> Void,
                  onDone: @escaping (String) -> Void,
                  onError: @escaping (Error) -> Void) {
        guard let url = URL(string: AgentConfig.CHAT_URL) else {
            onError(ChatServiceError.invalidUrl)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AgentConfig.SUPABASE_ANON, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AgentConfig.SUPABASE_ANON)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        
        let cappedHistory = Array(history.suffix(20))
        let body: [String: Any] = [
            "provider": provider,
            "model": model,
            "systemPrompt": systemPrompt,
            "message": buildUserMessagePayload(text: messageText, image: image),
            "history": cappedHistory.map { ["role": $0.role, "content": $0.content] }
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: [])
            request.httpBody = data
        } catch {
            onError(ChatServiceError.encodingError)
            return
        }
        
        // Stream using URLSession's bytes API
        Task {
            do {
                print("🤖 [ChatService] Starting stream request to: \(AgentConfig.CHAT_URL)")
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    print("🤖 [ChatService] HTTP status: \(http.statusCode)")
                    onError(ChatServiceError.httpError(http.statusCode))
                    return
                }
                var finalText = ""
                for try await line in bytes.lines {
                    guard !line.isEmpty else { continue }
                    // Debug raw SSE
                    // print("🤖 [ChatService] SSE:", line)
                    if line.hasPrefix("data:") {
                        let jsonString = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if jsonString == "[DONE]" { continue }
                        if let data = jsonString.data(using: .utf8),
                           let event = try? JSONDecoder().decode(SSEEvent.self, from: data) {
                            if event.type == "content" {
                                let piece = event.delta ?? event.content ?? ""
                                if !piece.isEmpty {
                                    finalText += piece
                                    onDelta(piece)
                                }
                            } else if event.type == "done" {
                                print("🤖 [ChatService] Stream done")
                                onDone(finalText)
                                return
                            } else if event.type == "error" {
                                print("🤖 [ChatService] Stream error event")
                                onError(ChatServiceError.streamError)
                                return
                            }
                        }
                    }
                }
                // If stream ends without done
                print("🤖 [ChatService] Stream ended without explicit done")
                onDone(finalText)
            } catch {
                print("🤖 [ChatService] Stream exception: \(error)")
                onError(error)
            }
        }
    }
}


