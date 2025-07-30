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
    @State private var transferFieldsValidationError:String? = nil

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
                    if let error = transferFieldsValidationError {
                        Utils.divider
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                } else if currentStep == 2 {
                    Text("KYC")
                } else if currentStep == 3 {
                    Text("Fee")
                } else if currentStep == 4 {
                    Text("Summary")
                }
                Utils.divider
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
                            if currentStep == 1 {
                                if validateTransferFields() {
                                    currentStep += 1
                                }
                            }
                            else if currentStep < 4 {
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
                        if val.choices != nil {
                            self.collectedTransferDetails.append(selectItem)
                        } else {
                            self.collectedTransferDetails.append("")
                        }
                    }
                }
            }
        })
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
                .foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var minAmount : Double {
        return depositInfo.minAmount ?? 0
    }
    
    private var maxAmount : Double? {
        return depositInfo.maxAmount
    }
    
    var fieldInfos: [TransferFieldInfo] {
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
                ForEach(fieldInfos, id: \.key) { info in
                    let optional = info.optional ? "(optional)" : ""
                    if let choices = info.info.choices {
                        HStack {
                            Text("\(info.key) \(optional):")
                            Picker("select \(info.key)", selection: $collectedTransferDetails[indexForTransferFieldKey(key: info.key)]) {
                                Text(selectItem).italic().foregroundColor(.black).tag(selectItem)
                                ForEach(choices, id: \.self) { choice in
                                    Text(choice).italic().foregroundColor(.black).tag(choice)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            
                        }
                    } else {
                        TextField("Enter \(info.key) \(optional)", text: $collectedTransferDetails[indexForTransferFieldKey(key: info.key)])
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    if let description = info.info.description {
                        Text(description).font(.subheadline).font(.caption)
                            .fontWeight(.light).italic()
                            .foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
    
    private func validateTransferFields() -> Bool {
        transferFieldsValidationError = nil
        if transferAmount.isEmpty {
            transferFieldsValidationError = "Amount is not optional"
            return false
        }
        guard let amount = Double(transferAmount) else {
            transferFieldsValidationError = "Invalid amount"
            return false
        }
        if let maxAmount = maxAmount, amount > maxAmount {
            transferFieldsValidationError = "Amount is to high."
            return false
        }
        
        if let dinfo = depositInfo.fieldsInfo {
            for (index, infoKey) in dinfo.keys.enumerated() {
                let field = dinfo[infoKey]
                let optional = field?.optional ?? false
                if !optional {
                    let val = collectedTransferDetails[index]
                    if val.isEmpty || val == selectItem {
                        transferFieldsValidationError = "\(infoKey) is not optional"
                        return false
                    }
                }
            }
        }
        
        return true
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
