import Foundation
import Firebase
import FirebaseAuth
import Combine

class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var isAuthenticated = false
    @Published var error: String?
    @Published var isLoading = false
    @Published var isEmailVerificationSent = false
    @Published var isEmailVerified = false
    
    private var cancellables = Set<AnyCancellable>()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        // Check if user is already authenticated
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] (auth: Auth, user: User?) in
            self?.isAuthenticated = user != nil
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    func login() {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields"
            return
        }
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] (result: AuthDataResult?, error: Error?) in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                if let user = Auth.auth().currentUser {
                    user.reload { [weak self] error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self?.error = error.localizedDescription
                                return
                            }
                            self?.isEmailVerified = user.isEmailVerified
                            self?.isAuthenticated = user.isEmailVerified
                            self?.error = nil
                        }
                    }
                }
            }
        }
    }
    
    func register() {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields"
            return
        }
        
        guard password == confirmPassword else {
            error = "Passwords do not match"
            return
        }
        
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] (result: AuthDataResult?, error: Error?) in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                // Send verification email
                result?.user.sendEmailVerification(completion: { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self?.error = "Verification email error: \(error.localizedDescription)"
                        } else {
                            self?.isEmailVerificationSent = true
                        }
                    }
                })
                self?.isAuthenticated = false
                self?.isEmailVerified = false
                self?.error = nil
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func checkEmailVerification() {
        guard let user = Auth.auth().currentUser else { return }
        user.reload { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    return
                }
                self?.isEmailVerified = user.isEmailVerified
                if user.isEmailVerified {
                    self?.isAuthenticated = true
                }
            }
        }
    }
    
    func resendVerificationEmail() {
        guard let user = Auth.auth().currentUser else { return }
        user.sendEmailVerification { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = "Verification email error: \(error.localizedDescription)"
                } else {
                    self?.isEmailVerificationSent = true
                }
            }
        }
    }
} 