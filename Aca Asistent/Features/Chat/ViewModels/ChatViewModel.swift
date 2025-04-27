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
    
    init() {
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
        
        db.collection("users")
            .document(userId)
            .collection("messages")
            .addDocument(data: messageData) { [weak self] error in
                if let error = error {
                    self?.error = "Greška pri slanju poruke: \(error.localizedDescription)"
                    return
                }
                self?.currentMessage = ""
                self?.simulateAIResponse()
            }
    }
    
    private func simulateAIResponse() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            
            guard let userId = Auth.auth().currentUser?.uid else {
                self.error = "Korisnik nije autentifikovan"
                self.isLoading = false
                return
            }
            
            let aiMessage = Message(
                content: "Ovo je simulirani odgovor AI asistenta. Ovo će biti zamenjeno sa pravim LLAMA modelom.",
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
            
            self.db.collection("users")
                .document(userId)
                .collection("messages")
                .addDocument(data: messageData) { [weak self] error in
                    if let error = error {
                        self?.error = "Greška pri slanju AI odgovora: \(error.localizedDescription)"
                    }
                    self?.isLoading = false
                }
        }
    }
    
    deinit {
        listener?.remove()
        cancellables.removeAll()
    }
} 