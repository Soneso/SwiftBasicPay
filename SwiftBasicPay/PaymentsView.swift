//
//  PaymentsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import stellar_wallet_sdk
import AlertToast
import stellarsdk

struct PaymentsView: View {
    
    public let userAddress:String
    private static let xlmAssetItem = "native"
    private static let selectRecipient = "Select recipient"
    private static let otherRecipient = "Other"
    
    @State private var showToast = false
    @State private var toastMessage:String = ""
    @State private var isLoadingData:Bool = false
    @State private var accountFunded:Bool = true
    @State private var pathPaymentMode:Bool = false
    @State private var viewErrorMsg:String?
    @State private var contacts:[ContactInfo] = []
    @State private var assets:[AssetInfo] = []
    @State private var selectedAsset = xlmAssetItem
    @State private var selectedRecipient = selectRecipient
    @State private var recipientAccountId:String = ""
    @State private var pin:String = ""
    @State private var amountToSend:String = ""
    @State private var memoToSend:String = ""
    @State private var standardPaymentErrMsg:String?
    @State private var isSendingPayment:Bool = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                Text("Payments").foregroundColor(Color.blue).multilineTextAlignment(.leading).bold().font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                Utils.divider
                Text("Here you can send payments to other Stellar addresses.").italic().foregroundColor(.black)
                Utils.divider
                if let error = viewErrorMsg {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
                if isLoadingData {
                    Utils.progressView
                } else if !accountFunded {
                    Text("Your account is not yet funded. Switch to the 'Overview' Tab to fund your account first.").italic().foregroundColor(.orange)
                }
                else if isSendingPayment {
                    HStack {
                        Utils.progressView
                        Spacer()
                        Text("Sending payment").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Toggle("Send and receive different assets?", isOn: $pathPaymentMode).padding(.vertical, 10.0)
                    Utils.divider
                    if pathPaymentMode {
                        pathPaymentsView
                    } else {
                        standardPaymentsView
                    }
                    balancesView
                }
            }.padding().toast(isPresenting: $showToast){
                AlertToast(type: .regular, title: "\(toastMessage)")
            }
        }.onAppear() {
            Task {
                await loadData()
            }
        }
    }
    
    private var standardPaymentsView: some View  {
        GroupBox ("Send payment"){
            Spacer(minLength: 20)
            Picker("select asset", selection: $selectedAsset) {
                ForEach(assets, id: \.self) { asset in
                    let assetString = asset.id == "native" ? "XLM" : asset.id
                    Text("\(assetString)").italic().foregroundColor(.black).tag(asset.id)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 20)
            Picker("select recipient", selection: $selectedRecipient) {
                Text(PaymentsView.selectRecipient).italic().foregroundColor(.black).tag(PaymentsView.selectRecipient)
                ForEach(contacts, id: \.self) { contact in
                    Text("\(contact.name)").italic().foregroundColor(.black).tag(contact.id as String).tag(contact.name)
                }
                Text(PaymentsView.otherRecipient).italic().foregroundColor(.black).tag(PaymentsView.otherRecipient)
            }.frame(maxWidth: .infinity, alignment: .leading)
            
            if selectedRecipient != PaymentsView.selectRecipient {
                if selectedRecipient == PaymentsView.otherRecipient {
                    TextField("Enter recipient account id", text: $recipientAccountId).textFieldStyle(.roundedBorder)
                        .padding(.vertical, 10.0).onChange(of: self.recipientAccountId, { oldValue, value in
                            if value.count > 56 {
                                self.recipientAccountId = String(value.prefix(56))
                           }
                        })
                }
                TextField("Enter amount (max. \(Utils.removeTrailingZerosFormAmount(amount: String(maxAmount()))) )", text: $amountToSend).keyboardType(.decimalPad) .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 10.0).onChange(of: self.amountToSend, { oldValue, value in
                        if value != "" && Double(value) == nil {
                            self.amountToSend = oldValue
                       }
                    })
                TextField("Enter text memo (optional)", text: $memoToSend).textFieldStyle(.roundedBorder)
                    .padding(.vertical, 10.0).onChange(of: self.memoToSend, { oldValue, value in
                        if value.count > 28 {
                            self.memoToSend = String(value.prefix(28))
                       }
                    })
                SecureField("Enter your pin", text: $pin).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    .padding(.vertical, 10.0).onChange(of: self.pin, { oldValue, value in
                        if value.count > 6 {
                            self.pin = String(value.prefix(6))
                       }
                    })
                if let error = standardPaymentErrMsg {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
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
        }
    }
    
    private var pathPaymentsView: some View  {
        GroupBox ("Send path payment"){
        }
    }
    
    private var balancesView: some View  {
        GroupBox ("Your Balances") {
            Utils.divider
            // TODO: fix this because it is not updating after payment sent
            ForEach(assets, id: \.id) { asset in
                let formattedBalance = Utils.removeTrailingZerosFormAmount(amount: asset.balance)
                Spacer()
                Text("\(formattedBalance) \(asset.code)").italic().foregroundColor(.black).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func resetState() {
        standardPaymentErrMsg = ""
        recipientAccountId = ""
        amountToSend = ""
        memoToSend = ""
        pin = ""
        selectedRecipient = PaymentsView.selectRecipient
        selectedAsset = PaymentsView.xlmAssetItem
    }
    private func sendStandardPayment() async {
        
        if !checkStandardPaymentFormData() {
            return
        }
        
        isSendingPayment = true
        
        do {
            let authService = AuthService()
            let userKeyPair = try authService.userKeyPair(pin: self.pin)
            let destinationExists = try await StellarService.accountExists(address: recipientAccountId)
            
            // if the destination account does not exist on the testnet, let's fund it!
            // alternatively we can use the create account operation.
            if !destinationExists {
                try await StellarService.fundTestnetAccount(address: recipientAccountId)
            }
            
            // find out if the recipient can receive the asset that
            // the user wants to send
            guard let asset = assets.filter({$0.id == selectedAsset}).first else {
                standardPaymentErrMsg = "Error finding selected asset"
                isSendingPayment = false
                return
            }
            if let issuedAsset = asset.asset as? IssuedAssetId, issuedAsset.issuer != recipientAccountId {
                let recipientAssets = try await StellarService.loadAssetsForAddress(address: recipientAccountId)
                guard let _ = recipientAssets.filter({$0.id == selectedAsset}).first else {
                    standardPaymentErrMsg = "Recipient can not receive \(selectedAsset)"
                    isSendingPayment = false
                    return
                }
            }
            
            // send payment
            guard let stellarAssetId = asset.asset as? StellarAssetId else {
                standardPaymentErrMsg = "Error: asset is not a stellar asset"
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
                standardPaymentErrMsg = "Error sending payment"
                isSendingPayment = false
                return
            } else {
                showToast = true
                toastMessage = "Payment sent"
                resetState()
                await loadData()
            }
        } catch {
            standardPaymentErrMsg = error.localizedDescription
        }
        isSendingPayment = false
    }
    
    private func checkStandardPaymentFormData() -> Bool {
        if selectedRecipient != PaymentsView.selectRecipient &&
            selectedRecipient != PaymentsView.otherRecipient {
            guard let contact = contacts.filter({$0.id == selectedRecipient}).first else {
                standardPaymentErrMsg = "Could not find recipient"
                return false
            }
            recipientAccountId = contact.accountId
        }
        
        if recipientAccountId.isEmpty {
            standardPaymentErrMsg = "Missing recipient account id"
            return false
        }
        if !recipientAccountId.isValidEd25519PublicKey() {
            standardPaymentErrMsg = "Invalid recipient account id"
            return false
        }
        if amountToSend.isEmpty {
            standardPaymentErrMsg = "Missing amount"
            return false
        }
        guard let amount = Double(amountToSend) else {
            standardPaymentErrMsg = "Invalid amount"
            return false
        }
        if amount > maxAmount() {
            standardPaymentErrMsg = "Not enough funds"
            return false
        }
        if pin.isEmpty {
            standardPaymentErrMsg = "Missing pin"
            return false
        }
        return true
    }
    
    private func loadData() async {
        isLoadingData = true
 
        do {
            let accountExists = try await StellarService.accountExists(address: userAddress)
            if !accountExists {
                accountFunded = false
            } else {
                contacts = SecureStorage.getContacts()
                assets = try await StellarService.loadAssetsForAddress(address: userAddress)
            }
        } catch {
            viewErrorMsg = error.localizedDescription
        }
        isLoadingData = false
    }
    
    private func maxAmount() -> Double {
        if let asset = assets.filter({$0.id == selectedAsset}).first, let max = Double(asset.balance) {
            if asset.id == PaymentsView.xlmAssetItem  {
                return max > 2.0 ? max - 2.0 : 0
            } else {
                return max
            }
        }
        return 0
    }
}

#Preview {
    PaymentsView(userAddress: "GAG4MYEEIJZ7DGS2PGCEEY5PX3HMZC7L7KK62BFLJ3LSYQIS4TYC4ETJ")
                 // not funded: GADABN2XLZ2EYWOQJJVGKCIHJ2PJERSQGLX6TQTGOYPODPNI4OYXGN36
}
