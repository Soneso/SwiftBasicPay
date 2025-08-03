//
//  Sep6StepperBase.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 02.08.25.
//

import SwiftUI
import stellar_wallet_sdk

enum Sep6OperationType {
    case deposit
    case withdraw
}

protocol Sep6TransferInfo {
    var minAmount: Double? { get }
    var maxAmount: Double? { get }
    var feeFixed: Double? { get }
    var feePercent: Double? { get }
}

extension Sep6DepositInfo: Sep6TransferInfo {}
extension Sep6WithdrawInfo: Sep6TransferInfo {}

class Sep6StepperViewModel: ObservableObject {
    @Published var currentStep = 1
    @Published var collectedTransferDetails: [String] = []
    @Published var transferAmount: String = ""
    @Published var transferFieldsError: String?
    @Published var isLoadingKyc = false
    @Published var kycLoadingText: String = ""
    @Published var kycInfo: GetCustomerResponse?
    @Published var kycFieldsError: String?
    @Published var collectedKycDetails: [String] = []
    @Published var isLoadingFee = false
    @Published var feeError: String?
    @Published var fee: Double?
    @Published var isSubmitting = false
    @Published var submissionError: String?
    @Published var submissionResponse: Sep6TransferResponse?
    
    let anchoredAsset: AnchoredAssetInfo
    let transferInfo: Sep6TransferInfo
    let authToken: AuthToken
    let anchorHasEnabledFeeEndpoint: Bool
    let selectItem = "select"
    let savedKycData: [KycEntry]
    let operationType: Sep6OperationType
    
    init(anchoredAsset: AnchoredAssetInfo,
         transferInfo: Sep6TransferInfo,
         authToken: AuthToken,
         anchorHasEnabledFeeEndpoint: Bool,
         savedKycData: [KycEntry] = [],
         operationType: Sep6OperationType) {
        
        self.anchoredAsset = anchoredAsset
        self.transferInfo = transferInfo
        self.authToken = authToken
        self.anchorHasEnabledFeeEndpoint = anchorHasEnabledFeeEndpoint
        self.savedKycData = savedKycData
        self.operationType = operationType
    }
    
    var minAmount: Double {
        return transferInfo.minAmount ?? 0
    }
    
    var maxAmount: Double? {
        return transferInfo.maxAmount
    }
    
    var stepTitles: [String] {
        return ["Transfer details", "KYC Data", "Fee", "Summary"]
    }
    
    var operationName: String {
        return operationType == .deposit ? "Deposit" : "Withdraw"
    }
    
    var operationNameLowercase: String {
        return operationType == .deposit ? "deposit" : "withdraw"
    }
    
    func loadKYCData() async {
        await MainActor.run {
            kycLoadingText = "Loading KYC data"
            isLoadingKyc = true
            kycInfo = nil
            kycFieldsError = nil
        }
        
        do {
            let sep12 = try await anchoredAsset.anchor.sep12(authToken: authToken)
            let kycResponse = try await sep12.getByAuthTokenOnly()
            
            await MainActor.run {
                kycInfo = kycResponse
                collectedKycDetails = []
            }
            
            if let dinfo = kycResponse.fields {
                await MainActor.run {
                    var newKycDetails: [String] = []
                    for key in dinfo.keys {
                        if let val = dinfo[key] {
                            if val.optional == true {
                                continue
                            }
                            //print("p: \(key)")
                            if val.choices != nil && !val.choices!.isEmpty {
                                newKycDetails.append(selectItem)
                            } else {
                                var value = ""
                                if let saved = savedKycData.filter({$0.id == key}).first {
                                    value = saved.val
                                }
                                newKycDetails.append(value)
                            }
                        }
                    }
                    collectedKycDetails = newKycDetails
                }
            }
        } catch {
            await MainActor.run {
                kycFieldsError = "Could not load SEP-12 (KYC) info from anchor: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isLoadingKyc = false
        }
    }
    
    func deleteKYCData() async {
        await MainActor.run {
            kycLoadingText = "Deleting KYC data"
            isLoadingKyc = true
            kycInfo = nil
            kycFieldsError = nil
        }
        
        do {
            let sep12 = try await anchoredAsset.anchor.sep12(authToken: authToken)
            try await sep12.delete(account: authToken.account)
            await loadKYCData()
        } catch {
            await MainActor.run {
                kycFieldsError = "Could not delete your KYC data from anchor: \(error.localizedDescription)"
                isLoadingKyc = false
            }
        }
    }
    
    func submitKYCData() async {
        await MainActor.run {
            kycLoadingText = "Submitting KYC data"
            isLoadingKyc = true
        }
        
        do {
            let sep12 = try await anchoredAsset.anchor.sep12(authToken: authToken)
            if let customerId = kycInfo?.id {
                let _ = try await sep12.update(id: customerId, sep9Info: preparedKycData)
            } else {
                let _ = try await sep12.add(sep9Info: preparedKycData)
            }
            try await Task.sleep(nanoseconds: 5_000_000_000)
            await loadKYCData()
        } catch {
            await MainActor.run {
                kycFieldsError = "Could not submit your KYC data to the anchor: \(error.localizedDescription)"
                isLoadingKyc = false
            }
        }
    }
    
    var preparedKycData: [String: String] {
        var result: [String: String] = [:]
        if !collectedKycDetails.isEmpty {
            for (index, field) in kycFieldInfos.enumerated() {
                if collectedKycDetails.count > index {
                    let val = collectedKycDetails[index]
                    if !val.isEmpty && val != selectItem {
                        result[field.key] = collectedKycDetails[index]
                    }
                }
            }
        }
        return result
    }
    
    func validateTransferFields() -> Bool {
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
        
        return validateSpecificTransferFields()
    }
    
    func validateSpecificTransferFields() -> Bool {
        fatalError("Must be implemented by subclass")
    }
    
    func validateKycFields() -> Bool {
        kycFieldsError = nil
        for (index, field) in kycFieldInfos.enumerated() {
            if !field.optional {
                let val = collectedKycDetails[index]
                if val.isEmpty || val == selectItem {
                    kycFieldsError = "\(field.key) is not optional"
                    return false
                }
            }
        }
        return true
    }
    
    func loadFeeInfo() async {
        await MainActor.run {
            isLoadingFee = true
            fee = nil
            feeError = nil
        }
        
        if let feeFixed = transferInfo.feeFixed {
            await MainActor.run {
                fee = feeFixed
            }
        } else {
            guard let amount = Double(transferAmount) else {
                await MainActor.run {
                    feeError = "Missing transfer amount"
                    isLoadingFee = false
                }
                return
            }
            
            if let feePercent = transferInfo.feePercent {
                await MainActor.run {
                    fee = amount * feePercent / 100
                }
            } else if anchorHasEnabledFeeEndpoint {
                do {
                    let calculatedFee = try await anchoredAsset.anchor.sep6.fee(assetCode: anchoredAsset.code,
                                                                                amount: amount,
                                                                                operation: operationNameLowercase,
                                                                                type: preparedTransferData["type"])
                    await MainActor.run {
                        fee = calculatedFee
                    }
                } catch {
                    await MainActor.run {
                        feeError = "Error loading fee from anchor: \(error.localizedDescription)"
                    }
                }
            }
        }
        
        await MainActor.run {
            isLoadingFee = false
        }
    }
    
    var preparedTransferData: [String: String] {
        fatalError("Must be implemented by subclass")
    }
    
    func submitTransfer() async {
        fatalError("Must be implemented by subclass")
    }
    
    var kycFieldInfos: [KycFieldInfo] {
        var info: [KycFieldInfo] = []
        if let dinfo = kycInfo?.fields {
            for key in dinfo.keys {
                if let val = dinfo[key] {
                    // show only required fields
                    if !(val.optional ?? false) {
                        info.append(KycFieldInfo(key: key, info: val))
                    }
                }
            }
        }
        return info
    }
    
    func indexForKycFieldKey(key: String) -> Int {
        for (index, infoKey) in kycFieldInfos.enumerated() {
            if key == infoKey.key {
                return index
            }
        }
        return -1
    }
}
