//
//  Sep6WithdrawalStepperViewModel.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 02.08.25.
//

import Foundation
import UIKit
import stellar_wallet_sdk
import Observation

@Observable
class Sep6WithdrawalStepperViewModel: Sep6StepperViewModel {
    
    private var withdrawInfo: Sep6WithdrawInfo {
        return transferInfo as! Sep6WithdrawInfo
    }
    
    init(anchoredAsset: AnchoredAssetInfo,
         withdrawInfo: Sep6WithdrawInfo,
         authToken: AuthToken,
         anchorHasEnabledFeeEndpoint: Bool,
         savedKycData: [KycEntry] = []) {
        super.init(anchoredAsset: anchoredAsset,
                   transferInfo: withdrawInfo,
                   authToken: authToken,
                   anchorHasEnabledFeeEndpoint: anchorHasEnabledFeeEndpoint,
                   savedKycData: savedKycData,
                   operationType: .withdraw)
        
        initializeTransferDetails()
    }
    
    private func initializeTransferDetails() {
        if let winfo = withdrawInfo.types?.first?.value {
            for key in winfo.keys {
                if let val = winfo[key] {
                    if let choices = val.choices, !choices.isEmpty {
                        // Auto-select the first choice for dropdown fields
                        self.collectedTransferDetails.append(choices[0])
                    } else {
                        self.collectedTransferDetails.append("")
                    }
                }
            }
        }
    }
    
    var transferFieldInfos: [TransferFieldInfo] {
        var info: [TransferFieldInfo] = []
        if let winfo = withdrawInfo.types?.first?.value {
            for key in winfo.keys {
                if let val = winfo[key] {
                    info.append(TransferFieldInfo(key: key, info: val))
                }
            }
        }
        return info
    }
    
    func indexForTransferFieldKey(key: String) -> Int {
        if let winfo = withdrawInfo.types?.first?.value {
            for (index, infoKey) in winfo.keys.enumerated() {
                if key == infoKey {
                    return index
                }
            }
        }
        return -1
    }
    
    override func validateSpecificTransferFields() -> Bool {
        if let winfo = withdrawInfo.types?.first?.value {
            for (index, infoKey) in winfo.keys.enumerated() {
                let field = winfo[infoKey]
                let optional = field?.optional ?? false
                if !optional {
                    let val = collectedTransferDetails[index]
                    if val.isEmpty || val == selectItem {
                        transferFieldsError = "\(infoKey) is required"
                        return false
                    }
                }
            }
        }
        return true
    }
    
    override var preparedTransferData: [String: String] {
        var result: [String: String] = [:]
        if let winfo = withdrawInfo.types?.first?.value, !collectedTransferDetails.isEmpty {
            for (index, key) in winfo.keys.enumerated() {
                if collectedTransferDetails.count > index {
                    let val = collectedTransferDetails[index]
                    if !val.isEmpty && val != selectItem {
                        result[key] = collectedTransferDetails[index]
                    }
                }
            }
        }
        return result
    }
    
    override func submitTransfer() async {
        isSubmitting = true
        submissionError = nil
        submissionResponse = nil
        
        guard let withdrawType = withdrawInfo.types?.first?.key else {
            submissionError = "No withdrawal type provided by the anchor!"
            isSubmitting = false
            return
        }
        
        do {
            let destinationAsset = anchoredAsset.asset
            let sep6 = anchoredAsset.anchor.sep6
            let params = Sep6WithdrawParams(
                assetCode: destinationAsset.code,
                type: withdrawType,
                account: authToken.account,
                amount: transferAmount,
                extraFields: preparedTransferData
            )
            
            let response = try await sep6.withdraw(params: params, authToken: authToken)
            
            submissionResponse = response
            
            // Success haptic feedback
            await MainActor.run {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            }
            
        } catch {
            submissionError = "Could not submit withdrawal request: \(error.localizedDescription)"
            
            // Error haptic feedback
            await MainActor.run {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
            }
        }
        
        isSubmitting = false
    }
}