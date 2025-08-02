//
//  SettingsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 30.06.25.
//

import SwiftUI

struct SettingsView: View {
    
    private let logoutUser:(() -> Void)
    
    @State private var isResettingApp:Bool = false
    @State private var resetAppError:String?
    
    internal init(logoutUser: @escaping (() -> Void)) {
        self.logoutUser = logoutUser
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                Text("Settings").foregroundColor(Color.blue).multilineTextAlignment(.leading).bold().font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                GroupBox ("Sign out"){
                    Utils.divider
                    Spacer()
                    Text("Exit to the login screen.").italic().foregroundColor(.black).frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Spacer()
                        Button("Sign out") {
                            signOut()
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding(.vertical, 20.0)
                }
                GroupBox ("Reset demo app"){
                    Utils.divider
                    Spacer()
                    Text("By resetting the demo app, your data, including your secret key, will be deleted from the keychain. This is helpful if you want to restart the signup process. However, your current data will be deleted forever.").italic().foregroundColor(.black)
                    if isResettingApp {
                        Utils.progressView
                    } else {
                        Button("Reset demo app", action:   {
                            Task {
                                await resetDemoApp()
                            }
                        }).buttonStyle(.borderedProminent).tint(.red).padding(.vertical, 20.0)
                        if let error = resetAppError {
                            Spacer()
                            Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }.padding()
        }
    }
    
    private func resetDemoApp() async {
        isResettingApp = true
        resetAppError = nil
        do {
            try SecureStorage.deleteAll()
        } catch {
            resetAppError = error.localizedDescription
        }
        isResettingApp = false
        logoutUser()
    }
    
    private func signOut() {
        logoutUser()
    }
}

public func logoutUserSettingsPreview() -> Void {}

#Preview {
    SettingsView(logoutUser: logoutUserSettingsPreview)
}
