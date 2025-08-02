//
//  Sep6WithdrawalStepper.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 02.08.25.
//


import SwiftUI
import stellar_wallet_sdk
import AlertToast

struct Sep6WithdrawalStepper: View {

    private let anchoredAsset:AnchoredAssetInfo
    private let withdrawInfo:Sep6WithdrawInfo
    private let authToken:AuthToken
    private let anchorHasEnabledFeeEndpoint:Bool
    private let stepTitles = ["Transfer details", "KYC Data", "Fee", "Summary"]
    private let selectItem = "select"
    private let savedKycData:[KycEntry]
    
    internal init(anchoredAsset: AnchoredAssetInfo,
                  withdrawInfo: Sep6WithdrawInfo,
                  authToken: AuthToken,
                  anchorHasEnabledFeeEndpoint:Bool,
                  savedKycData:[KycEntry] = []) {
        self.anchoredAsset = anchoredAsset
        self.withdrawInfo = withdrawInfo
        self.authToken = authToken
        self.anchorHasEnabledFeeEndpoint = anchorHasEnabledFeeEndpoint
        self.savedKycData = savedKycData
    }
    
    @Environment(\.dismiss) private var dismiss // Environment property for dismissing the sheet
    
    @State private var currentStep = 1

    @State private var collectedTransferDetails:[String] = []
    @State private var transferAmount:String = ""
    @State private var transferFieldsError:String?
    @State private var isLoadingKyc = false
    @State private var kycLoadingText:String = ""
    @State private var kycInfo:GetCustomerResponse?
    @State private var kycFieldsError:String?
    @State private var collectedKycDetails:[String] = []
    @State private var isLoadingFee = false
    @State private var feeError:String?
    @State private var fee:Double?
    @State private var isSubmitting = false
    @State private var submissionError:String?
    @State private var submissionResponse:Sep6TransferResponse?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                
                Text("Asset: \(anchoredAsset.code)").font(.subheadline)
                Text("Step \(currentStep) of 4 - \(stepTitles[currentStep - 1])")
                    .font(.subheadline).fontWeight(.bold)
                

                if currentStep == 1 {
                    Text("The anchor requested following information about your transfer:").font(.subheadline)
                    // Amount is always needed
                    amountInputField
                    transferFields
                    if let error = transferFieldsError {
                        Utils.divider
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                } else if currentStep == 2 {
                    if isLoadingKyc {
                        Utils.progressViewWithLabel(kycLoadingText)
                    }
                    else if let info = kycInfo {
                        if info.sep12Status == Sep12Status.neesdInfo {
                            Text("The anchor needs following of your KYC data:").font(.subheadline)
                            kycFields
                        } else if(info.sep12Status == Sep12Status.accepted) {
                            Text("Your KYC data has been accepted by the anchor.").font(.subheadline)
                            Button("Delete") {
                                Task {
                                    await deleteKYCData()
                                }
                            }
                        } else if(info.sep12Status == Sep12Status.processing) {
                            Text("Your KYC data is currently being processed by the anchor.").font(.subheadline)
                        } else if(info.sep12Status == Sep12Status.rejected) {
                            Text("Your KYC data has been rejected by the anchor.").font(.subheadline)
                        }
                        if let error = kycFieldsError {
                            Utils.divider
                            Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else if currentStep == 3 {
                    if isLoadingFee {
                        Utils.progressViewWithLabel("Loading fee data")
                    } else {
                        if let anchorFee = fee {
                            let feeStr = anchorFee.toStringWithoutTrailingZeros
                            Text("The Anchor will charge a fee of \(feeStr) \(anchoredAsset.code).").padding(.leading).frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("The Anchor provides no fee info for the asset \(anchoredAsset.code).").padding(.leading).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let error = feeError {
                            Utils.divider
                            Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else if currentStep == 4 {
                    
                    if isSubmitting {
                        Utils.progressViewWithLabel("Submitting data to anchor")
                    } else if let response = submissionResponse {
                        Sep6TransferResponseView(response: response)
                    }
                    else {
                        let withdrawalAmountStr = transferAmount.amountWithoutTrailingZeros
                        Text("Withdraw: \(withdrawalAmountStr) \(anchoredAsset.code)").padding(.leading).frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let anchorFee = fee {
                            let feeStr = anchorFee.toStringWithoutTrailingZeros
                            Text("Fee: \(feeStr) \(anchoredAsset.code).").padding(.leading).frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Fee: unknown").padding(.leading).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        if let error = submissionError {
                            Utils.divider
                            Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                }
                Utils.divider
                navigationButtons
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("SEP-06 Deposit Stepper").font(.headline).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }.navigationBarTitleDisplayMode(.inline).navigationTitle("")
        }.onAppear(perform: {
            // in a real app let the user choose the type.
            if let winfo = withdrawInfo.types?.first?.value {
                for key in winfo.keys {
                    if let val = winfo[key] {
                        if val.choices != nil && !val.choices!.isEmpty {
                            self.collectedTransferDetails.append(selectItem)
                        } else {
                            self.collectedTransferDetails.append("")
                        }
                    }
                }
            }
        })
    }
    
    private var navigationButtons: some View {
        HStack {
            if submissionResponse == nil {
                Button("Previous") {
                    if currentStep > 1 {
                        currentStep -= 1
                    }
                }
                .disabled(currentStep == 1)
            }

            Spacer()

            if currentStep < 4 {
                Button("Next") {
                    if currentStep == 1 && validateTransferFields(){
                        currentStep += 1
                        Task {
                            await loadKYCData()
                        }
                    } else if currentStep == 2 {
                        if (kycInfo?.sep12Status == Sep12Status.neesdInfo && validateKycFields()) {
                            Task {
                                await submitKYCData()
                            }
                        } else if (kycInfo?.sep12Status == Sep12Status.accepted) {
                            currentStep += 1
                            Task {
                                await loadFeeInfo()
                            }
                        }
                    }
                    else {
                        currentStep += 1
                    }
                }
            } else {
                if submissionResponse == nil {
                    Button("Submit") {
                        Task {
                            await submitTransfer()
                        }
                    }
                } else {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .padding(.trailing)
    }
    
    private var amountInputField: some View  {
        let min = minAmount.toStringWithoutTrailingZeros
        let max = maxAmount != nil ? " max: \(maxAmount!.toStringWithoutTrailingZeros)" : ""

        return VStack {
            TextField("Enter amount", text: $transferAmount).keyboardType(.decimalPad) .textFieldStyle(.roundedBorder)
                .onChange(of: self.transferAmount, { oldValue, value in
                    if value != "" && Double(value) == nil {
                        self.transferAmount = oldValue
                    }
                })
            
            Text("min: \(min) \(max)").font(.subheadline).font(.caption)
                .fontWeight(.light).italic()
                .foregroundColor(.orange).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var minAmount : Double {
        return withdrawInfo.minAmount ?? 0
    }
    
    private var maxAmount : Double? {
        return withdrawInfo.maxAmount
    }
    
    var transferFieldInfos: [TransferFieldInfo] {
        var info:[TransferFieldInfo] = []
        if let winfo = withdrawInfo.types?.first?.value {
            for key in winfo.keys {
                if let val = winfo[key] {
                    info.append(TransferFieldInfo(key: key, info: val))
                }
            }
        }
        return info
    }
        
    private func indexForTransferFieldKey(key:String) -> Int {
        if let winfo = withdrawInfo.types?.first?.value {
            for (index, infoKey) in winfo.keys.enumerated() {
                if key == infoKey {
                    return index
                }
            }
        }
        return -1
    }
    
    private var transferFields : some View {
        VStack {
            if !collectedTransferDetails.isEmpty {
                ScrollView {
                    ForEach(transferFieldInfos, id: \.key) { info in
                        
                        if let choices = info.info.choices, !choices.isEmpty {
                            HStack {
                                Text("\(info.key):").font(.subheadline).fontWeight(.light)
                                Picker("select \(info.key)", selection: $collectedTransferDetails[indexForTransferFieldKey(key: info.key)]) {
                                    Text(selectItem).italic().foregroundColor(.black).tag(selectItem)
                                    ForEach(choices, id: \.self) { choice in
                                        Text(choice).italic().foregroundColor(.black).tag(choice)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                
                            }
                        } else {
                            TextField("\(info.key)", text: $collectedTransferDetails[indexForTransferFieldKey(key: info.key)])
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        let optional = info.optional ? "(optional)" : "*"
                        Text("\(optional) \(info.info.description ?? "")").font(.subheadline).font(.caption)
                            .fontWeight(.light).italic()
                            .foregroundColor(info.optional ? .secondary : .orange).frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 10)
                    }
                }
            }
        }
    }
    
    private func validateTransferFields() -> Bool {
        transferFieldsError = nil
        if transferAmount.isEmpty {
            transferFieldsError = "Amount is not optional"
            return false
        }
        guard let amount = Double(transferAmount) else {
            transferFieldsError = "Invalid amount"
            return false
        }
        if let maxAmount = maxAmount, amount > maxAmount {
            transferFieldsError = "Amount is to high."
            return false
        }
        
        if let winfo = withdrawInfo.types?.first?.value {
            for (index, infoKey) in winfo.keys.enumerated() {
                let field = winfo[infoKey]
                let optional = field?.optional ?? false
                if !optional {
                    let val = collectedTransferDetails[index]
                    if val.isEmpty || val == selectItem {
                        transferFieldsError = "\(infoKey) is not optional"
                        return false
                    }
                }
            }
        }
        
        return true
    }
    
    var kycFieldInfos: [KycFieldInfo] {
        var info:[KycFieldInfo] = []
        if let dinfo = kycInfo?.fields {
            for key in dinfo.keys {
                if let val = dinfo[key] {
                    info.append(KycFieldInfo(key: key, info: val))
                }
            }
        }
        return info
    }
    
    private func indexForKycFieldKey(key:String) -> Int {
        if let dinfo = kycInfo?.fields {
            for (index, infoKey) in dinfo.keys.enumerated() {
                if key == infoKey {
                    return index
                }
            }
        }
        return -1
    }
    
    private var kycFields : some View {
        VStack {
            if !collectedKycDetails.isEmpty {
                ScrollView {
                    ForEach(kycFieldInfos, id: \.key) { info in
                        if let choices = info.info.choices, !choices.isEmpty {
                            HStack {
                                Text("\(info.key):").font(.subheadline).fontWeight(.light)
                                Picker("select \(info.key)", selection: $collectedKycDetails[indexForKycFieldKey(key: info.key)]) {
                                    Text(selectItem).italic().foregroundColor(.black).tag(selectItem)
                                    ForEach(choices, id: \.self) { choice in
                                        Text(choice).italic().foregroundColor(.black).tag(choice)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                
                            }
                        } else {
                            TextField("\(info.key)", text: $collectedKycDetails[indexForKycFieldKey(key: info.key)])
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        let optional = info.optional ? "(optional)" : "*"
                        Text("\(optional) \(info.info.description ?? "")").font(.caption)
                            .fontWeight(.light).italic()
                            .foregroundColor(info.optional ? .secondary : .orange).frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 20)
                    }
                }
            }
        }
    }
    
    private func validateKycFields() -> Bool {
        kycFieldsError = nil
        if let dinfo = kycInfo?.fields {
            for (index, infoKey) in dinfo.keys.enumerated() {
                let field = dinfo[infoKey]
                let optional = field?.optional ?? false
                if !optional {
                    let val = collectedKycDetails[index]
                    if val.isEmpty || val == selectItem {
                        kycFieldsError = "\(infoKey) is not optional"
                        return false
                    }
                }
            }
        }
        
        return true
    }
    
    private func loadKYCData() async {
        kycLoadingText = "Loading KYC data"
        isLoadingKyc = true
        kycInfo = nil
        kycFieldsError =  nil
        do {
            let sep12 = try await anchoredAsset.anchor.sep12(authToken: authToken)
            kycInfo = try await sep12.getByAuthTokenOnly()
            print("kyc status: \(kycInfo!.sep12Status.rawValue)")
            collectedKycDetails = []
            if let dinfo = kycInfo?.fields {
                for key in dinfo.keys {
                    if let val = dinfo[key] {
                        if val.choices != nil && !val.choices!.isEmpty {
                            self.collectedKycDetails.append(selectItem)
                        } else {
                            var value = ""
                            if let saved = savedKycData.filter({$0.id == key}).first {
                                value = saved.val
                            }
                            self.collectedKycDetails.append(value)
                        }
                    }
                }
            }
        } catch {
            kycFieldsError = "Could not load SEP-12 (KYC) info from anchor: \(error.localizedDescription)"
        }
        isLoadingKyc = false
    }
    
    private func deleteKYCData() async {
        kycLoadingText = "Deleting KYC data"
        isLoadingKyc = true
        kycInfo = nil
        kycFieldsError =  nil
        do {
            let sep12 = try await anchoredAsset.anchor.sep12(authToken: authToken)
            try await sep12.delete(account: authToken.account)
            await loadKYCData()
        } catch {
            kycFieldsError = "Could not delete your KYC data from anchor: \(error.localizedDescription)"
        }
        isLoadingKyc = false
    }
    
    private func submitKYCData() async {
        kycLoadingText = "Submitting KYC data"
        isLoadingKyc = true
        do {
            let sep12 = try await anchoredAsset.anchor.sep12(authToken: authToken)
            if let customerId = kycInfo?.id {
                // known anchor customer
                let _ = try await sep12.update(id: customerId, sep9Info: preparedKycData)
            } else {
                // new anchor customer
                let _ = try await sep12.add(sep9Info: preparedKycData)
            }
            try await Task.sleep(nanoseconds: 5_000_000_000) // wait 5 sec.
            await loadKYCData()
        } catch {
            kycFieldsError = "Could not submit your KYC data to the anchor: \(error.localizedDescription)"
        }
        isLoadingKyc = false
    }
    
    private var preparedKycData : [String:String] {
        var result:[String:String]  = [:]
        if let dinfo = kycInfo?.fields, !collectedKycDetails.isEmpty {
            for (index, key) in dinfo.keys.enumerated() {
                if (collectedKycDetails.count > index) {
                    let val = collectedKycDetails[index]
                    if !val.isEmpty && val != selectItem {
                        result[key] = collectedKycDetails[index]
                    }
                }
            }
        }
        return result
    }
    
    private var preparedTransferData : [String:String] {
        var result:[String:String]  = [:]
        if let winfo = withdrawInfo.types?.first?.value, !collectedTransferDetails.isEmpty {
            for (index, key) in winfo.keys.enumerated() {
                if (collectedTransferDetails.count > index) {
                    let val = collectedTransferDetails[index]
                    if !val.isEmpty && val != selectItem {
                        result[key] = collectedTransferDetails[index]
                    }
                }
            }
        }
        return result
    }
    
    private func loadFeeInfo() async {
        isLoadingFee = true
        fee = nil
        if let feeFixed = withdrawInfo.feeFixed {
            fee = feeFixed
        } else {
            guard let amount = Double(transferAmount) else {
                feeError = "Missing transfer amount"
                isLoadingFee = false
                return
            }
            if let feePercent = withdrawInfo.feePercent {
                fee = amount * feePercent / 100
            } else if anchorHasEnabledFeeEndpoint {
                do {
                    fee = try await anchoredAsset.anchor.sep6.fee(assetCode: anchoredAsset.code,
                                                                  amount: amount,
                                                                  operation: "withdraw",
                                                                  type: preparedTransferData["type"])
                } catch {
                    feeError = "Error loading fee from anchor: \(error.localizedDescription)"
                }
            }
        }
        isLoadingFee = false
    }
    
    private func submitTransfer() async {
        isSubmitting = true
        submissionError = nil
        submissionResponse = nil
        do {
            let destinationAsset = anchoredAsset.asset
            let sep6 = anchoredAsset.anchor.sep6
            let params = Sep6WithdrawParams(assetCode: destinationAsset.code, 
                                            type: withdrawInfo.types!.first!.key,
                                            account: authToken.account,
                                            amount: transferAmount,
                                            extraFields: preparedTransferData)
            
            submissionResponse = try await sep6.withdraw(params: params, authToken: authToken)
            
        } catch {
            submissionError = "Your request has been submitted to the Anchor but following error occurred: \(error.localizedDescription). Please close this window and try again."
        }
        isSubmitting = false
    }
}
