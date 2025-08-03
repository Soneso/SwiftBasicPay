//
//  Sep6TransferResponseView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 31.07.25.
//

import SwiftUI
import stellar_wallet_sdk

struct Sep6TransferResponseView: View {

    
    private let response:Sep6TransferResponse
    
    internal init(response: Sep6TransferResponse) {
        self.response = response
    }
    
    @State private var depositInstructions:[DepositInstruction] = []
    @State private var showToast = false
    @State private var toastMessage:String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            switch response {
            case .missingKYC(let fields):
                missingKYCView(fields: fields)
            case .pending(let status, let moreInfoUrl, let eta):
                pendingInfoView(status: status, moreInfoUrl: moreInfoUrl, eta: eta)
            case .withdrawSuccess(let accountId, let memoType, let memo, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo):
                withdrawalSuccess(accountId: accountId, memoType: memoType, memo: memo, id: id, eta: eta, minAmount: minAmount, maxAmount: maxAmount, feeFixed: feeFixed, feePercent: feePercent, extraInfo: extraInfo)
            case .depositSuccess(let how, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo, let instructions):
                depositSuccess(how: how, id: id, eta: eta, minAmount: minAmount, maxAmount: maxAmount, feeFixed: feeFixed, feePercent: feePercent, extraInfo: extraInfo, instructions: instructions)
            }
        }
    }
    
    private func missingKYCView(fields:[String]) -> some View {
        return VStack {
            Text("We have submitted your transfer to the anchor, but the anchor needs more KYC data from you.").font(.subheadline)
            if !fields.isEmpty {
                Text("Required fields: \(fields)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func pendingInfoView(status:String, moreInfoUrl:String?, eta:Int?) -> some View {
        return VStack {
            Text("We have submitted your transfer to the anchor, and the anchor responded with the status: pending").font(.subheadline)
            if let eta = eta {
                Text("Eta: \(eta)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let moreInfoUrl = moreInfoUrl {
                Text("More info URL: \(moreInfoUrl)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func depositSuccess(how:String?, id:String?, eta:Int?, minAmount:Double?, maxAmount:Double?, feeFixed:Double?, feePercent:Double?, extraInfo:Sep6ExtraInfo?, instructions:[String:Sep6DepositInstruction]?) -> some View {
        if let instructions = instructions {
            for key in instructions.keys {
                depositInstructions.append(DepositInstruction(key: key,
                                                              value: instructions[key]!.value,
                                                              description: instructions[key]!.description))
            }
        }
        return VStack {
            Text("You may not be finished yet. We have submitted your transfer to the anchor, but you may need to provide additional data. Switch to the transaction history section to check the current transaction status.").font(.subheadline)
            Utils.divider
            if id != nil || how != nil || eta != nil || !depositInstructions.isEmpty {
                Text("Info provided by the anchor: ").font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let id = id {
                Text("Transfer id: \(id)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.top)
            }
            if let how = how {
                Text("How: \(how)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.top)
            }
            if let eta = eta {
                Text("Eta: \(eta)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.top)
            }
            if !depositInstructions.isEmpty {
                ForEach($depositInstructions, id: \.key) { info in
                    Text("\(info.key) Instructions").font(.subheadline).font(.caption).padding(.top)
                        .fontWeight(.light).italic()
                        .foregroundColor(.secondary ).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Value: \(info.value)").font(.subheadline).font(.caption)
                        .fontWeight(.light).italic()
                        .foregroundColor(.secondary ).frame(maxWidth: .infinity, alignment: .leading)
                    Text("Desc: \(info.description)").font(.subheadline).font(.caption)
                        .fontWeight(.light).italic()
                        .foregroundColor(.secondary ).frame(maxWidth: .infinity, alignment: .leading)
                    Utils.divider
                }
            }
            if let extraInfo = extraInfo?.message {
                Text("Extra info: \(extraInfo)").font(.subheadline)
            }
        }
    }
    
    private func withdrawalSuccess(accountId:String?, memoType:String?, memo:String?, id:String?, eta:Int?, minAmount:Double?, maxAmount:Double?, feeFixed:Double?, feePercent:Double?, extraInfo:Sep6ExtraInfo?) -> some View {
        return VStack {
            Text("You may not be finished yet. We have submitted your transfer to the anchor, but you may need to provide additional data. Switch to the transaction history section to check the current transaction status.").font(.subheadline)
            Utils.divider
            if let id = id {
                Text("Transfer id: \(id)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let accountId = accountId {
                HStack {
                    Text("Account id: \(accountId)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    Button("", systemImage: "doc.on.doc") {
                        copyToClipboard(text: accountId)
                    }
                }
            }
            if let memo = memo {
                HStack {
                    Text("Memo: \(memo)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    Button("", systemImage: "doc.on.doc") {
                        copyToClipboard(text: memo)
                    }
                }
            }
            if let memoType = memoType {
                Text("Memo type: \(memoType)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let eta = eta {
                Text("Eta: \(eta)").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let extraInfo = extraInfo?.message {
                Text("Extra info: \(extraInfo)").font(.subheadline)
            }
        }
    }
    
    private func copyToClipboard(text:String) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = text
        toastMessage = "Copied to clipboard"
        showToast = true
    }
}

public class DepositInstruction: Hashable, Identifiable {
    var key:String
    var value: String
    var description:String
    
    internal init(key: String, value: String, description:String) {
        self.key = key
        self.value = value
        self.description = description
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(value)
        hasher.combine(description)
    }
    
    public static func == (lhs: DepositInstruction, rhs: DepositInstruction) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value && lhs.description == rhs.description
    }
}
