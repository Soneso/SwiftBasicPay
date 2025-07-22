//
//  AuthView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import SwiftUI
import stellar_wallet_sdk
import AlertToast

struct AuthView: View {
    
    private let userLoggedIn:((_ userAddress:String) -> Void)
    
    private let authService = AuthService()
    
    @State private var checkUserError:String?
    @State private var hasUser:Bool
    @State private var newUserKeypair:SigningKeyPair = SigningKeyPair.random
    @State private var showSeed = false
    @State private var showToast = false
    @State private var toastMessage:String = ""
    @State private var pin:String = ""
    @State private var pinConfirmation:String = ""
    @State private var isSigningUp:Bool = false
    @State private var signupError:String?
    @State private var isLoggingIn:Bool = false
    @State private var loginError:String?
    
    internal init(userLoggedIn: @escaping ((String) -> Void)) {
        self.userLoggedIn = userLoggedIn
        do {
            hasUser = try authService.userIsSignedUp
        } catch {
            checkUserError = error.localizedDescription
            hasUser = false
        }
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                if let error = checkUserError {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                } else if hasUser {
                    loginView
                } else {
                    signupView
                }
            }.padding().toast(isPresenting: $showToast){
                AlertToast(type: .regular, title: "\(toastMessage)")
            }
        }
    }
    
    var signupView: some View {
        VStack {
            Text("Sign up now!").bold().font(.title2)
            Utils.divider
            Text("Please provide a 6-digit pincode to sign up. This pincode will be used to encrypt the secret key for your Stellar address, before it is stored in your keychain. Your secret key to this address will be stored on your device. You will be the only one to ever have custody over this key.").font(.subheadline).multilineTextAlignment(.leading).italic().foregroundColor(.black)
            Utils.divider
            Text("Public key:").bold().font(.body).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10.0)
            HStack {
                Text(newUserKeypair.address).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                Button("", systemImage: "doc.on.doc") {
                    copyToClipboard(text: newUserKeypair.address)
                }
            }.padding(EdgeInsets(top: 5, leading: 0, bottom: 10, trailing: 0))
            Button("Generate new address?") {
                newUserKeypair = SigningKeyPair.random
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10.0)
            Toggle("Show secret key", isOn: $showSeed).padding(.vertical, 10.0)
            if showSeed {
                Text("Secret key:").bold().font(.body).frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(newUserKeypair.secretKey).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.red)
                    Button("", systemImage: "doc.on.doc") {
                        copyToClipboard(text: newUserKeypair.secretKey)
                    }
                }.padding(.vertical, 10.0)
            }
            Utils.divider
            SecureField("Enter a 6 digit pin code", text: $pin).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                .padding(.top, 10.0).onChange(of: self.pin, { oldValue, value in
                    if value.count > 6 {
                        self.pin = String(value.prefix(6))
                   }
               })
            SecureField("Confirm pin code", text: $pinConfirmation).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                .padding(.bottom, 10.0).onChange(of: self.pinConfirmation, { oldValue, value in
                    if value.count > 6 {
                        self.pinConfirmation = String(value.prefix(6))
                   }
               })
            Utils.divider
            if isSigningUp {
                Utils.progressView
            } else {
                Button("Signup", action:   {
                    Task {
                        await signup()
                    }
                }).buttonStyle(.borderedProminent).tint(.green).padding(.vertical, 20.0)
            }
            if let error = signupError {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    var loginView: some View {
        VStack {
            Text("Login now!").bold().font(.title2)
            Utils.divider
            Text("Provide your 6-digit pincode to access the dashboard. To reiterate, this pincode never leaves your device, and your secret key is encrypted on your device and is never shared anywhere else.").font(.subheadline).multilineTextAlignment(.leading).italic().foregroundColor(.black)
            Utils.divider
            SecureField("Enter your pin", text: $pin).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                .padding(.vertical, 10.0).onChange(of: self.pin, { oldValue, value in
                    if value.count > 6 {
                        self.pin = String(value.prefix(6))
                   }
               })
            if isLoggingIn {
                Utils.progressView
            } else {
                if let error = loginError {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
                Button("Login", action:   {
                    Task {
                        await login()
                    }
                }).buttonStyle(.borderedProminent).tint(.green).padding(.vertical, 20.0)
            }
        }
    }
    
    private func signup() async {
        isSigningUp = true
        if pin.count < 6 {
            signupError = "invalid pin: 6 digits required"
        }
        else if pin != pinConfirmation {
            signupError = "pin & confirmation are not identical"
        } else {
            do {
                let address = try authService.signUp(userKeyPair: newUserKeypair, pin: pin)
                userLoggedIn(address)
            } catch {
                signupError = error.localizedDescription
            }
        }
        isSigningUp = false
    }
    
    private func login() async {
        isLoggingIn = true
        if pin.count < 6 {
            loginError = "invalid pin: 6 digits required"
        }
        else {
            do {
                let address = try authService.signIn(pin: pin)
                userLoggedIn(address)
            } catch {
                loginError = error.localizedDescription
            }
        }
        isLoggingIn = false
    }
    
    private func copyToClipboard(text:String) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = text
        toastMessage = "Copied to clipboard"
        showToast = true
    }
}

public func userLoggedInPreview(_ userAddress:String) -> Void {}

#Preview {
    AuthView(userLoggedIn:userLoggedInPreview)
}
