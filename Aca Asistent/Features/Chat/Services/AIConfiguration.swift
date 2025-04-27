import Foundation

struct AIConfiguration {
    static var shared = AIConfiguration()
    
    // Osnovne postavke
    var baseURL: String = "http://localhost:8000"
    var apiKey: String?
    
    // Parametri za generisanje
    var temperature: Float = 0.7
    var maxTokens: Int = 1000
    var topP: Float = 0.9
    
    private init() {}
    
    mutating func configure(baseURL: String? = nil, apiKey: String? = nil) {
        if let baseURL = baseURL {
            self.baseURL = baseURL
        }
        if let apiKey = apiKey {
            self.apiKey = apiKey
        }
    }
} 