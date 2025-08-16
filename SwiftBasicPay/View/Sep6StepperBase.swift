//
//  Sep6StepperBase.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 02.08.25.
//

import SwiftUI
import UIKit
import stellar_wallet_sdk
import Observation

// MARK: - Step State Machine

enum Sep6StepState: Int, CaseIterable {
    case transferDetails = 1
    case kycData = 2
    case fee = 3
    case summary = 4
    
    var title: String {
        switch self {
        case .transferDetails: return "Transfer Details"
        case .kycData: return "KYC Data"
        case .fee: return "Fee"
        case .summary: return "Summary"
        }
    }
    
    var canGoBack: Bool {
        return self != .transferDetails
    }
    
    var canGoForward: Bool {
        return self != .summary
    }
    
    func next() -> Sep6StepState? {
        guard let nextRawValue = Sep6StepState(rawValue: self.rawValue + 1) else { return nil }
        return nextRawValue
    }
    
    func previous() -> Sep6StepState? {
        guard let previousRawValue = Sep6StepState(rawValue: self.rawValue - 1) else { return nil }
        return previousRawValue
    }
}

// MARK: - Operation Type

enum Sep6OperationType {
    case deposit
    case withdraw
    
    var displayName: String {
        switch self {
        case .deposit: return "Deposit"
        case .withdraw: return "Withdraw"
        }
    }
    
    var displayNameLowercase: String {
        displayName.lowercased()
    }
}

// MARK: - Transfer Info Protocol

protocol Sep6TransferInfo {
    var minAmount: Double? { get }
    var maxAmount: Double? { get }
    var feeFixed: Double? { get }
    var feePercent: Double? { get }
}

extension Sep6DepositInfo: Sep6TransferInfo {}
extension Sep6WithdrawInfo: Sep6TransferInfo {}

// MARK: - Base View Model

@Observable
class Sep6StepperViewModel {
    // State machine
    var currentStep: Sep6StepState = .transferDetails
    var stepHistory: [Sep6StepState] = [.transferDetails]
    
    // Transfer details
    var collectedTransferDetails: [String] = []
    var transferAmount: String = ""
    var transferFieldsError: String?
    
    // KYC state
    var isLoadingKyc = false
    var kycLoadingText: String = ""
    var kycInfo: GetCustomerResponse?
    var kycFieldsError: String?
    var collectedKycDetails: [String] = []
    
    // Fee state
    var isLoadingFee = false
    var feeError: String?
    var fee: Double?
    
    // Submission state
    var isSubmitting = false
    var submissionError: String?
    var submissionResponse: Sep6TransferResponse?
    
    // Core properties
    let anchoredAsset: AnchoredAssetInfo
    let transferInfo: Sep6TransferInfo
    let authToken: AuthToken
    let anchorHasEnabledFeeEndpoint: Bool
    let selectItem = "select"
    let savedKycData: [KycEntry]
    let operationType: Sep6OperationType
    
    // Computed properties
    var minAmount: Double { transferInfo.minAmount ?? 0 }
    var maxAmount: Double? { transferInfo.maxAmount }
    
    var operationName: String { operationType.displayName }
    var operationNameLowercase: String { operationType.displayNameLowercase }
    
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
    
    // MARK: - Navigation
    
    func goToNextStep() {
        if let nextStep = currentStep.next() {
            stepHistory.append(nextStep)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentStep = nextStep
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    func goToPreviousStep() {
        if currentStep.canGoBack, let previousStep = currentStep.previous() {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                currentStep = previousStep
            }
            
            // Remove from history if going back
            if stepHistory.last == currentStep.next() {
                stepHistory.removeLast()
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    // MARK: - KYC Operations
    
    func loadKYCData() async {
        kycLoadingText = "Loading KYC data"
        isLoadingKyc = true
        kycInfo = nil
        kycFieldsError = nil
        
        do {
            let sep12 = try await anchoredAsset.anchor.sep12(authToken: authToken)
            let kycResponse = try await sep12.getByAuthTokenOnly()
            
            kycInfo = kycResponse
            collectedKycDetails = []
            
            if let dinfo = kycResponse.fields {
                var newKycDetails: [String] = []
                for key in dinfo.keys {
                    if let val = dinfo[key] {
                        if val.optional == true {
                            continue
                        }
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
        } catch {
            kycFieldsError = "Could not load SEP-12 (KYC) info from anchor: \(error.localizedDescription)"
        }
        
        isLoadingKyc = false
    }
    
    func deleteKYCData() async {
        kycLoadingText = "Deleting KYC data"
        isLoadingKyc = true
        kycInfo = nil
        kycFieldsError = nil
        
        do {
            let sep12 = try await anchoredAsset.anchor.sep12(authToken: authToken)
            try await sep12.delete(account: authToken.account)
            await loadKYCData()
        } catch {
            kycFieldsError = "Could not delete your KYC data from anchor: \(error.localizedDescription)"
            isLoadingKyc = false
        }
    }
    
    func submitKYCData() async {
        kycLoadingText = "Submitting KYC data"
        isLoadingKyc = true
        
        do {
            let sep12 = try await anchoredAsset.anchor.sep12(authToken: authToken)
            if let customerId = kycInfo?.id {
                let _ = try await sep12.update(id: customerId, sep9Info: preparedKycData)
            } else {
                let _ = try await sep12.add(sep9Info: preparedKycData)
            }
            
            // Small delay to ensure server processing
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await loadKYCData()
            
            // Success feedback
            await MainActor.run {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            }
        } catch {
            kycFieldsError = "Could not submit your KYC data to the anchor: \(error.localizedDescription)"
            isLoadingKyc = false
            
            // Error feedback
            await MainActor.run {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
            }
        }
    }
    
    // MARK: - Fee Operations
    
    func loadFeeInfo() async {
        isLoadingFee = true
        fee = nil
        feeError = nil
        
        if let feeFixed = transferInfo.feeFixed {
            fee = feeFixed
        } else {
            guard let amount = Double(transferAmount) else {
                feeError = "Missing transfer amount"
                isLoadingFee = false
                return
            }
            
            if let feePercent = transferInfo.feePercent {
                fee = amount * feePercent / 100
            } else if anchorHasEnabledFeeEndpoint {
                do {
                    let calculatedFee = try await anchoredAsset.anchor.sep6.fee(
                        assetCode: anchoredAsset.code,
                        amount: amount,
                        operation: operationNameLowercase,
                        type: preparedTransferData["type"]
                    )
                    fee = calculatedFee
                } catch {
                    feeError = "Error loading fee from anchor: \(error.localizedDescription)"
                }
            }
        }
        
        isLoadingFee = false
    }
    
    // MARK: - Validation
    
    func validateTransferFields() -> Bool {
        transferFieldsError = nil
        
        if transferAmount.isEmpty {
            transferFieldsError = "Amount is required"
            return false
        }
        
        guard let amount = Double(transferAmount) else {
            transferFieldsError = "Invalid amount"
            return false
        }
        
        if amount < minAmount {
            transferFieldsError = "Amount is below minimum (\(minAmount.toStringWithoutTrailingZeros))"
            return false
        }
        
        if let maxAmount = maxAmount, amount > maxAmount {
            transferFieldsError = "Amount exceeds maximum (\(maxAmount.toStringWithoutTrailingZeros))"
            return false
        }
        
        return validateSpecificTransferFields()
    }
    
    func validateKycFields() -> Bool {
        kycFieldsError = nil
        for (index, field) in kycFieldInfos.enumerated() {
            if !field.optional {
                let val = collectedKycDetails[index]
                if val.isEmpty || val == selectItem {
                    kycFieldsError = "\(field.key) is required"
                    return false
                }
            }
        }
        return true
    }
    
    // MARK: - Data Preparation
    
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
    
    var kycFieldInfos: [KycFieldInfo] {
        var info: [KycFieldInfo] = []
        if let dinfo = kycInfo?.fields {
            for key in dinfo.keys {
                if let val = dinfo[key] {
                    // Show only required fields
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
    
    // MARK: - Abstract Methods (to be overridden)
    
    func validateSpecificTransferFields() -> Bool {
        fatalError("Must be implemented by subclass")
    }
    
    var preparedTransferData: [String: String] {
        fatalError("Must be implemented by subclass")
    }
    
    func submitTransfer() async {
        fatalError("Must be implemented by subclass")
    }
}