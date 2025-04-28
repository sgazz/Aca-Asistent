import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class PDFViewModel: ObservableObject {
    @Published var documents: [PDFDocument] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    
    init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("PDFs")
        try? fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        
        setupSearchSubscription()
        loadLocalDocuments()
    }
    
    private func setupSearchSubscription() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] searchText in
                self?.filterDocuments(searchText)
            }
            .store(in: &cancellables)
    }
    
    private func loadLocalDocuments() {
        guard Auth.auth().currentUser != nil else {
            error = "Korisnik nije prijavljen"
            return
        }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, 
                                                             includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            documents = fileURLs.compactMap { url -> PDFDocument? in
                guard url.pathExtension.lowercased() == "pdf" else { return nil }
                
                let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                let fileSize = attributes?[.size] as? Int64 ?? 0
                
                return PDFDocument(
                    name: url.lastPathComponent,
                    localURL: url,
                    size: fileSize
                )
            }
        } catch {
            self.error = "Greška pri učitavanju dokumenata: \(error.localizedDescription)"
        }
    }
    
    private func filterDocuments(_ searchText: String) {
        if searchText.isEmpty {
            loadLocalDocuments()
        } else {
            documents = documents.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    func addDocument(from sourceURL: URL) {
        guard Auth.auth().currentUser != nil else {
            error = "Korisnik nije prijavljen"
            return
        }
        
        do {
            let fileName = sourceURL.lastPathComponent
            let destinationURL = documentsDirectory.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(atPath: destinationURL.path)
            }
            
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            let newDocument = PDFDocument(
                name: fileName,
                localURL: destinationURL,
                size: fileSize
            )
            
            documents.append(newDocument)
            documents.sort { doc1, doc2 in
                doc1.date > doc2.date
            }
            
        } catch {
            self.error = "Greška pri dodavanju dokumenta: \(error.localizedDescription)"
        }
    }
    
    func deletePDF(_ document: PDFDocument) {
        do {
            if let localURL = document.localURL {
                try fileManager.removeItem(atPath: localURL.path)
            }
            
            documents.removeAll { $0.localURL == document.localURL }
            
            if let documentId = document.id {
                guard let userId = Auth.auth().currentUser?.uid else { return }
                
                db.collection("users")
                    .document(userId)
                    .collection("pdfs")
                    .document(documentId)
                    .delete { [weak self] error in
                        if let error = error {
                            self?.error = "Greška pri brisanju dokumenta iz cloud-a: \(error.localizedDescription)"
                        }
                    }
            }
        } catch {
            self.error = "Greška pri brisanju dokumenta: \(error.localizedDescription)"
        }
    }
    
    deinit {
        listener?.remove()
        cancellables.removeAll()
    }
}