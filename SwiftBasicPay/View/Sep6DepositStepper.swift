import SwiftUI
import stellar_wallet_sdk

struct Sep6DepositStepper: View {

    private let anchoredAsset:AnchoredAssetInfo
    private let depositInfo:Sep6DepositInfo
    private let authToken:AuthToken
    private let stepTitles = ["Transfer details", "KYC Data", "Fee", "Summary"]
    private let selectItem = "select"
    
    internal init(anchoredAsset: AnchoredAssetInfo, depositInfo: Sep6DepositInfo, authToken: AuthToken) {
        self.anchoredAsset = anchoredAsset
        self.depositInfo = depositInfo
        self.authToken = authToken
    }
    
    @Environment(\.dismiss) private var dismiss // Environment property for dismissing the sheet
    
    @State private var currentStep = 1
    @State private var anchorHasEnabledFeeEndpoint = false
    @State private var collectedTransferDetails:[String] = []
    @State private var transferAmount:String = ""
    @State private var transferFieldsError:String? = nil
    @State private var isLoadingKyc = false
    @State private var kycLoadingText:String = ""
    @State private var kycInfo:GetCustomerResponse? = nil
    @State private var kycFieldsError:String? = nil
    @State private var collectedKycDetails:[String] = []

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
                        HStack {
                            Utils.progressView
                            Text(kycLoadingText).padding(.leading).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    else if let info = kycInfo, !isLoadingKyc {
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
                    Text("Fee")
                } else if currentStep == 4 {
                    Text("Summary")
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
            if let dinfo = depositInfo.fieldsInfo {
                for key in dinfo.keys {
                    if let val = dinfo[key] {
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
            Button("Previous") {
                if currentStep > 1 {
                    currentStep -= 1
                }
            }
            .disabled(currentStep == 1)

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
                        }
                    }
                    else if currentStep > 2 && currentStep < 4 {
                        currentStep += 1
                    }
                }
            } else {
                Button("Submit") {
                    // Handle submission logic here
                }
            }
        }
        .padding(.trailing)
    }
    
    private var amountInputField: some View  {
        let min = Utils.removeTrailingZerosFormAmount(amount: String(minAmount))
        let max = maxAmount != nil ? " max: \(Utils.removeTrailingZerosFormAmount(amount: String(maxAmount!)))" : ""

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
        return depositInfo.minAmount ?? 0
    }
    
    private var maxAmount : Double? {
        return depositInfo.maxAmount
    }
    
    var transferFieldInfos: [TransferFieldInfo] {
        var info:[TransferFieldInfo] = []
        if let dinfo = depositInfo.fieldsInfo {
            for key in dinfo.keys {
                if let val = dinfo[key] {
                    info.append(TransferFieldInfo(key: key, info: val))
                }
            }
        }
        return info
    }
        
    private func indexForTransferFieldKey(key:String) -> Int {
        if let dinfo = depositInfo.fieldsInfo {
            for (index, infoKey) in dinfo.keys.enumerated() {
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
        
        if let dinfo = depositInfo.fieldsInfo {
            for (index, infoKey) in dinfo.keys.enumerated() {
                let field = dinfo[infoKey]
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
                            self.collectedKycDetails.append("")
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
                    result[key] = collectedKycDetails[index]
                }
            }
        }
        return result
    }
}

/*struct Sep6DepositStepper_Previews: PreviewProvider {
    static var previews: some View {
        Sep6DepositStepper()
    }
}*/

public class TransferFieldInfo: Hashable, Identifiable {
    let key:String
    let info:Sep6FieldInfo
    
    internal init(key: String, info: Sep6FieldInfo) {
        self.key = key
        self.info = info
    }
    
    public var optional : Bool {
        return info.optional ?? false
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
    
    public static func == (lhs: TransferFieldInfo, rhs: TransferFieldInfo) -> Bool {
        lhs.key == rhs.key
    }
}

public class KycFieldInfo: Hashable, Identifiable {
    let key:String
    let info:Field
    
    internal init(key: String, info: Field) {
        self.key = key
        self.info = info
    }
    
    public var optional : Bool {
        return info.optional ?? false
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
    
    public static func == (lhs: KycFieldInfo, rhs: KycFieldInfo) -> Bool {
        lhs.key == rhs.key
    }
}
