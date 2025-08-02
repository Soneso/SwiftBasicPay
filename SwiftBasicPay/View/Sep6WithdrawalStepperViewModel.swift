//
//  Sep6WithdrawalStepperViewModel.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 02.08.25.
//

import Foundation
import stellar_wallet_sdk

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
                    if val.choices != nil && !val.choices!.isEmpty {
                        self.collectedTransferDetails.append(selectItem)
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
                        transferFieldsError = "\(infoKey) is not optional"
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
        await MainActor.run {
            isSubmitting = true
            submissionError = nil
            submissionResponse = nil
        }
        
        guard let withdrawType = withdrawInfo.types?.first?.key else {
            await MainActor.run {
                submissionError = "No withdrawal type provided by the anchor!"
                isSubmitting = false
            }
            return
        }
        
        do {
            let destinationAsset = anchoredAsset.asset
            let sep6 = anchoredAsset.anchor.sep6
            let params = Sep6WithdrawParams(assetCode: destinationAsset.code,
                                            type: withdrawType,
                                            account: authToken.account,
                                            amount: transferAmount,
                                            extraFields: preparedTransferData)
            
            let response = try await sep6.withdraw(params: params, authToken: authToken)
            
            await MainActor.run {
                submissionResponse = response
            }
            
        } catch {
            await MainActor.run {
                submissionError = "Your request has been submitted to the Anchor but following error occurred: \(error.localizedDescription). Please close this window and try again."
            }
        }
        
        await MainActor.run {
            isSubmitting = false
        }
    }
}
