//
//  SettingsService.swift
//  macchewie
//

import Foundation

struct SharedSettings: Decodable {
    let system_prompt: String
    let provider: String
    let model: String
}

enum SettingsServiceError: Error {
    case invalidUrl
    case invalidResponse
    case httpError(Int)
    case notAuthenticated
    case apiError(String)
}

class SettingsService {
    static let shared = SettingsService()
    private init() {}
    
    private let supabaseUrl = "https://iiolvvdnzrfcffudwocp.supabase.co"
    
    func loadSharedSettings(email: String) async throws -> (systemPrompt: String, provider: String, model: String) {
        guard !email.isEmpty else {
            throw SettingsServiceError.notAuthenticated
        }
        
        // Use the new public endpoint that doesn't require JWT
        guard let url = URL(string: "\(supabaseUrl)/functions/v1/llm-proxy-public/settings") else {
            throw SettingsServiceError.invalidUrl
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlpb2x2dmRuenJmY2ZmdWR3b2NwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MjE4MDAsImV4cCI6MjA3MzA5NzgwMH0.2-e8Scn26fqsR11h-g4avH8MWybwLTtcf3fCN9qAgVw", forHTTPHeaderField: "apikey")
        request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlpb2x2dmRuenJmY2ZmdWR3b2NwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MjE4MDAsImV4cCI6MjA3MzA5NzgwMH0.2-e8Scn26fqsR11h-g4avH8MWybwLTtcf3fCN9qAgVw", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SettingsServiceError.invalidResponse }
        
        if http.statusCode == 200 {
            let settings = try JSONDecoder().decode(SharedSettings.self, from: data)
            return (settings.system_prompt, settings.provider, settings.model)
        } else {
            // If settings fail to load, return defaults instead of throwing error
            print("⚠️ [SettingsService] Failed to load settings (HTTP \(http.statusCode)), using defaults")
            return (
                systemPrompt: "You are a helpful AI assistant.",
                provider: "openai",
                model: "gpt-4"
            )
        }
    }
    
    // Legacy method for backward compatibility
    func loadSharedSettings() async throws -> (systemPrompt: String, provider: String, model: String) {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                let email = UserDefaults.standard.string(forKey: "user_email") ?? ""
                
                do {
                    let result = try await loadSharedSettings(email: email)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}


