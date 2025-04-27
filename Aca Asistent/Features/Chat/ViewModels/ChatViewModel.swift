import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentMessage: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    private let aiService: AIServiceProtocol
    
    init(aiService: AIServiceProtocol = AIService()) {
        self.aiService = aiService
        setupMessagesListener()
    }
    
    private func setupMessagesListener() {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "Korisnik nije autentifikovan"
            return
        }
        
        listener = db.collection("users")
            .document(userId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = "Greška pri učitavanju poruka: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self?.error = "Nema dostupnih poruka"
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
            error = "Korisnik nije autentifikovan"
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
        
        // Sačuvaj korisničku poruku
        db.collection("users")
            .document(userId)
            .collection("messages")
            .addDocument(data: messageData) { [weak self] error in
                if let error = error {
                    self?.error = "Greška pri slanju poruke: \(error.localizedDescription)"
                    return
                }
                self?.currentMessage = ""
                
                // Generiši AI odgovor
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
                error = "Korisnik nije autentifikovan"
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
            self.error = "Greška pri generisanju AI odgovora: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    deinit {
        listener?.remove()
        cancellables.removeAll()
    }
} 