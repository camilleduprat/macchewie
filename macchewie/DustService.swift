//
//  DustService.swift
//  macchewie
//
//  Created by Camille Duprat on 10/09/2025.
//

import Foundation
import AppKit

// MARK: - Dust Service
@MainActor
class DustService: ObservableObject {
    private let supabaseUrl = "https://iiolvvdnzrfcffudwocp.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlpb2x2dmRuenJmY2ZmdWR3b2NwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU2MTIxNzQsImV4cCI6MjA3MTE4ODE3NH0.zm_bLL3lu2hXKqZdIHzH-bIgVwd1cM1jb7Cju92sl6E"
    
    // Supabase function endpoint
    private var designBrainEndpoint: String {
        return "\(supabaseUrl)/functions/v1/design-brain"
    }
    
    private var urlSession: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120  // 2 minutes for request
        config.timeoutIntervalForResource = 180 // 3 minutes total
        return URLSession(configuration: config)
    }
    
    @Published var lastResponse: String = ""
    @Published var lastError: String = ""
    
    func sendMessage(_ message: String, image: NSImage? = nil) async throws -> String {
        print("🤖 [DEBUG] Starting to send message: '\(message)'")
        
        do {
            // Convert image to base64 data URL if provided
            var imageUrl: String? = nil
            if let image = image {
                print("🤖 [DEBUG] Converting image to base64...")
                imageUrl = try await convertImageToDataURL(image)
                print("🤖 [DEBUG] ✅ Image converted to data URL")
            }
            
            // Call Supabase design-brain function
            print("🤖 [DEBUG] Calling Supabase design-brain function...")
            let result = try await callDesignBrainFunction(message: message, imageUrl: imageUrl)
            print("🤖 [DEBUG] ✅ Design analysis complete")
            
            return result
            
        } catch {
            print("🤖 [DEBUG] ❌ ERROR occurred: \(error)")
            print("🤖 [DEBUG] Error details: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Supabase Integration Functions
    
    private func convertImageToDataURL(_ image: NSImage) async throws -> String {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw DustError.invalidResponse
        }
        
        let base64String = imageData.base64EncodedString()
        return "data:image/jpeg;base64,\(base64String)"
    }
    
    private func callDesignBrainFunction(message: String, imageUrl: String?) async throws -> String {
        let url = URL(string: designBrainEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body matching your webapp structure
        let requestBody: [String: Any] = [
            "action": "analyze",
            "content": message,
            "imageUrl": imageUrl as Any,
            "username": "mac-user",
            "timezone": TimeZone.current.identifier
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        print("🤖 [DEBUG] Sending request to Supabase function...")
        print("🤖 [DEBUG] Request body: \(String(data: jsonData, encoding: .utf8) ?? "nil")")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DustError.invalidResponse
        }
        
        print("🤖 [DEBUG] Supabase response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🤖 [DEBUG] Supabase response: \(responseDict)")
                
                if let ok = responseDict["ok"] as? Bool, ok,
                   let data = responseDict["data"] as? [String: Any],
                   let text = data["text"] as? String {
                    return text
                } else if let error = responseDict["error"] as? [String: Any],
                          let hint = error["hint"] as? String {
                    throw DustError.apiError(statusCode: httpResponse.statusCode, message: hint)
                }
            }
        }
        
        // If we get here, something went wrong
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw DustError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
    }
}

// MARK: - Dust Error Types
enum DustError: Error, LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case streamError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "🤖 Invalid response from server"
        case .apiError(let _, let message):
            return "🤖 \(message)"
        case .streamError:
            return "🤖 Streaming issue - Couldn't get the agent's response in real-time"
        case .decodingError:
            return "🤖 Response format issue - The server sent data in an unexpected format"
        }
    }
}