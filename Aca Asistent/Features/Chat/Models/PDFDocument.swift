import Foundation
import FirebaseFirestore
import SwiftUI

struct PDFDocument: Identifiable, Codable {
    var id: String?
    let name: String
    let localURL: URL?
    let remoteURL: String?
    let size: Int64
    let date: Date
    var isUploaded: Bool
    var uploadProgress: Double?
    
    // Dodatna polja koja će nam trebati kasnije za RAG
    var extractedText: String?
    var embeddings: [Double]?
    var summary: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case localURL
        case remoteURL
        case size
        case date
        case isUploaded
        case uploadProgress
        case extractedText
        case embeddings
        case summary
    }
    
    init(id: String? = nil,
         name: String,
         localURL: URL? = nil,
         remoteURL: String? = nil,
         size: Int64,
         date: Date = Date(),
         isUploaded: Bool = false,
         uploadProgress: Double? = nil,
         extractedText: String? = nil,
         embeddings: [Double]? = nil,
         summary: String? = nil) {
        self.id = id
        self.name = name
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.size = size
        self.date = date
        self.isUploaded = isUploaded
        self.uploadProgress = uploadProgress
        self.extractedText = extractedText
        self.embeddings = embeddings
        self.summary = summary
    }
    
    // Helper za formatiranje veličine fajla
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // Helper za formatiranje datuma
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Status badge text
    var statusText: String {
        if isUploaded {
            return "Sinhronizovano"
        } else if let progress = uploadProgress {
            return "Upload: \(Int(progress * 100))%"
        } else {
            return "Lokalno"
        }
    }
    
    // Status badge color
    var statusColor: Color {
        if isUploaded {
            return .green
        } else if uploadProgress != nil {
            return .blue
        } else {
            return .orange
        }
    }
} 