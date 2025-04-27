import SwiftUI
import Firebase

struct AuthView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var isLogin = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                ChatView()
            } else {
                NavigationView {
                    VStack(spacing: 24) {
                        // Logo i naslov
                        VStack(spacing: 16) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.accentColor)
                            
                            Text("Aca Asistent")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                        }
                        .padding(.top, 60)
                        
                        // Login/Register toggle
                        Picker("Mode", selection: $isLogin) {
                            Text("Login").tag(true)
                            Text("Register").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 40)
                        
                        // Form
                        VStack(spacing: 16) {
                            CustomTextField(text: $viewModel.email,
                                          placeholder: "Email",
                                          systemImage: "envelope")
                            
                            CustomSecureField(text: $viewModel.password,
                                            placeholder: "Password",
                                            systemImage: "lock")
                            
                            if !isLogin {
                                CustomSecureField(text: $viewModel.confirmPassword,
                                                placeholder: "Confirm Password",
                                                systemImage: "lock.shield")
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Error message
                        if let error = viewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.top, 8)
                        }
                        
                        // Action Button
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
                                .background(Color.accentColor)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        
                        if !isLogin {
                            VStack(spacing: 8) {
                                Text("Premium Access")
                                    .font(.headline)
                                Text("$10/month")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 32)
                        }
                        
                        Spacer()
                    }
                    .navigationBarHidden(true)
                }
            }
        }
    }
}

struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.gray)
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .autocapitalization(.none)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CustomSecureField: View {
    @Binding var text: String
    let placeholder: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.gray)
                .frame(width: 20)
            SecureField(placeholder, text: $text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    AuthView()
} 