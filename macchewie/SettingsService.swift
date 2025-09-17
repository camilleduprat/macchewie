//
//  SettingsService.swift
//  macchewie
//

import Foundation

struct SharedSettings: Decodable {
    let key: String
    let system_prompt: String
    let provider: String
    let model: String
}

enum SettingsServiceError: Error {
    case invalidUrl
    case invalidResponse
    case httpError(Int)
}

class SettingsService {
    static let shared = SettingsService()
    private init() {}
    
    func loadSharedSettings() async throws -> (systemPrompt: String, provider: String, model: String) {
        guard let url = URL(string: "\(AgentConfig.SUPABASE_URL)/rest/v1/app_settings?select=key,system_prompt,provider,model&key=eq.default") else {
            throw SettingsServiceError.invalidUrl
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(AgentConfig.SUPABASE_ANON, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AgentConfig.SUPABASE_ANON)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SettingsServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw SettingsServiceError.httpError(http.statusCode) }
        
        let items = try JSONDecoder().decode([SharedSettings].self, from: data)
        if let s = items.first {
            return (s.system_prompt, s.provider, s.model)
        }
        // Fallback defaults if table empty
        return ("You are a helpful assistant.", "openai", "gpt-4o-mini")
    }
}


