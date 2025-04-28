import SwiftUI
import PDFKit

struct PDFViewer: View {
    let url: URL
    @State private var document: PDFKit.PDFDocument?
    @State private var error: String?
    
    var body: some View {
        Group {
            if let document = document {
                PDFKitView(document: document)
                    .edgesIgnoringSafeArea(.all)
            } else if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
                ProgressView("Učitavanje PDF-a...")
            }
        }
        .onAppear {
            loadDocument()
        }
    }
    
    private func loadDocument() {
        // Prvo pokušaj da učitaš iz keša ako postoji
        if let cachedDocument = PDFDocumentCache.shared.getDocument(for: url) {
            self.document = cachedDocument
            return
        }
        
        // Ako nije u kešu, učitaj i sačuvaj
        Task {
            do {
                let data = try await loadPDFData(from: url)
                if let doc = PDFKit.PDFDocument(data: data) {
                    await MainActor.run {
                        self.document = doc
                        // Sačuvaj u keš
                        PDFDocumentCache.shared.cacheDocument(doc, for: url)
                    }
                } else {
                    await MainActor.run {
                        self.error = "Nije moguće otvoriti PDF"
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Greška pri učitavanju: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func loadPDFData(from url: URL) async throws -> Data {
        if url.isFileURL {
            // Lokalni fajl
            return try Data(contentsOf: url)
        } else {
            // Remote URL
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFKit.PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        pdfView.document = document
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // No update needed
    }
}

// Singleton za keširanje PDF dokumenata
class PDFDocumentCache {
    static let shared = PDFDocumentCache()
    private var cache = NSCache<NSURL, PDFKit.PDFDocument>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Kreiraj direktorijum za keš ako ne postoji
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("PDFCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Podesi limite za keš
        cache.countLimit = 50 // Maksimalan broj dokumenata u memoriji
    }
    
    func cacheDocument(_ document: PDFKit.PDFDocument, for url: URL) {
        // Keširaj u memoriji
        cache.setObject(document, forKey: url as NSURL)
        
        // Keširaj na disku
        let fileName = url.lastPathComponent
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        if let data = document.dataRepresentation() {
            try? data.write(to: fileURL)
        }
    }
    
    func getDocument(for url: URL) -> PDFKit.PDFDocument? {
        // Prvo proveri memorijski keš
        if let cachedDoc = cache.object(forKey: url as NSURL) {
            return cachedDoc
        }
        
        // Ako nije u memoriji, proveri disk keš
        let fileName = url.lastPathComponent
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let document = PDFKit.PDFDocument(data: data) {
            // Vrati u memorijski keš
            cache.setObject(document, forKey: url as NSURL)
            return document
        }
        
        return nil
    }
    
    func clearCache() {
        // Očisti memorijski keš
        cache.removeAllObjects()
        
        // Očisti keš na disku
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

#Preview {
    PDFViewer(url: Bundle.main.url(forResource: "sample", withExtension: "pdf") ?? URL(string: "about:blank")!)
} 
