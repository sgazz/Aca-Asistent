import SwiftUI

struct PDFListView: View {
    @StateObject var viewModel = PDFViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedDocument: PDFDocument?
    @State private var showingFilePicker = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Učitavanje...")
                } else if viewModel.documents.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("Nema PDF dokumenata")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Button("Dodaj PDF") {
                            showingFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.documents) { document in
                                PDFCardView(document: document)
                                    .onTapGesture {
                                        selectedDocument = document
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            viewModel.deletePDF(document)
                                        } label: {
                                            Label("Obriši", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                    .searchable(text: $viewModel.searchText, prompt: "Pretraži PDF-ove")
                }
            }
            .navigationTitle("PDF Dokumenti")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Zatvori") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(item: $selectedDocument) { document in
            if let url = document.localURL {
                PDFViewer(url: url)
            } else {
                Text("Ne mogu da otvorim PDF")
                    .foregroundColor(.red)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                
                // Počni sa učitavanjem dokumenta
                viewModel.addDocument(from: url)
                
            case .failure(let error):
                viewModel.error = "Greška pri izboru fajla: \(error.localizedDescription)"
            }
        }
        .alert("Greška", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
}

struct PDFCardView: View {
    let document: PDFDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                Spacer()
                Circle()
                    .fill(document.isUploaded ? Color.green : Color.orange)
                    .frame(width: 12, height: 12)
            }
            
            Text(document.name)
                .font(.headline)
                .lineLimit(2)
            
            Text(document.formattedSize)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(document.formattedDate)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(document.statusText)
                .font(.caption)
                .foregroundColor(document.statusColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

#Preview {
    PDFListView()
} 