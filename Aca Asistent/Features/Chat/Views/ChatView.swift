import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.colorScheme) var colorScheme
    @State private var isDocumentPickerPresented = false
    @State private var selectedPDFName: String?
    @State private var selectedPDFUrl: URL?
    @State private var isPDFViewerPresented = false
    @State private var uploadStatus: UploadStatus? = nil
    @State private var showPDFList = false
    enum UploadStatus { case uploading, success, error(String) }
    
    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > 700
            ZStack {
                // Tamni gradijent
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 40/255, green: 30/255, blue: 60/255), Color(red: 20/255, green: 15/255, blue: 30/255)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("AI Assistant")
                            .font(isWide ? .largeTitle : .title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            // TODO: Implementirati podešavanja
                        } label: {
                            Image(systemName: "gear")
                                .font(isWide ? .title : .title3)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(isWide ? 32 : 16)
                    .background(Color.white.opacity(0.05).blur(radius: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: isWide ? 28 : 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: isWide ? 16 : 8, y: 4)
                    // Toolbar
                    HStack {
                        Spacer()
                        Button {
                            showPDFList = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                Text("PDF dokumenti")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                        .padding(.trailing)
                    }
                    .padding(.top)
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: isWide ? 24 : 12) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message, isWide: isWide)
                                        .id(message.id)
                                }
                            }
                            .padding(.vertical, isWide ? 24 : 12)
                            .padding(.horizontal, isWide ? 32 : 8)
                        }
                        .onChange(of: viewModel.messages.count) { oldCount, newCount in
                            if let lastMessage = viewModel.messages.last {
                                withAnimation {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    // Input Area
                    VStack(spacing: 0) {
                        Divider().background(Color.white.opacity(0.1))
                        HStack(spacing: isWide ? 24 : 12) {
                            // PDF upload button
                            Button {
                                isDocumentPickerPresented = true
                            } label: {
                                Image(systemName: "paperclip")
                                    .font(.system(size: isWide ? 32 : 24))
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.trailing, 4)
                            .fileImporter(
                                isPresented: $isDocumentPickerPresented,
                                allowedContentTypes: [UTType.pdf],
                                allowsMultipleSelection: false
                            ) { result in
                                switch result {
                                case .success(let urls):
                                    if let url = urls.first {
                                        selectedPDFName = url.lastPathComponent
                                        selectedPDFUrl = url
                                        // Prvo upload PDF na Firebase
                                        uploadStatus = .uploading
                                        viewModel.uploadPDF(url: url) { result in
                                            DispatchQueue.main.async {
                                                switch result {
                                                case .success:
                                                    uploadStatus = .success
                                                    // Otvori PDF viewer tek nakon uspešnog upload-a
                                                    isPDFViewerPresented = true
                                                case .failure(let error):
                                                    uploadStatus = .error(error.localizedDescription)
                                                    isPDFViewerPresented = false
                                                }
                                            }
                                        }
                                    }
                                case .failure(let error):
                                    print("Failed to pick PDF: \(error.localizedDescription)")
                                }
                            }
                            // Prikaz imena izabranog PDF-a
                            if let pdfName = selectedPDFName {
                                Text(pdfName)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            // TextField za poruku
                            TextField("Enter your message...", text: $viewModel.currentMessage)
                                .padding(isWide ? 20 : 14)
                                .background(.ultraThinMaterial)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: isWide ? 24 : 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: isWide ? 24 : 16)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: isWide ? 8 : 4, y: 2)
                                .disabled(viewModel.isLoading)
                            Button {
                                viewModel.sendMessage()
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: isWide ? 44 : 32))
                                    .foregroundColor(viewModel.currentMessage.isEmpty ? .gray : .accentColor)
                                    .shadow(color: Color.accentColor.opacity(0.25), radius: isWide ? 10 : 6, y: 2)
                            }
                            .disabled(viewModel.currentMessage.isEmpty || viewModel.isLoading)
                        }
                        .padding(.horizontal, isWide ? 24 : 12)
                        .padding(.vertical, isWide ? 18 : 10)
                    }
                    .background(Color.white.opacity(0.05).blur(radius: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: isWide ? 28 : 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.12), radius: isWide ? 16 : 8, y: 4)
                }
                .padding(.vertical, isWide ? 16 : 8)
                .padding(.horizontal, 0)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
                if let status = uploadStatus {
                    switch status {
                    case .uploading:
                        ZStack {
                            Color.black.opacity(0.3).ignoresSafeArea()
                            ProgressView("Uploading PDF...")
                                .padding()
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(12)
                        }
                    case .success:
                        ZStack {
                            Color.black.opacity(0.3).ignoresSafeArea()
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.largeTitle)
                                Text("PDF uploaded successfully!").foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                        }
                        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { uploadStatus = nil } }
                    case .error(let msg):
                        ZStack {
                            Color.black.opacity(0.3).ignoresSafeArea()
                            VStack(spacing: 12) {
                                Image(systemName: "xmark.octagon.fill").foregroundColor(.red).font(.largeTitle)
                                Text("Upload failed: \(msg)").foregroundColor(.red)
                            }
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(12)
                        }
                        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { uploadStatus = nil } }
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "")
            }
            .sheet(isPresented: $isPDFViewerPresented) {
                if let url = selectedPDFUrl {
                    PDFViewer(url: url)
                }
            }
            .sheet(isPresented: $showPDFList) {
                PDFListView()
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    var isWide: Bool = false
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, isWide ? 28 : 16)
                    .padding(.vertical, isWide ? 18 : 10)
                    .background {
                        if message.isUser {
                            LinearGradient(gradient: Gradient(colors: [Color.accentColor, Color(red: 140/255, green: 110/255, blue: 200/255)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                        } else {
                            Color.white.opacity(0.08)
                        }
                    }
                    .foregroundColor(message.isUser ? .white : .white.opacity(0.95))
                    .cornerRadius(isWide ? 28 : 20)
                    .shadow(color: message.isUser ? Color.accentColor.opacity(0.18) : Color.black.opacity(0.08), radius: isWide ? 10 : 6, y: 2)
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal, isWide ? 12 : 4)
    }
}

#Preview {
    ChatView()
} 