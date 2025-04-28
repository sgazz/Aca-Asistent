import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine
import FirebaseStorage

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    private let aiService: AIServiceProtocol
    
    init() {
        // Učitaj OpenAI API ključ iz Info.plist
        let openAIKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String ?? ""
        print("OPENAI_API_KEY iz konfiguracije: \(openAIKey)")
        self.aiService = OpenAIService(apiKey: openAIKey)
        setupMessagesListener()
    }
    
    private func setupMessagesListener() {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "User is not authenticated"
            return
        }
        
        listener = db.collection("users")
            .document(userId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = "Error loading messages: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.error = "No messages available"
                    return
                }
                
                self?.messages = documents.compactMap { document in
                    let data = document.data()
                    return Message(
                        id: document.documentID,
                        content: data["content"] as? String ?? "",
                        isUser: data["isUser"] as? Bool ?? false,
                        timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date(),
                        subject: data["subject"] as? String,
                        attachments: data["attachments"] as? [String]
                    )
                }
            }
    }
    
    func sendMessage() {
        guard !currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "User is not authenticated"
            return
        }
        
        let message = Message(
            content: currentMessage,
            isUser: true,
            timestamp: Date()
        )
        
        let messageData: [String: Any] = [
            "content": message.content,
            "isUser": message.isUser,
            "timestamp": Timestamp(date: message.timestamp),
            "subject": message.subject as Any,
            "attachments": message.attachments as Any
        ]
        
        // Save user message
        db.collection("users")
            .document(userId)
            .collection("messages")
            .addDocument(data: messageData) { [weak self] error in
                if let error = error {
                    self?.error = "Error sending message: \(error.localizedDescription)"
                    return
                }
                self?.currentMessage = ""
                
                // Generate AI response
                Task { [weak self] in
                    await self?.generateAIResponse(to: message.content)
                }
            }
    }
    
    @MainActor
    private func generateAIResponse(to message: String) async {
        isLoading = true
        
        do {
            let response = try await aiService.generateResponse(to: message)
            
            guard let userId = Auth.auth().currentUser?.uid else {
                error = "User is not authenticated"
                isLoading = false
                return
            }
            
            let aiMessage = Message(
                content: response,
                isUser: false,
                timestamp: Date()
            )
            
            let messageData: [String: Any] = [
                "content": aiMessage.content,
                "isUser": aiMessage.isUser,
                "timestamp": Timestamp(date: aiMessage.timestamp),
                "subject": aiMessage.subject as Any,
                "attachments": aiMessage.attachments as Any
            ]
            
            try await db.collection("users")
                .document(userId)
                .collection("messages")
                .addDocument(data: messageData)
            
        } catch {
            if let aiError = error as? AIError, case let .serverError(message) = aiError {
                self.error = "AI error: \(message)"
            } else {
                self.error = "Error generating AI response: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    func uploadPDF(url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "No user", code: 0)))
            return
        }
        
        let fileName = url.lastPathComponent
        
        // Dobavljanje Storage instance sa ispravnim bucket-om
        let storage = Storage.storage()
        let bucket = storage.reference().bucket
        print("Using bucket: \(bucket)")
        
        // Kreiranje reference
        let storageRef = storage.reference(forURL: "gs://\(bucket)")
        
        print("Storage reference created")
        
        // Kreiranje putanje za PDF
        let pdfPath = "users/\(userId)/pdfs/\(fileName)"
        let pdfRef = storageRef.child(pdfPath)
            
        print("Attempting to upload PDF...")
        print("Full path: \(pdfRef.fullPath)")
        print("Bucket: \(bucket)")
        
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        
        do {
            let data = try Data(contentsOf: url)
            print("Data size: \(data.count) bytes")
            
            // Postavljanje metadata sa dodatnim informacijama
            let metadata = StorageMetadata()
            metadata.contentType = "application/pdf"
            metadata.customMetadata = [
                "uploadedBy": userId,
                "originalName": fileName
            ]
            
            let uploadTask = pdfRef.putData(data, metadata: metadata) { [weak self] metadata, error in
                if let error = error {
                    print("Upload error details: \(error)")
                    let nsError = error as NSError
                    print("Error code: \(nsError.code), domain: \(nsError.domain)")
                    if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                        print("Underlying error: \(underlyingError)")
                    }
                    completion(.failure(error))
                    return
                }
                
                print("Upload completed, metadata: \(String(describing: metadata))")
                
                pdfRef.downloadURL { url, error in
                    if let error = error {
                        print("Download URL error: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    guard let downloadURL = url else {
                        completion(.failure(NSError(domain: "No download URL", code: 0)))
                        return
                    }
                    
                    print("Download URL obtained: \(downloadURL.absoluteString)")
                    
                    // Sačuvaj meta podatke u Firestore
                    let docData: [String: Any] = [
                        "name": fileName,
                        "url": downloadURL.absoluteString,
                        "uploadedAt": Timestamp(date: Date()),
                        "userId": userId,
                        "size": data.count,
                        "path": pdfPath
                    ]
                    
                    self?.db.collection("users")
                        .document(userId)
                        .collection("pdfs")
                        .addDocument(data: docData) { error in
                            if let error = error {
                                print("Firestore error: \(error.localizedDescription)")
                                completion(.failure(error))
                            } else {
                                print("PDF successfully uploaded and metadata saved")
                                completion(.success(()))
                            }
                        }
                }
            }
            
            // Dodajemo progress observer
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let percentComplete = 100.0 * Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    print("Upload progress: \(percentComplete)%")
                }
            }
            
        } catch {
            print("Local file error: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    deinit {
        listener?.remove()
        cancellables.removeAll()
    }
} 
