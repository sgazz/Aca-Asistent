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
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] (result: AuthDataResult?, error: Error?) in
            if let error = error {
                self?.error = error.localizedDescription
                return
            }
            self?.isAuthenticated = true
            self?.error = nil
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
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] (result: AuthDataResult?, error: Error?) in
            if let error = error {
                self?.error = error.localizedDescription
                return
            }
            self?.isAuthenticated = true
            self?.error = nil
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
} 