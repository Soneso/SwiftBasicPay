//
//  AuthView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import SwiftUI
import stellar_wallet_sdk
import AlertToast
import Observation

// MARK: - View Model

@Observable
final class AuthViewModel {
    
    private let authService = AuthService()
    
    var hasUser: Bool = false
    var checkUserError: String?
    var isLoading: Bool = false
    
    var pin: String = ""
    var pinConfirmation: String = ""
    
    var newUserKeypair = SigningKeyPair.random
    var showSeed = false
    
    var signupError: String?
    var loginError: String?
    
    var showToast = false
    var toastMessage: String = ""
    
    init() {
        checkUserStatus()
    }
    
    private func checkUserStatus() {
        do {
            hasUser = try authService.userIsSignedUp
        } catch {
            checkUserError = error.localizedDescription
            hasUser = false
        }
    }
    
    func generateNewAddress() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            newUserKeypair = SigningKeyPair.random
        }
    }
    
    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        toastMessage = "Copied to clipboard"
        showToast = true
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func validatePin() -> Bool {
        guard pin.count == 6 else {
            return false
        }
        return pin.allSatisfy { $0.isNumber }
    }
    
    func validatePinConfirmation() -> Bool {
        return pin == pinConfirmation && validatePin()
    }
    
    @MainActor
    func signup() async -> String? {
        guard validatePin() else {
            signupError = "PIN must be exactly 6 digits"
            return nil
        }
        
        guard validatePinConfirmation() else {
            signupError = "PIN and confirmation do not match"
            return nil
        }
        
        isLoading = true
        signupError = nil
        
        do {
            let address = try authService.signUp(userKeyPair: newUserKeypair, pin: pin)
            isLoading = false
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            return address
        } catch {
            isLoading = false
            signupError = error.localizedDescription
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
            
            return nil
        }
    }
    
    @MainActor
    func login() async -> String? {
        guard validatePin() else {
            loginError = "PIN must be exactly 6 digits"
            return nil
        }
        
        isLoading = true
        loginError = nil
        
        do {
            let address = try authService.signIn(pin: pin)
            isLoading = false
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            return address
        } catch {
            isLoading = false
            loginError = error.localizedDescription
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
            
            return nil
        }
    }
    
    func clearErrors() {
        signupError = nil
        loginError = nil
    }
    
    func reset() {
        pin = ""
        pinConfirmation = ""
        clearErrors()
    }
}

// MARK: - Reusable Components

struct PINInputField: View {
    let title: String
    @Binding var text: String
    var isFocused: Bool
    var showError: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField(title, text: $text)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    showError ? Color.red : (isFocused ? Color.blue : Color.clear),
                                    lineWidth: 2
                                )
                        )
                )
                .onChange(of: text) { oldValue, newValue in
                    if newValue.count > 6 {
                        text = String(newValue.prefix(6))
                    }
                    text = text.filter { $0.isNumber }
                }
                .accessibilityLabel(title)
                .accessibilityHint("Enter a 6-digit PIN code")
        }
    }
}

struct KeyDisplayCard: View {
    let title: String
    let value: String
    let isSecret: Bool
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            HStack {
                Text(value)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(isSecret ? .red : .primary)
                    .lineLimit(isSecret ? 2 : 1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy \(title)")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct AuthButton: View {
    let title: String
    let action: () -> Void
    let style: AuthButtonStyle
    let isLoading: Bool
    
    enum AuthButtonStyle {
        case primary
        case secondary
        case destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return Color(.systemGray5)
            case .destructive: return .red
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .primary
            case .destructive: return .white
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(style.foregroundColor)
            .background(style.backgroundColor)
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .accessibilityLabel(title)
    }
}

struct AuthHeaderView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16))
            
            Text(message)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundColor(.red)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Main Auth View

struct AuthView: View {
    
    private let userLoggedIn: (String) -> Void
    @State private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable {
        case pin
        case pinConfirmation
    }
    
    init(userLoggedIn: @escaping (String) -> Void) {
        self.userLoggedIn = userLoggedIn
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if let error = viewModel.checkUserError {
                        ErrorMessageView(message: error)
                            .padding(.bottom, 24)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    
                    if viewModel.hasUser {
                        loginView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else {
                        signupView
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(.systemBackground))
        .toast(isPresenting: $viewModel.showToast) {
            AlertToast(type: .regular, title: viewModel.toastMessage)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.hasUser)
        .animation(.easeInOut(duration: 0.3), value: viewModel.checkUserError)
        .onTapGesture {
            focusedField = nil
        }
    }
    
    var signupView: some View {
        VStack(spacing: 32) {
            AuthHeaderView(
                title: "Create Account",
                subtitle: "Set up your secure Stellar wallet with a 6-digit PIN. Your secret key will be encrypted and stored locally on your device."
            )
            
            VStack(spacing: 24) {
                keypairSection
                pinInputSection
                signupButton
            }
            
            if let error = viewModel.signupError {
                ErrorMessageView(message: error)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
    
    var loginView: some View {
        VStack(spacing: 32) {
            AuthHeaderView(
                title: "Welcome Back",
                subtitle: "Enter your 6-digit PIN to access your wallet. Your PIN and secret key never leave your device."
            )
            
            VStack(spacing: 24) {
                PINInputField(
                    title: "Enter your PIN",
                    text: $viewModel.pin,
                    isFocused: focusedField == .pin,
                    showError: viewModel.loginError != nil
                )
                .focused($focusedField, equals: .pin)
                .onSubmit {
                    Task {
                        await performLogin()
                    }
                }
                
                loginButton
            }
            
            if let error = viewModel.loginError {
                ErrorMessageView(message: error)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
    }
    
    @ViewBuilder
    private var keypairSection: some View {
        VStack(spacing: 16) {
            KeyDisplayCard(
                title: "Public Key",
                value: viewModel.newUserKeypair.address,
                isSecret: false,
                onCopy: {
                    viewModel.copyToClipboard(viewModel.newUserKeypair.address)
                }
            )
            
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.generateNewAddress()
                    }
                }) {
                    Label("Generate New", systemImage: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Toggle(isOn: $viewModel.showSeed.animation(.easeInOut)) {
                    Label("Show Secret", systemImage: viewModel.showSeed ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .medium))
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if viewModel.showSeed {
                KeyDisplayCard(
                    title: "Secret Key - Keep this safe!",
                    value: viewModel.newUserKeypair.secretKey,
                    isSecret: true,
                    onCopy: {
                        viewModel.copyToClipboard(viewModel.newUserKeypair.secretKey)
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
    
    @ViewBuilder
    private var pinInputSection: some View {
        VStack(spacing: 16) {
            PINInputField(
                title: "Create 6-digit PIN",
                text: $viewModel.pin,
                isFocused: focusedField == .pin,
                showError: viewModel.signupError != nil && !viewModel.pin.isEmpty
            )
            .focused($focusedField, equals: .pin)
            .onSubmit {
                focusedField = .pinConfirmation
            }
            
            PINInputField(
                title: "Confirm PIN",
                text: $viewModel.pinConfirmation,
                isFocused: focusedField == .pinConfirmation,
                showError: viewModel.signupError != nil && !viewModel.pinConfirmation.isEmpty
            )
            .focused($focusedField, equals: .pinConfirmation)
            .onSubmit {
                Task {
                    await performSignup()
                }
            }
            
            if !viewModel.pin.isEmpty || !viewModel.pinConfirmation.isEmpty {
                pinValidationStatus
            }
        }
    }
    
    @ViewBuilder
    private var pinValidationStatus: some View {
        HStack(spacing: 16) {
            validationIndicator(
                isValid: viewModel.pin.count == 6,
                text: "6 digits"
            )
            
            if !viewModel.pinConfirmation.isEmpty {
                validationIndicator(
                    isValid: viewModel.pin == viewModel.pinConfirmation,
                    text: "PINs match"
                )
            }
        }
        .font(.system(size: 13))
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }
    
    private func validationIndicator(isValid: Bool, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? .green : .orange)
            Text(text)
                .foregroundColor(isValid ? .green : .orange)
        }
    }
    
    private var signupButton: some View {
        AuthButton(
            title: "Create Account",
            action: {
                Task {
                    await performSignup()
                }
            },
            style: .primary,
            isLoading: viewModel.isLoading
        )
        .disabled(!viewModel.validatePinConfirmation())
    }
    
    private var loginButton: some View {
        AuthButton(
            title: "Sign In",
            action: {
                Task {
                    await performLogin()
                }
            },
            style: .primary,
            isLoading: viewModel.isLoading
        )
        .disabled(!viewModel.validatePin())
    }
    
    private func performSignup() async {
        focusedField = nil
        if let address = await viewModel.signup() {
            withAnimation(.easeInOut) {
                userLoggedIn(address)
            }
        }
    }
    
    private func performLogin() async {
        focusedField = nil
        if let address = await viewModel.login() {
            withAnimation(.easeInOut) {
                userLoggedIn(address)
            }
        }
    }
}

// MARK: - Preview

public func userLoggedInPreview(_ userAddress:String) -> Void {}

#Preview {
    AuthView(userLoggedIn: userLoggedInPreview)
}