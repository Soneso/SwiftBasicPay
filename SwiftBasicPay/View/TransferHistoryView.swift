//
//  TransferHistoryView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 29.07.25.
//

import SwiftUI
import stellar_wallet_sdk
import AlertToast

struct TransferHistoryView: View {
    
    private var assetInfo:AnchoredAssetInfo
    private var authToken:AuthToken
    
    internal init(assetInfo: AnchoredAssetInfo, authToken: AuthToken) {
        self.assetInfo = assetInfo
        self.authToken = authToken
    }
    
    @State private var mode: Int = 1 // 1 = sep6, 2 = sep24
    @State private var isLoadingTransfers = false
    @State private var sep6ErrorMessage:String?
    @State private var sep24ErrorMessage:String?
    @State private var rawSep6Transactions:[Sep6Transaction] = []
    @State private var rawSep24Transactions:[InteractiveFlowTransaction] = []
    @State private var showToast = false
    @State private var toastMessage:String = ""
    
    var body: some View {
        VStack() {
            if isLoadingTransfers {
                Utils.progressViewWithLabel("Loading transfers")
            } else {
                Picker(selection: $mode, label: Text("Select")) {
                    Text("SEP-06 Transfers").tag(1)
                    Text("SEP-24 Transfers").tag(2)
                }.pickerStyle(.segmented)
                
                if mode == 1 {
                    if let error = sep6ErrorMessage {
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                    }
                    ScrollView {
                        ForEach(sep6History, id: \.id) { info in
                            sep6TransactionBox(info.raw)
                        }
                    }.padding(.top)
                    
                } else if mode == 2 {
                    if let error = sep24ErrorMessage {
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                    }
                    ScrollView {
                        ForEach(sep24History, id: \.id) { info in
                            Text("\(info.id)").font(.subheadline).font(.caption)
                                .fontWeight(.light).italic().frame(maxWidth: .infinity, alignment: .leading)
                            Spacer(minLength: 10)
                        }
                    }.padding(.top)
                    
                }
            }
            
        }.onAppear() {
            Task {
                isLoadingTransfers = true
                await loadSep6Transfers()
                await loadSep24Transfers()
                isLoadingTransfers = false
            }
        }.toast(isPresenting: $showToast){
            AlertToast(type: .regular, title: "\(toastMessage)")
        }
    }
    
    private func loadSep6Transfers() async {
        do {
            let sep6 = assetInfo.anchor.sep6
            rawSep6Transactions = try await sep6.getTransactionsForAsset(authToken: authToken, assetCode: assetInfo.code)
        } catch {
            sep6ErrorMessage = "Error loading SEP-06 transfer history: \(error.localizedDescription)"
        }
    }
    
    private func loadSep24Transfers() async {
        do {
            let sep24 = assetInfo.anchor.sep24
            rawSep24Transactions = try await sep24.getTransactionsForAsset(authToken: authToken, asset: assetInfo.asset)
        } catch {
            sep6ErrorMessage = "Error loading SEP-24 transfer history: \(error.localizedDescription)"
        }
    }
    
    var sep6History: [Sep6TxInfo] {
        var result:[Sep6TxInfo] = []
        for rawSep6Transaction in rawSep6Transactions {
            result.append(Sep6TxInfo(raw: rawSep6Transaction))
        }
        return result
    }
    
    var sep24History: [Sep24TxInfo] {
        var result:[Sep24TxInfo] = []
        for rawSep24Transaction in rawSep24Transactions {
            result.append(Sep24TxInfo(raw: rawSep24Transaction))
        }
        return result
    }
    
    private func sep6TransactionBox(_ tx:Sep6Transaction) -> some View {
        var title = tx.kind
        if let amount = tx.amountIn, tx.kind == "deposit" {
            title.append(" \(amount)")
        } else if let amount = tx.amountOut, tx.kind == "withdrawal" {
            title.append(" \(amount)")
        }
        title.append(" \(assetInfo.code)")
        return GroupBox (title){
            Utils.divider
            getRow("Id", tx.id)
            getRow("Kind", tx.kind)
            if let message = tx.message {
                getRow("Msg.", message)
            }
            if let eta = tx.statusEta {
                getRow("Status Eta.", "\(eta)")
            }
            if let amountIn = tx.amountIn {
                getRow("Amount in", amountIn)
            }
            if let amountInAsset = tx.amountInAsset {
                getRow("Amount in asset", amountInAsset)
            }
            if let amountOut = tx.amountOut {
                getRow("Amount out", amountOut)
            }
            if let amountOutAsset = tx.amountOutAsset {
                getRow("Amount in asset", amountOutAsset)
            }
            if let amountFee = tx.amountFee {
                getRow("Amount fee", amountFee)
            }
            if let amountFeeAsset = tx.amountFeeAsset{
                getRow("Amount fee asset", amountFeeAsset)
            }
            if let chargedFeeInfo = tx.chargedFeeInfo {
                sep6ChargedFeeDetails(chargedFeeInfo)
            }
            if let quoteId = tx.quoteId {
                getRow("Quote id", quoteId)
            }
            if let from = tx.from {
                getRow("From", from)
            }
            if let to = tx.to {
                getRow("To", to)
            }
            if let externalExtra = tx.externalExtra {
                getRow("External extra", externalExtra)
            }
            if let externalExtraText = tx.externalExtraText {
                getRow("External extra text", externalExtraText)
            }
            if let depositMemo = tx.depositMemo {
                getRow("Deposit memo", depositMemo)
            }
            if let depositMemoType = tx.depositMemoType {
                getRow("Deposit memo type", depositMemoType)
            }
            if let withdrawAnchorAccount = tx.withdrawAnchorAccount {
                getRow("Withdraw anchor account", withdrawAnchorAccount)
            }
            if let startedAt = tx.startedAt {
                getRow("Started at", "\(startedAt)")
            }
            if let updatedAt = tx.updatedAt {
                getRow("Updated at", "\(updatedAt)")
            }
            if let completedAt = tx.completedAt {
                getRow("Completed at", "\(completedAt)")
            }
            if let stellarTransactionId = tx.stellarTransactionId {
                getRow("Stellar transaction id", stellarTransactionId)
            }
            if let externalTransactionId = tx.externalTransactionId {
                getRow("External transaction id", externalTransactionId)
            }
            if let refunded = tx.refunded {
                getRow("Refunded", "\(refunded)")
            }
            if let refunds = tx.refunds {
                sep6RefundsDetails(refunds)
            }
            if let requiredInfoMessage = tx.requiredInfoMessage {
                getRow("Required info msg.", requiredInfoMessage)
            }
            if let claimableBalanceId = tx.claimableBalanceId {
                getRow("Claimable balance id.", claimableBalanceId)
            }
            if let moreInfoUrl = tx.moreInfoUrl {
                getRow("More info url", moreInfoUrl)
            }
        }
    }
    
    private func sep6ChargedFeeDetails(_ chargedFee: Sep6ChargedFee) -> some View {
        var detailInfos:[Sep6ChargedFeeDetailInfo] = []
        if let details = chargedFee.details {
            for detail in details {
                detailInfos.append(Sep6ChargedFeeDetailInfo(raw: detail))
            }
        }
        return VStack {
            getRow("Charged fee - total", chargedFee.total)
            getRow("Charged fee - asset", chargedFee.asset)
            ForEach(detailInfos, id: \.name) { info in
                getRow("Charged fee - detail name", info.name)
                getRow("Charged fee - detail amount", info.amount)
                if let desc = info.desc {
                    getRow("Charged fee - detail desc", desc)
                }
            }
        }
    }
    
    private func sep6RefundsDetails(_ refunds: Sep6Refunds) -> some View {
        var paymentInfos:[Sep6RefundPaymentInfo] = []
        if let payments = refunds.payments {
            for payment in payments {
                paymentInfos.append(Sep6RefundPaymentInfo(raw: payment))
            }
        }
        return VStack {
            getRow("Refunds - amount refunded", refunds.amountRefunded)
            getRow("Refunds - amount fee", refunds.amountFee)
            ForEach(paymentInfos, id: \.id) { info in
                getRow("Refunds - payment id", info.id)
                getRow("Refunds - payment id type:", info.idType)
                getRow("Refunds - payment \(info.id) amount", info.amount )
                getRow("Refunds - payment \(info.id) fee", info.fee )
            }
        }
    }
    
    private func getRow(_ label:String, _ txt:String) -> some View {
        HStack {
            Text("\(label): \(txt)").font(.subheadline).font(.caption)
                .fontWeight(.light).italic().frame(maxWidth: .infinity, alignment: .leading)
            Button("", systemImage: "doc.on.doc") {
                copyToClipboard(text: txt)
            }
        }.padding(.vertical, 5.0)
    }
    
    private func copyToClipboard(text:String) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = text
        toastMessage = "Copied to clipboard"
        showToast = true
    }
}

public class Sep6TxInfo: Hashable, Identifiable {

    public let raw:Sep6Transaction
    
    internal init(raw: Sep6Transaction) {
        self.raw = raw
    }
    
    public var id:String {
        return raw.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw.id)
    }
    
    public static func == (lhs: Sep6TxInfo, rhs: Sep6TxInfo) -> Bool {
        lhs.raw.id == rhs.raw.id
    }
}

public class Sep24TxInfo: Hashable, Identifiable {

    public let raw:InteractiveFlowTransaction
    
    internal init(raw: InteractiveFlowTransaction) {
        self.raw = raw
    }
    
    public var id:String {
        return raw.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw.id)
    }
    
    public static func == (lhs: Sep24TxInfo, rhs: Sep24TxInfo) -> Bool {
        lhs.raw.id == rhs.raw.id
    }
}

public class Sep6ChargedFeeDetailInfo: Hashable, Identifiable {

    public let raw:Sep6ChargedFeeDetail
    
    internal init(raw: Sep6ChargedFeeDetail) {
        self.raw = raw
    }
    
    public var name:String {
        return raw.name
    }
    
    public var amount:String {
        return raw.amount
    }
    
    public var desc:String? {
        return raw.description
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw.name)
    }
    
    public static func == (lhs: Sep6ChargedFeeDetailInfo, rhs: Sep6ChargedFeeDetailInfo) -> Bool {
        lhs.raw.name == rhs.raw.name
    }
}

public class Sep6RefundPaymentInfo: Hashable, Identifiable {

    public let raw:Sep6Payment
    
    internal init(raw: Sep6Payment) {
        self.raw = raw
    }
    
    public var id:String {
        return raw.id
    }
    
    public var idType:String {
        return raw.idType
    }

    public var amount:String {
        return raw.amount
    }
    
    public var fee:String {
        return raw.fee
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw.id)
    }
    
    public static func == (lhs: Sep6RefundPaymentInfo, rhs: Sep6RefundPaymentInfo) -> Bool {
        lhs.raw.id == rhs.raw.id
    }
}

