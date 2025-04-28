import Foundation
import SwiftUI
import FirebaseStorage
import FirebaseFirestore
import UniformTypeIdentifiers

@MainActor
class PDFListViewModel: ObservableObject {
    @Published var documents: [PDFDocument] = []
    @Published var isLoading = false
    @Published var searchText = ""
    @Published var error: Error?
    @Published var showError = false
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
        Task {
            await loadDocuments()
        }
    }
    
    var filteredDocuments: [PDFDocument] {
        if searchText.isEmpty {
            return documents
        }
        return documents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    func loadDocuments() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let snapshot = try await db.collection("users").document(userId).collection("pdfs").getDocuments()
            documents = snapshot.documents.compactMap { doc -> PDFDocument? in
                guard var document = try? doc.data(as: PDFDocument.self) else { return nil }
                document.id = doc.documentID
                return document
            }
        } catch {
            self.error = error
            self.showError = true
        }
    }
    
    func addDocument(from url: URL) async {
        let fileName = url.lastPathComponent
        let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        
        let document = PDFDocument(
            name: fileName,
            localURL: url,
            size: Int64(fileSize),
            isUploaded: false
        )
        
        documents.append(document)
        
        do {
            let documentData = try await uploadDocument(document)
            if let index = documents.firstIndex(where: { $0.name == document.name }) {
                documents[index] = documentData
            }
        } catch {
            self.error = error
            self.showError = true
            if let index = documents.firstIndex(where: { $0.name == document.name }) {
                documents.remove(at: index)
            }
        }
    }
    
    private func uploadDocument(_ document: PDFDocument) async throws -> PDFDocument {
        guard let localURL = document.localURL else {
            throw NSError(domain: "PDFUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing local URL"])
        }
        
        let storageRef = storage.reference().child("users/\(userId)/pdfs/\(document.name)")
        
        let uploadedDocument = document
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"
        
        let task = storageRef.putFile(from: localURL, metadata: metadata)
        
        let _ = task.observe(.progress) { snapshot in
            if let progress = snapshot.progress {
                let percentComplete = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                Task { @MainActor in
                    if let index = self.documents.firstIndex(where: { $0.name == document.name }) {
                        self.documents[index].uploadProgress = percentComplete
                    }
                }
            }
        }
        
        return await withCheckedContinuation { continuation in
            task.observe(.success) { _ in
                Task {
                    do {
                        let downloadURL = try await storageRef.downloadURL()
                        
                        let updatedDocument = PDFDocument(
                            id: uploadedDocument.id,
                            name: uploadedDocument.name,
                            localURL: uploadedDocument.localURL,
                            remoteURL: downloadURL.absoluteString,
                            size: uploadedDocument.size,
                            date: uploadedDocument.date,
                            isUploaded: true
                        )
                        
                        let docRef = try await self.db.collection("users")
                            .document(self.userId)
                            .collection("pdfs")
                            .addDocument(data: updatedDocument.dictionary)
                        
                        let finalDocument = PDFDocument(
                            id: docRef.documentID,
                            name: updatedDocument.name,
                            localURL: updatedDocument.localURL,
                            remoteURL: updatedDocument.remoteURL,
                            size: updatedDocument.size,
                            date: updatedDocument.date,
                            isUploaded: true
                        )
                        
                        continuation.resume(returning: finalDocument)
                    } catch {
                        continuation.resume(throwing: error as! Never)
                    }
                }
            }
            
            task.observe(.failure) { snapshot in
                if let error = snapshot.error {
                    continuation.resume(throwing: error as! Never)
                }
            }
        }
    }
    
    func deleteDocument(_ document: PDFDocument) async {
        guard let documentId = document.id else { return }
        
        do {
            if document.isUploaded {
                if let remoteURL = document.remoteURL {
                    let storageRef = storage.reference(forURL: remoteURL)
                    try await storageRef.delete()
                }
                try await db.collection("users").document(userId).collection("pdfs").document(documentId).delete()
            }
            
            if let index = documents.firstIndex(where: { $0.id == documentId }) {
                documents.remove(at: index)
            }
        } catch {
            self.error = error
            self.showError = true
        }
    }
}

extension PDFDocument {
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "size": size,
            "date": date,
            "isUploaded": isUploaded
        ]
        
        if let localURL = localURL {
            dict["localURL"] = localURL.absoluteString
        }
        if let remoteURL = remoteURL {
            dict["remoteURL"] = remoteURL
        }
        if let uploadProgress = uploadProgress {
            dict["uploadProgress"] = uploadProgress
        }
        if let extractedText = extractedText {
            dict["extractedText"] = extractedText
        }
        if let embeddings = embeddings {
            dict["embeddings"] = embeddings
        }
        
        return dict
    }
} 
