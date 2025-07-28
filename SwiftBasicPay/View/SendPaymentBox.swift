//
//  SendPaymentBox.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 23.07.25.
//

import SwiftUI
import stellar_wallet_sdk
import stellarsdk

/// For sending standard payments
struct SendPaymentBox: View {
    
    /// Holds the current user data.
    @EnvironmentObject var dashboardData: DashboardData
    
    /// Static picker items
    private static let xlmAssetItem = "native"
    private static let selectRecipient = "Select"
    private static let otherRecipient = "Other"
    
    /// Fetcher used to fetch the recipients assets from the Stellar Network.
    @StateObject var recipientAssetsFetcher = AssetsFetcher()
    
    /// State variable used to update the UI
    @State private var pathPaymentMode:Bool = false
    @State private var selectedAsset = xlmAssetItem
    @State private var selectedRecipient = selectRecipient
    @State private var recipientAccountId:String = ""
    @State private var pin:String = ""
    @State private var amountToSend:String = ""
    @State private var memoToSend:String = ""
    @State private var errorMessage:String?
    @State private var isSendingPayment:Bool = false
    
    var body: some View {
        GroupBox ("Send payment"){
            if isSendingPayment {
               HStack {
                   Utils.progressView
                   Spacer()
                   Text("Sending payment").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
               }
            } else {
                HStack {
                    Text("Asset:").font(.subheadline)
                    assetSelectionPicker
                    Text("To:").font(.subheadline)
                    recipientSelectionPicker
                }
                
                if selectedRecipient != SendPaymentBox.selectRecipient {
                    if selectedRecipient == SendPaymentBox.otherRecipient {
                        recipientAccountIdInputField
                    }
                    amountInputField
                    memoInputField
                    pinInputField
                    
                    if let error = errorMessage {
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                    }
                    submitAndCanelButtons
                }
            }
        }
    }
    
    var userAssets: [AssetInfo] {
        dashboardData.userAssets
    }
    
    var userContacts: [ContactInfo] {
        dashboardData.userContacts
    }
    
    private var assetSelectionPicker: some View {
        Picker("select asset", selection: $selectedAsset) {
            ForEach(userAssets, id: \.self) { asset in
                if let _ = asset.asset as? NativeAssetId {
                    Text("XLM").italic().foregroundColor(.black).tag(asset.id)
                } else if let issuedAsset = asset.asset as? IssuedAssetId {
                    Text("\(issuedAsset.code)").italic().foregroundColor(.black).tag(asset.id)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var recipientSelectionPicker: some View {
        Picker("select recipient", selection: $selectedRecipient) {
            Text(SendPaymentBox.selectRecipient).italic().foregroundColor(.black).tag(SendPaymentBox.selectRecipient)
            ForEach(userContacts, id: \.self) { contact in
                Text("\(contact.name)").italic().foregroundColor(.black).tag(contact.id as String).tag(contact.name)
            }
            Text(SendPaymentBox.otherRecipient).italic().foregroundColor(.black).tag(SendPaymentBox.otherRecipient)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var recipientAccountIdInputField : some View {
        TextField("Enter recipient account id", text: $recipientAccountId).textFieldStyle(.roundedBorder)
            .onChange(of: self.recipientAccountId, { oldValue, value in
                if value.count > 56 {
                    self.recipientAccountId = String(value.prefix(56))
               }
            })
    }
    
    private var amountInputField: some View  {
        TextField("Enter amount (max. \(Utils.removeTrailingZerosFormAmount(amount: String(maxAmount()))) )", text: $amountToSend).keyboardType(.decimalPad) .textFieldStyle(.roundedBorder)
            .onChange(of: self.amountToSend, { oldValue, value in
                if value != "" && Double(value) == nil {
                    self.amountToSend = oldValue
               }
            })
    }
    
    private var memoInputField: some View {
        TextField("Enter text memo (optional)", text: $memoToSend).textFieldStyle(.roundedBorder)
            .onChange(of: self.memoToSend, { oldValue, value in
                if value.count > 28 {
                    self.memoToSend = String(value.prefix(28))
               }
            })
    }
    
    private var pinInputField: some View {
        SecureField("Enter your pin", text: $pin).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            .padding(.top, 10.0).onChange(of: self.pin, { oldValue, value in
                if value.count > 6 {
                    self.pin = String(value.prefix(6))
               }
            })
    }
    
    private var submitAndCanelButtons : some View {
        HStack {
            Button("Submit", action:   {
                Task {
                    await sendStandardPayment()
                }
            }).buttonStyle(.borderedProminent).tint(.green).padding(.vertical, 20.0)
            Button("Cancel", action:   {
                resetState()
            }).buttonStyle(.borderedProminent).tint(.red)
        }
    }
    
    private func resetState() {
        errorMessage = ""
        recipientAccountId = ""
        amountToSend = ""
        memoToSend = ""
        pin = ""
        selectedRecipient = SendPaymentBox.selectRecipient
        selectedAsset = SendPaymentBox.xlmAssetItem
    }
    
    private func sendStandardPayment() async {
        
        if !checkPaymentFormData() {
            return
        }
        
        isSendingPayment = true
        
        do {
            let authService = AuthService()
            let userKeyPair = try authService.userKeyPair(pin: self.pin)
            let destinationExists = try await StellarService.accountExists(address: recipientAccountId)
            
            // if the destination account does not exist on the testnet, let's fund it with friendbot!
            // alternatively we can use the create account operation:
            // StellarService.createAccount(...)
            if !destinationExists {
                try await StellarService.fundTestnetAccount(address: recipientAccountId)
            }
            
            // find out if the recipient can receive the asset that
            // the user wants to send
            guard let asset = userAssets.filter({$0.id == selectedAsset}).first else {
                errorMessage = "Error finding selected asset"
                isSendingPayment = false
                return
            }
            // check if the recipient can receive the asset the user wants to send
            if let issuedAsset = asset.asset as? IssuedAssetId, issuedAsset.issuer != recipientAccountId {
                let recipientAssets = try await StellarService.loadAssetsForAddress(address: recipientAccountId)
                guard let _ = recipientAssets.filter({$0.id == selectedAsset}).first else {
                    errorMessage = "Recipient can not receive \(selectedAsset)"
                    isSendingPayment = false
                    return
                }
            }
            
            // send payment
            guard let stellarAssetId = asset.asset as? StellarAssetId else {
                errorMessage = "Error: asset is not a stellar asset"
                isSendingPayment = false
                return
            }
            
            var memo:Memo? = nil
            if !memoToSend.isEmpty {
                memo = try Memo(text: memoToSend)
            }
            
            let result = try await StellarService.sendPayment(
                destinationAddress: recipientAccountId,
                assetId: stellarAssetId,
                amount: Decimal(Double(amountToSend)!),
                memo: memo,
                userKeyPair: userKeyPair)
            if !result {
                errorMessage = "Error sending payment"
                isSendingPayment = false
                return
            } else {
                resetState()
                await dashboardData.fetchStellarData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSendingPayment = false
    }
    
    private func checkPaymentFormData() -> Bool {
        if selectedRecipient != SendPaymentBox.selectRecipient &&
            selectedRecipient != SendPaymentBox.otherRecipient {
            guard let contact = userContacts.filter({$0.id == selectedRecipient}).first else {
                errorMessage = "Could not find recipient"
                return false
            }
            recipientAccountId = contact.accountId
        }
        
        if recipientAccountId.isEmpty {
            errorMessage = "Missing recipient account id"
            return false
        }
        if !recipientAccountId.isValidEd25519PublicKey() {
            errorMessage = "Invalid recipient account id"
            return false
        }
        if amountToSend.isEmpty {
            errorMessage = "Missing amount"
            return false
        }
        guard let amount = Double(amountToSend) else {
            errorMessage = "Invalid amount"
            return false
        }
        if amount > maxAmount() {
            errorMessage = "Not enough funds"
            return false
        }
        if pin.isEmpty {
            errorMessage = "Missing pin"
            return false
        }
        return true
    }
    
    private func maxAmount() -> Double {
        if let asset = userAssets.filter({$0.id == selectedAsset}).first, let max = Double(asset.balance) {
            if asset.id == SendPaymentBox.xlmAssetItem  {
                return max > 2.0 ? max - 2.0 : 0
            } else {
                return max
            }
        }
        return 0
    }
    
}

#Preview {
    SendPaymentBox()
}
