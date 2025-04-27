import Foundation

enum AIError: Error {
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case missingAPIKey
}

protocol AIServiceProtocol {
    func generateResponse(to message: String) async throws -> String
}

class AIService: AIServiceProtocol {
    private let session: URLSession
    private let configuration: AIConfiguration
    
    init(session: URLSession = .shared, configuration: AIConfiguration = .shared) {
        self.session = session
        self.configuration = configuration
    }
    
    func generateResponse(to message: String) async throws -> String {
        guard let url = URL(string: "\(configuration.baseURL)/generate") else {
            throw AIError.serverError("Invalid URL")
        }
        
        guard configuration.apiKey != nil else {
            throw AIError.missingAPIKey
        }
        
        let requestBody: [String: Any] = [
            "prompt": message,
            "temperature": configuration.temperature,
            "max_tokens": configuration.maxTokens,
            "top_p": configuration.topP
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = configuration.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw AIError.invalidResponse
            }
            
            let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let generatedText = responseDict?["response"] as? String else {
                throw AIError.decodingError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
            }
            
            return generatedText
        } catch {
            throw AIError.networkError(error)
        }
    }
} 