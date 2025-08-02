//
//  Sep6StepperViews.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 02.08.25.
//

import SwiftUI
import stellar_wallet_sdk

struct Sep6AmountInputField: View {
    @Binding var transferAmount: String
    let minAmount: Double
    let maxAmount: Double?
    let assetCode: String
    
    var body: some View {
        let min = minAmount.toStringWithoutTrailingZeros
        let max = maxAmount != nil ? " max: \(maxAmount!.toStringWithoutTrailingZeros)" : ""

        return VStack {
            TextField("Enter amount", text: $transferAmount)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: transferAmount) { oldValue, value in
                    if value != "" && Double(value) == nil {
                        transferAmount = oldValue
                    }
                }
            
            Text("min: \(min) \(max)")
                .font(.subheadline)
                .font(.caption)
                .fontWeight(.light)
                .italic()
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct Sep6KycStatusView: View {
    let kycInfo: GetCustomerResponse
    let onDelete: () -> Void
    
    var body: some View {
        if kycInfo.sep12Status == Sep12Status.neesdInfo {
            Text("The anchor needs following of your KYC data:")
                .font(.subheadline)
        } else if kycInfo.sep12Status == Sep12Status.accepted {
            Text("Your KYC data has been accepted by the anchor.")
                .font(.subheadline)
            Button("Delete") {
                onDelete()
            }
        } else if kycInfo.sep12Status == Sep12Status.processing {
            Text("Your KYC data is currently being processed by the anchor.")
                .font(.subheadline)
        } else if kycInfo.sep12Status == Sep12Status.rejected {
            Text("Your KYC data has been rejected by the anchor.")
                .font(.subheadline)
        }
    }
}

struct Sep6KycFields: View {
    let kycFieldInfos: [KycFieldInfo]
    @Binding var collectedKycDetails: [String]
    let selectItem: String
    let indexForKycFieldKey: (String) -> Int
    
    var body: some View {
        VStack {
            if !collectedKycDetails.isEmpty {
                ScrollView {
                    ForEach(kycFieldInfos, id: \.key) { info in
                        if let choices = info.info.choices, !choices.isEmpty {
                            HStack {
                                Text("\(info.key):")
                                    .font(.subheadline)
                                    .fontWeight(.light)
                                Picker("select \(info.key)", selection: $collectedKycDetails[indexForKycFieldKey(info.key)]) {
                                    Text(selectItem)
                                        .italic()
                                        .foregroundColor(.black)
                                        .tag(selectItem)
                                    ForEach(choices, id: \.self) { choice in
                                        Text(choice)
                                            .italic()
                                            .foregroundColor(.black)
                                            .tag(choice)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            TextField("\(info.key)", text: $collectedKycDetails[indexForKycFieldKey(info.key)])
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        let optional = info.optional ? "(optional)" : "*"
                        Text("\(optional) \(info.info.description ?? "")")
                            .font(.caption)
                            .fontWeight(.light)
                            .italic()
                            .foregroundColor(info.optional ? .secondary : .orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 20)
                    }
                }
            }
        }
    }
}

struct Sep6TransferFields: View {
    let transferFieldInfos: [TransferFieldInfo]
    @Binding var collectedTransferDetails: [String]
    let selectItem: String
    let indexForTransferFieldKey: (String) -> Int
    
    var body: some View {
        VStack {
            if !collectedTransferDetails.isEmpty {
                ScrollView {
                    ForEach(transferFieldInfos, id: \.key) { info in
                        if let choices = info.info.choices, !choices.isEmpty {
                            HStack {
                                Text("\(info.key):")
                                    .font(.subheadline)
                                    .fontWeight(.light)
                                Picker("select \(info.key)", selection: $collectedTransferDetails[indexForTransferFieldKey(info.key)]) {
                                    Text(selectItem)
                                        .italic()
                                        .foregroundColor(.black)
                                        .tag(selectItem)
                                    ForEach(choices, id: \.self) { choice in
                                        Text(choice)
                                            .italic()
                                            .foregroundColor(.black)
                                            .tag(choice)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            TextField("\(info.key)", text: $collectedTransferDetails[indexForTransferFieldKey(info.key)])
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        let optional = info.optional ? "(optional)" : "*"
                        Text("\(optional) \(info.info.description ?? "")")
                            .font(.subheadline)
                            .font(.caption)
                            .fontWeight(.light)
                            .italic()
                            .foregroundColor(info.optional ? .secondary : .orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Spacer(minLength: 10)
                    }
                }
            }
        }
    }
}

struct Sep6FeeView: View {
    let isLoadingFee: Bool
    let fee: Double?
    let feeError: String?
    let assetCode: String
    
    var body: some View {
        if isLoadingFee {
            Utils.progressViewWithLabel("Loading fee data")
        } else {
            if let anchorFee = fee {
                let feeStr = anchorFee.toStringWithoutTrailingZeros
                Text("The Anchor will charge a fee of \(feeStr) \(assetCode).")
                    .padding(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("The Anchor provides no fee info for the asset \(assetCode).")
                    .padding(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error = feeError {
                Utils.divider
                Text("\(error)")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct Sep6SummaryView: View {
    let isSubmitting: Bool
    let submissionResponse: Sep6TransferResponse?
    let transferAmount: String
    let fee: Double?
    let submissionError: String?
    let assetCode: String
    let operationName: String
    
    var body: some View {
        if isSubmitting {
            Utils.progressViewWithLabel("Submitting data to anchor")
        } else if let response = submissionResponse {
            Sep6TransferResponseView(response: response)
        } else {
            let amountStr = transferAmount.amountWithoutTrailingZeros
            Text("\(operationName): \(amountStr) \(assetCode)")
                .padding(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let anchorFee = fee {
                let feeStr = anchorFee.toStringWithoutTrailingZeros
                Text("Fee: \(feeStr) \(assetCode).")
                    .padding(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Fee: unknown")
                    .padding(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let error = submissionError {
                Utils.divider
                Text("\(error)")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct Sep6NavigationButtons: View {
    let currentStep: Int
    let submissionResponse: Sep6TransferResponse?
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSubmit: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            if submissionResponse == nil {
                Button("Previous") {
                    onPrevious()
                }
                .disabled(currentStep == 1)
            }

            Spacer()

            if currentStep < 4 {
                Button("Next") {
                    onNext()
                }
            } else {
                if submissionResponse == nil {
                    Button("Submit") {
                        onSubmit()
                    }
                } else {
                    Button("Close") {
                        onClose()
                    }
                }
            }
        }
        .padding(.trailing)
    }
}