import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable {
    var id: String?
    let content: String
    let isUser: Bool
    let timestamp: Date
    var subject: String?
    var attachments: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case content
        case isUser
        case timestamp
        case subject
        case attachments
    }
    
    init(id: String? = nil, content: String, isUser: Bool, timestamp: Date, subject: String? = nil, attachments: [String]? = nil) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.subject = subject
        self.attachments = attachments
    }
} 