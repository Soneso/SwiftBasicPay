//
//  Sep12KycFormSheet.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 03.08.25.
//

import SwiftUI
import stellar_wallet_sdk

struct Sep12KycFormSheet: View {
    let customerId: String?
    let requiredFields: [String: Field]
    let savedKycData: [KycEntry]
    let txId: String
    let onSubmit: (String?, [String: String], String) async -> Void
    @Binding var isPresented: Bool
    
    @State private var collectedKycDetails: [String] = []
    @State private var kycFieldsError: String?
    @State private var isSubmitting = false
    
    private let selectItem = "select"
    
    var kycFieldInfos: [KycFieldInfo] {
        var info: [KycFieldInfo] = []
        for key in requiredFields.keys.sorted() {
            if let field = requiredFields[key] {
                info.append(KycFieldInfo(key: key, info: field))
            }
        }
        return info
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isSubmitting {
                    Utils.progressViewWithLabel("Submitting KYC data")
                } else {
                    Text("Please provide the required KYC information:")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(kycFieldInfos, id: \.key) { info in
                                VStack(alignment: .leading, spacing: 5) {
                                    if let choices = info.info.choices, !choices.isEmpty {
                                        HStack {
                                            Text("\(info.key):")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Picker("Select \(info.key)", selection: $collectedKycDetails[indexForKycFieldKey(info.key)]) {
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
                                        Text("\(info.key):")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        TextField("Enter \(info.key)", text: $collectedKycDetails[indexForKycFieldKey(info.key)])
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                    
                                    let optional = info.optional ? "(optional)" : "*required"
                                    Text("\(optional) \(info.info.description ?? "")")
                                        .font(.caption)
                                        .fontWeight(.light)
                                        .italic()
                                        .foregroundColor(info.optional ? .secondary : .orange)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if let error = kycFieldsError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            .navigationTitle("KYC Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        Task {
                            await submitKycData()
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
        .onAppear {
            initializeKycDetails()
        }
    }
    
    private func indexForKycFieldKey(_ key: String) -> Int {
        for (index, info) in kycFieldInfos.enumerated() {
            if key == info.key {
                return index
            }
        }
        return -1
    }
    
    private func initializeKycDetails() {
        collectedKycDetails = []
        for info in kycFieldInfos {
            if let choices = info.info.choices, !choices.isEmpty {
                collectedKycDetails.append(selectItem)
            } else {
                var value = ""
                if let saved = savedKycData.filter({ $0.id == info.key }).first {
                    value = saved.val
                }
                collectedKycDetails.append(value)
            }
        }
    }
    
    private func validateKycFields() -> Bool {
        kycFieldsError = nil
        for (index, info) in kycFieldInfos.enumerated() {
            if !info.optional {
                let val = collectedKycDetails[index]
                if val.isEmpty || val == selectItem {
                    kycFieldsError = "\(info.key) is required"
                    return false
                }
            }
        }
        return true
    }
    
    private var preparedKycData: [String: String] {
        var result: [String: String] = [:]
        for (index, info) in kycFieldInfos.enumerated() {
            if collectedKycDetails.count > index {
                let val = collectedKycDetails[index]
                if !val.isEmpty && val != selectItem {
                    result[info.key] = val
                }
            }
        }
        return result
    }
    
    private func submitKycData() async {
        guard validateKycFields() else { return }
        
        await MainActor.run {
            isSubmitting = true
        }
        
        let kycData = preparedKycData
        await onSubmit(customerId, kycData, txId)
        
        await MainActor.run {
            isSubmitting = false
            isPresented = false
        }
    }
}
