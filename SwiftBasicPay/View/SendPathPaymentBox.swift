//
//  SendPathPaymentBox.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 23.07.25.
//

import SwiftUI
import stellar_wallet_sdk
import stellarsdk

struct SendPathPaymentBox: View {
    
    @EnvironmentObject var dashboardData: DashboardData
    
    private static let xlmAssetItem = "native"
    private static let selectRecipient = "Select recipient"
    private static let otherRecipient = "Other"
    @StateObject var recipientAssetsFetcher = AssetsFetcher()
    @State private var selectedAssetToSend = xlmAssetItem
    @State private var selectedAssetToReceive = xlmAssetItem
    @State private var selectedRecipient = selectRecipient
    @State private var recipientAccountId:String = ""
    @State private var pin:String = ""
    @State private var amountToSend:String = ""
    @State private var memoToSend:String = ""
    @State private var strictSend:Bool = true
    @State private var errorMessage:String?
    @State private var invalidDestinationErrorMsg:String?
    @State private var invalidAmountToSendErrorMsg:String?
    @State private var findPathErrorMsg:String?
    @State private var state:PathPaymentBoxState = .initial
    @State private var selectedPath:PaymentPath?
    @State private var sendPaymentErrorMsg:String?
    
    var body: some View {
        GroupBox ("Send path payment"){

            if state != .sending {
                if let error = errorMessage {
                    Text("Error: \(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                }
                recipientSelectionView
                
                if state == .loadingDestinationAssets {
                    progressView(text: "Loading destination assets")
                }
                if state.rawValue >=  PathPaymentBoxState.destinationAssetsLoaded.rawValue {
                    if state == .pathSelected {
                        submitView
                    } else {
                        assetSelectionView
                    }
                }
            } else {
                progressView(text: "Sending payment")
            }
        }
    }
    
    enum PathPaymentBoxState : Int {
        typealias RawValue = Int
        
        case initial = 0
        case otherRecipientSelected = 1
        case loadingDestinationAssets = 3
        case loadingDestinationAssetsError = 4
        case destinationAssetsLoaded = 5
        case loadingPath = 6
        case loadingPathError = 7
        case pathSelected = 8
        case sending = 9
        case sendingError = 10
    }
    
    var userAssets: [AssetInfo] {
        dashboardData.userAssets
    }
    
    var userContacts: [ContactInfo] {
        dashboardData.userContacts
    }
    
    var assetsThatCanBeSent: [AssetInfo] {
        // remove assets with balance == 0
        return userAssets.filter({Decimal(Double($0.balance) ?? 0) != 0})
    }
    
    var assetsThatCanBeReceived: [AssetInfo] {
        return recipientAssetsFetcher.assets
    }
    
    private var submitView: some View {
        VStack {
            if let text = pathText {
                Text("\(text)").font(.subheadline).fontWeight(.semibold).foregroundStyle(.green).frame(maxWidth: .infinity, alignment: .leading)
                
                memoInputField
                pinInputField
                submitAndCanelButtons
            } else {
                Text("Error: path is nil").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var pathText:String? {
        guard let selectedPath = selectedPath else {
            return nil
        }
        let sourceAmountStr = Utils.removeTrailingZerosFormAmount(amount: selectedPath.sourceAmount)
        let sourceAssetStr = selectedPath.sourceAsset.id == "native" ? "XLM" : (selectedPath.sourceAsset as! IssuedAssetId).code
        let sendEstimated = strictSend ? "" : "(estimated)"
        let destinationAmountStr = Utils.removeTrailingZerosFormAmount(amount: selectedPath.destinationAmount)
        let destinationAssetStr = selectedPath.destinationAsset.id == "native" ? "XLM" : (selectedPath.destinationAsset as! IssuedAssetId).code
        let receiveEstimated = strictSend ? "(estimated)" : ""
        return "You send \(sourceAmountStr) \(sourceAssetStr) \(sendEstimated) and the recipient receives \(destinationAmountStr) \(destinationAssetStr) \(receiveEstimated)"
    }
    
    private var assetSelectionView: some View {
        VStack {
            Toggle("Strict send", isOn: $strictSend).padding(.vertical, 10.0)
            HStack {
                if strictSend {
                    Text("Send:").font(.subheadline)
                    Picker("select asset to send", selection: $selectedAssetToSend) {
                        ForEach(assetsThatCanBeSent, id: \.self) { asset in
                            if let _ = asset.asset as? NativeAssetId {
                                Text("XLM").italic().foregroundColor(.black).tag(asset.id)
                            } else if let issuedAsset = asset.asset as? IssuedAssetId {
                                Text("\(issuedAsset.code)").italic().foregroundColor(.black).tag(asset.id)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Receive:").font(.subheadline)
                    Picker("select asset to receive", selection: $selectedAssetToReceive) {
                        ForEach(assetsThatCanBeReceived, id: \.self) { asset in
                            if let _ = asset.asset as? NativeAssetId {
                                Text("XLM").italic().foregroundColor(.black).tag(asset.id)
                            } else if let issuedAsset = asset.asset as? IssuedAssetId {
                                Text("\(issuedAsset.code)").italic().foregroundColor(.black).tag(asset.id)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            amountInputField
            if let error = invalidAmountToSendErrorMsg {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error = findPathErrorMsg {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
            }
            if state == .loadingPath {
                progressView(text: "Searching payment path")
            } else {
                Button("Find path", action:   {
                    Task {
                        if validateAmountToSend() {
                            await findPath()
                        }
                    }
                }).buttonStyle(.borderedProminent).tint(.green).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func findPath() async {
        state = .loadingPath
        
        var assetFromList:AssetInfo?
        if strictSend {
            assetFromList = userAssets.filter({$0.id == selectedAssetToSend}).first
        } else {
            assetFromList = assetsThatCanBeReceived.filter({$0.id == selectedAssetToReceive}).first
        }
        
        guard let asset = assetFromList else {
            findPathErrorMsg = "Error finding selected asset"
            state = .loadingPathError
            return
        }
        guard let stellarAsset = asset.asset as? StellarAssetId else {
            findPathErrorMsg = "Invalid asset"
            state = .loadingPathError
            return
        }
        guard let amount = Double(amountToSend) else {
            findPathErrorMsg = "Invalid amount."
            state = .loadingPathError
            return
        }
        
        do {
            var paths:[PaymentPath] = []
            if strictSend {
                paths = try await StellarService.findStrictSendPaymentPath(sourceAsset: stellarAsset, sourceAmount: Decimal(amount), destinationAddress: recipientAccountId)
            } else {
                paths = try await StellarService.findStrictReceivePaymentPath(sourceAddress: dashboardData.userAddress, destinationAsset: stellarAsset, destinationAmount: Decimal(amount))
            }
            if paths.isEmpty {
                findPathErrorMsg = "No payment path found for the given data"
                state = .loadingPathError
                return
            }
            // in a real app you would let the user select the path
            // for now, we just take the first.
            selectedPath = paths.first
            state = .pathSelected
        } catch {
            findPathErrorMsg = "Error finding path: \(error.localizedDescription)"
            state = .loadingPathError
        }
    }
    
    private func validateAmountToSend() -> Bool {
        invalidAmountToSendErrorMsg = nil
        if amountToSend.isEmpty {
            invalidAmountToSendErrorMsg = "Please enter amount."
            return false
        }
        guard let amount = Double(amountToSend) else {
            invalidAmountToSendErrorMsg = "Invalid amount."
            return false
        }
        if strictSend {
            let max = maxAmount()
            if amount > max {
                invalidAmountToSendErrorMsg = "Amount can not be greater than \(max)"
                return false
            }
        }
        return true
    }
    
    private func progressView(text:String) -> some View {
        HStack {
            Utils.progressView
            Spacer()
            Text(text).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var recipientSelectionView: some View {
        VStack {
            HStack {
                Text("To:").font(.subheadline)
                recipientSelectionPicker
                
                if state.rawValue >=  PathPaymentBoxState.loadingDestinationAssets.rawValue {
                    recipientAccountIdView
                }
            }
            if state == .otherRecipientSelected {
                recipientAccountIdInputField
            }
            if let error = invalidDestinationErrorMsg {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var recipientAccountIdView: some View {
        Text("\(Utils.shortAddress(address: recipientAccountId))").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).italic().foregroundColor(.blue)
    }
    
    private var recipientSelectionPicker: some View {
        Picker("select recipient", selection: $selectedRecipient) {
            Text(SendPathPaymentBox.selectRecipient).italic().foregroundColor(.black).tag(SendPathPaymentBox.selectRecipient)
            ForEach(userContacts, id: \.self) { contact in
                Text("\(contact.name)").italic().foregroundColor(.black).tag(contact.id as String).tag(contact.name)
            }
            Text(SendPathPaymentBox.otherRecipient).italic().foregroundColor(.black).tag(SendPathPaymentBox.otherRecipient)
        }.frame(maxWidth: .infinity, alignment: .leading).onChange(of: selectedRecipient, initial: true) { oldVal, newVal in Task {
            await selectedRecepientChanged(oldValue:oldVal, newValue:newVal)
        }}
    }
    
    private var recipientAccountIdInputField : some View {
        
        HStack {
            TextField("Enter recipient account id", text: $recipientAccountId).textFieldStyle(.roundedBorder)
                .onChange(of: self.recipientAccountId, { oldValue, value in
                    if value.count > 56 {
                        self.recipientAccountId = String(value.prefix(56))
                   }
                })
            Button("Check", action:   {
                Task {
                    await validateRecepientAccountId()
                    if invalidDestinationErrorMsg == nil {
                        await loadPathPaymentDestinationAssets(destAccountId:recipientAccountId)
                    }
                }
            }).buttonStyle(.borderedProminent).tint(.green)
        }
    }
    
    private var amountInputField: some View  {
        let max = strictSend ? "(max. \(Utils.removeTrailingZerosFormAmount(amount: String(maxAmount()))) )" : ""
        return TextField("Enter amount \(max)", text: $amountToSend).keyboardType(.decimalPad) .textFieldStyle(.roundedBorder)
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
            .onChange(of: self.pin, { oldValue, value in
                if value.count > 6 {
                    self.pin = String(value.prefix(6))
               }
            })
    }
    
    private func selectedRecepientChanged(oldValue:String, newValue:String) async {
        if newValue == SendPathPaymentBox.selectRecipient {
            recipientAccountId = ""
            state = PathPaymentBoxState.initial
            return
        }
        if newValue == SendPathPaymentBox.otherRecipient {
            recipientAccountId = ""
            state = PathPaymentBoxState.otherRecipientSelected
            return
        } else {
            guard let contact = userContacts.filter({$0.id == newValue}).first else {
                invalidDestinationErrorMsg = "Could not find recipient"
                return
            }
            recipientAccountId = contact.accountId
            await validateRecepientAccountId()
            if invalidDestinationErrorMsg == nil {
                await loadPathPaymentDestinationAssets(destAccountId: contact.accountId)
            }
        }
    }
    
    public func validateRecepientAccountId() async {
        invalidDestinationErrorMsg = nil
        if recipientAccountId.isEmpty {
            invalidDestinationErrorMsg = "Please insert the recipient`s account id"
            return
        }
        if !recipientAccountId.isValidEd25519PublicKey() {
            invalidDestinationErrorMsg = "The recipient`s account id is not valid"
            return
        }
        do {
            let exists = try await StellarService.accountExists(address: recipientAccountId)
            if !exists {
                invalidDestinationErrorMsg = "The recipient`s was not found on the Stellar Network. It needs to be funded first."
            }
        } catch {
            invalidDestinationErrorMsg = "Could not check if recipient account exists."
        }
    }
    
    private func loadPathPaymentDestinationAssets(destAccountId:String) async {
        state = PathPaymentBoxState.loadingDestinationAssets
        await recipientAssetsFetcher.fetchAssets(accountId: destAccountId)
        if let error =  recipientAssetsFetcher.error {
            switch error {
            case .accountNotFound(_):
                errorMessage = "The recipient account was not found on the Stellar Network. It needs to be funded first."
            case .fetchingError(_, let message):
                errorMessage = message
            }
            errorMessage = error.localizedDescription
            state = PathPaymentBoxState.loadingDestinationAssetsError
            return
        }
        
        
        state = PathPaymentBoxState.destinationAssetsLoaded
    }
    
    private var submitAndCanelButtons : some View {
        HStack {
            Button("Submit", action:   {
                Task {
                    await sendPathPayment()
                }
            }).buttonStyle(.borderedProminent).tint(.green).padding(.vertical, 20.0)
            Button("Cancel", action:   {
                resetState()
            }).buttonStyle(.borderedProminent).tint(.red)
        }
    }
    
    private func sendPathPayment() async {
        state = .sending
        if !checkPaymentFormData() {
            state = .sendingError
            return
        }
        
        guard let path = selectedPath else {
            sendPaymentErrorMsg = "Selected path is nil"
            state = .sendingError
            return
        }
        
        do {
            let authService = AuthService()
            let userKeyPair = try authService.userKeyPair(pin: self.pin)
            
            var result = false
            if strictSend {
                result = try await StellarService.strictSendPayment(
                    sendAssetId: path.sourceAsset,
                    sendAmount: Decimal(Double(path.sourceAmount)!),
                    destinationAddress: recipientAccountId,
                    destinationAssetId: path.destinationAsset,
                    destinationMinAmount: Decimal(Double(path.destinationAmount)!),
                    path: path.path,
                    memo: memoToSend,
                    userKeyPair: userKeyPair)
            } 
            else
            {
             result = try await StellarService.strictReceivePayment(
                sendAssetId: path.sourceAsset,
                sendMaxAmount: Decimal(Double(path.sourceAmount)!),
                destinationAddress: recipientAccountId,
                destinationAssetId: path.destinationAsset,
                destinationAmount: Decimal(Double(path.destinationAmount)!),
                path: path.path,
                memo: memoToSend,
                userKeyPair: userKeyPair)
            }
            
            if !result {
                sendPaymentErrorMsg = "Error sending payment"
                state = .sendingError
                return
            } else {
                resetState()
                await dashboardData.fetchStellarData()
            }
            
        } catch {
            sendPaymentErrorMsg = error.localizedDescription
            state = .sendingError
        }
    }
    
    private func checkPaymentFormData() -> Bool {
        
        if recipientAccountId.isEmpty {
            sendPaymentErrorMsg = "Missing recipient account id"
            return false
        }
       
        if amountToSend.isEmpty {
            sendPaymentErrorMsg = "Missing amount"
            return false
        }
        
        if pin.isEmpty {
            sendPaymentErrorMsg = "Missing pin"
            return false
        }
        return true
    }
    
    private func resetState() {
        errorMessage = nil
        sendPaymentErrorMsg = nil
        findPathErrorMsg = nil
        recipientAccountId = ""
        amountToSend = ""
        memoToSend = ""
        pin = ""
        selectedRecipient = SendPathPaymentBox.selectRecipient
        selectedAssetToSend = SendPathPaymentBox.xlmAssetItem
        selectedAssetToReceive = SendPathPaymentBox.xlmAssetItem
        selectedPath = nil
        state = .initial
    }
    
    private func maxAmount() -> Double {
        if let asset = userAssets.filter({$0.id == selectedAssetToSend}).first, let max = Double(asset.balance) {
            if asset.id == SendPathPaymentBox.xlmAssetItem  {
                return max > 2.0 ? max - 2.0 : 0
            } else {
                return max
            }
        }
        return 0
    }
}

#Preview {
    SendPathPaymentBox()
}
