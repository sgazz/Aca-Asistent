import SwiftUI
import Firebase

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isLogin = true
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, confirm
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Tamni gradijent
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 40/255, green: 30/255, blue: 60/255), Color(red: 20/255, green: 15/255, blue: 30/255)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                let tabs = [("Login", true), ("Register", false)]
                VStack(spacing: 32) {
                    Spacer()
                    // Logo i naslov
                    Image("aca_asistent")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.3), radius: 12, y: 6)
                    Text("Aca Assistant")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("AI assistant for the new age of learning")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    // Tab bar za Login/Register
                    HStack(spacing: 0) {
                        ForEach(tabs, id: \.0) { tab in
                            Button(action: { withAnimation { isLogin = tab.1 } }) {
                                VStack(spacing: 2) {
                                    Text(tab.0)
                                        .font(.headline)
                                        .foregroundColor(isLogin == tab.1 ? Color.accentColor : Color.white.opacity(0.7))
                                    Rectangle()
                                        .frame(height: 3)
                                        .foregroundColor(isLogin == tab.1 ? Color.accentColor : .clear)
                                        .cornerRadius(2)
                                        .animation(.easeInOut, value: isLogin)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(height: 36)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Capsule())
                    .padding(.horizontal, 32)
                    .frame(maxWidth: 400)
                    // Glassmorphism forma
                    VStack(spacing: 16) {
                        CustomTextField(text: $viewModel.email,
                                       placeholder: "Email",
                                       systemImage: "envelope",
                                       focused: $focusedField,
                                       field: .email)
                            .focused($focusedField, equals: .email)
                        CustomSecureField(text: $viewModel.password,
                                         placeholder: "Password",
                                         systemImage: "lock",
                                         focused: $focusedField,
                                         field: .password)
                            .focused($focusedField, equals: .password)
                        if !isLogin {
                            CustomSecureField(text: $viewModel.confirmPassword,
                                             placeholder: "Confirm Password",
                                             systemImage: "lock.shield",
                                             focused: $focusedField,
                                             field: .confirm)
                                .focused($focusedField, equals: .confirm)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Color.black.opacity(0.25), radius: 16, y: 8)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 400)
                    // Error message
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 4)
                            .frame(maxWidth: 400)
                    }
                    // Dugme
                    Button(action: {
                        if isLogin {
                            viewModel.login()
                        } else {
                            viewModel.register()
                        }
                    }) {
                        Text(isLogin ? "Login" : "Create Account")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.accentColor, Color(red: 140/255, green: 110/255, blue: 200/255)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                            .scaleEffect(viewModel.isAuthenticated ? 1.05 : 1.0)
                            .animation(.spring(), value: viewModel.isAuthenticated)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 400)
                    // Premium kartica
                    if !isLogin {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Premium Access")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("$10/month")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.subheadline)
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                        .padding(.top, 8)
                        .frame(maxWidth: 400)
                    }
                    Spacer()
                }
                .padding(.vertical, 24)
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let systemImage: String
    @FocusState.Binding var focused: AuthView.Field?
    let field: AuthView.Field
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(Color.white.opacity(0.85))
                .frame(width: 20)
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.7)))
                .autocapitalization(.none)
                .foregroundColor(.white)
                .keyboardType(.emailAddress)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focused == field ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .cornerRadius(12)
    }
}

struct CustomSecureField: View {
    @Binding var text: String
    let placeholder: String
    let systemImage: String
    @FocusState.Binding var focused: AuthView.Field?
    let field: AuthView.Field
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(Color.white.opacity(0.85))
                .frame(width: 20)
            SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.7)))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focused == field ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .cornerRadius(12)
    }
}

#Preview {
    AuthView()
} 
