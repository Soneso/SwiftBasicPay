//
//  PinSheet.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 01.07.25.
//

import SwiftUI
import stellar_wallet_sdk

struct PinSheet: View {
    
    
    @Environment(\.dismiss) var dismiss
    
    private let onSuccess:((_ signingKey:SigningKeyPair) -> Void)
    private let onCancel:(() -> Void)
    
    @State private var err:String?
    @State private var pin:String = ""
    @State private var isCheckingPin:Bool = false
    
    internal init(onSuccess: @escaping ((SigningKeyPair) -> Void), onCancel: @escaping (() -> Void)) {
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack {
            Text("Enter your Pin!").bold().font(.title).frame(maxWidth: .infinity, alignment: .center)
            Utils.divider
            Text("Please enter your pin to continue!").italic().foregroundColor(.black).frame(maxWidth: .infinity, alignment: .leading)
            Utils.divider
            SecureField("Enter your pin", text: $pin).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                .padding(.vertical, 10.0).onChange(of: self.pin, { oldValue, value in
                    if value.count > 6 {
                        self.pin = String(value.prefix(6))
                   }
               })
            if let error = err {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
            if isCheckingPin {
                Utils.progressView
            } else {
                HStack {
                    Button("Submit", action:   {
                        Task {
                            await checkPin()
                        }
                    }).buttonStyle(.borderedProminent).tint(.green).padding(.vertical, 20.0)
                    Button("Cancel", action:   {
                        err = nil
                        dismiss()
                        onCancel()
                    }).buttonStyle(.borderedProminent).tint(.red).padding(.vertical, 20.0)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding()
    }
    
    private func checkPin() async {
        err = nil
        if pin.isEmpty {
            err = "please enter your pin"
            return
        }
        
        isCheckingPin = true
        do {
            let authService = AuthService()
            let userKeyPair = try authService.userKeyPair(pin: self.pin)
            isCheckingPin = false
            dismiss()
            onSuccess(userKeyPair)
        } catch {
            err = error.localizedDescription
            isCheckingPin = false
        }
    }
}

public func onCancelPinSheetPreview() -> Void {}
public func onSuccessPinViewPreview(_ signingKey:SigningKeyPair) -> Void {}
#Preview {
    PinSheet(onSuccess: onSuccessPinViewPreview(_:), onCancel: onCancelPinSheetPreview)
}
