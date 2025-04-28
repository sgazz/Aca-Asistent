import Foundation

enum AIError: Error {
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case missingAPIKey
    case invalidURL
}

protocol AIServiceProtocol {
    func generateResponse(to message: String) async throws -> String
}

class OpenAIService: AIServiceProtocol {
    private let apiKey: String
    private let endpoint: String
    private let model: String
    
    init(apiKey: String, endpoint: String = "https://api.openai.com/v1/chat/completions", model: String = "gpt-3.5-turbo") {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
    }
    
    func generateResponse(to message: String) async throws -> String {
        guard !apiKey.isEmpty else {
            print("[OpenAIService] API ključ nije postavljen!")
            throw AIError.missingAPIKey
        }
        guard let url = URL(string: endpoint) else {
            print("[OpenAIService] Endpoint URL nije validan: \(endpoint)")
            throw AIError.invalidURL
        }

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": message]
            ]
        ]
        print("[OpenAIService] Request body: \(requestBody)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("[OpenAIService] HTTP status: \(httpResponse.statusCode)")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("[OpenAIService] Odgovor: \(responseString)")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorDict = json["error"] as? [String: Any],
               let errorMessage = errorDict["message"] as? String {
                print("[OpenAIService] API error: \(errorMessage)")
                throw AIError.serverError(errorMessage)
            }
            let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                print("[OpenAIService] Nema content u odgovoru!")
                throw AIError.invalidResponse
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("[OpenAIService] Greška: \(error)")
            throw AIError.networkError(error)
        }
        
        // MARK: - OpenAI Response Models

        struct OpenAIResponse: Decodable {
            let choices: [OpenAIChoice]
        }

        struct OpenAIChoice: Decodable {
            let message: OpenAIMessage
        }

        struct OpenAIMessage: Decodable {
            let role: String
            let content: String
        }
    }
} 
