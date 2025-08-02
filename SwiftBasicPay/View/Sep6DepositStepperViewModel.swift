//
//  Sep6DepositStepperViewModel.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 02.08.25.
//

import Foundation
import stellar_wallet_sdk

class Sep6DepositStepperViewModel: Sep6StepperViewModel {
    
    private var depositInfo: Sep6DepositInfo {
        return transferInfo as! Sep6DepositInfo
    }
    
    init(anchoredAsset: AnchoredAssetInfo,
         depositInfo: Sep6DepositInfo,
         authToken: AuthToken,
         anchorHasEnabledFeeEndpoint: Bool,
         savedKycData: [KycEntry] = []) {
        super.init(anchoredAsset: anchoredAsset,
                   transferInfo: depositInfo,
                   authToken: authToken,
                   anchorHasEnabledFeeEndpoint: anchorHasEnabledFeeEndpoint,
                   savedKycData: savedKycData,
                   operationType: .deposit)
        
        initializeTransferDetails()
    }
    
    private func initializeTransferDetails() {
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
    }
    
    var transferFieldInfos: [TransferFieldInfo] {
        var info: [TransferFieldInfo] = []
        if let dinfo = depositInfo.fieldsInfo {
            for key in dinfo.keys {
                if let val = dinfo[key] {
                    info.append(TransferFieldInfo(key: key, info: val))
                }
            }
        }
        return info
    }
    
    func indexForTransferFieldKey(key: String) -> Int {
        if let dinfo = depositInfo.fieldsInfo {
            for (index, infoKey) in dinfo.keys.enumerated() {
                if key == infoKey {
                    return index
                }
            }
        }
        return -1
    }
    
    override func validateSpecificTransferFields() -> Bool {
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
    
    override var preparedTransferData: [String: String] {
        var result: [String: String] = [:]
        if let dinfo = depositInfo.fieldsInfo, !collectedTransferDetails.isEmpty {
            for (index, key) in dinfo.keys.enumerated() {
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
        
        do {
            let destinationAsset = anchoredAsset.asset
            let sep6 = anchoredAsset.anchor.sep6
            let params = Sep6DepositParams(assetCode: destinationAsset.code,
                                           account: authToken.account,
                                           amount: transferAmount,
                                           extraFields: preparedTransferData)
            
            let response = try await sep6.deposit(params: params, authToken: authToken)
            
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
