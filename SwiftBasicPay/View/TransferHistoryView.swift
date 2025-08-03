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
    private var savedKycData: [KycEntry] = []
    
    internal init(assetInfo: AnchoredAssetInfo, authToken: AuthToken, savedKycData: [KycEntry] = []) {
        self.assetInfo = assetInfo
        self.authToken = authToken
        self.savedKycData = savedKycData
    }
    
    @State private var mode: Int = 1 // 1 = sep6, 2 = sep24
    @State private var isLoadingTransfers = false
    @State private var isGettingRequiredSep12Data = false
    @State private var isUpdatingSep12Data = false
    @State private var sep6ErrorMessage:String?
    @State private var sep24ErrorMessage:String?
    @State private var rawSep6Transactions:[Sep6Transaction] = []
    @State private var rawSep24Transactions:[InteractiveFlowTransaction] = []
    @State private var showToast = false
    @State private var toastMessage:String = ""
    @State private var showKycFormSheet = false
    @State private var kycCustomerId: String?
    @State private var kycRequiredFields: [String: Field] = [:]
    @State private var kycTransactionId: String = ""
    
    var body: some View {
        VStack() {
            if isLoadingTransfers {
                Utils.progressViewWithLabel("Loading transfers")
            } else if isUpdatingSep12Data {
                Utils.progressViewWithLabel("Sending SEP-12 data to anchor")
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
                            sep24TransactionBox(info.raw)
                        }
                    }.padding(.top)
                }
            }
            
        }.onAppear() {
            Task {
               await loadTransfers()
            }
        }.toast(isPresenting: $showToast){
            AlertToast(type: .regular, title: "\(toastMessage)")
        }.sheet(isPresented: $showKycFormSheet) {
            Sep12KycFormSheet(
                customerId: kycCustomerId,
                requiredFields: kycRequiredFields,
                savedKycData: savedKycData,
                txId: kycTransactionId,
                onSubmit: uploadSep12CustomerData,
                isPresented: $showKycFormSheet
            )
        }
    }
    
    private func loadTransfers() async {
        isLoadingTransfers = true
        await loadSep6Transfers()
        await loadSep24Transfers()
        isLoadingTransfers = false
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
            getRow("Id", "\(tx.id.prefix(6))...\(tx.id.suffix(4))", showCopyButton: true, stringToCopy: tx.id)
            getRow("Kind", tx.kind)
            if tx.transactionStatus == TransactionStatus.pendingCustomerInfoUpdate {
                HStack {
                    HStack(spacing: 0) {
                        Text("Status:").font(.subheadline).font(.caption).foregroundStyle(.red)
                            .fontWeight(.bold)
                        Text(" \(tx.transactionStatus.rawValue)").font(.subheadline).font(.caption).foregroundStyle(.red)
                            .fontWeight(.light).italic()
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    
                    if isGettingRequiredSep12Data {
                        Utils.progressView
                    } else {
                        Button("", systemImage: "square.and.arrow.up") {
                            Task {
                                await getCustomerInfo(txId: tx.id)
                            }
                        }
                    }
                }.padding(.vertical, 5.0)
            } else {
                getRow("Status", tx.transactionStatus.rawValue)
            }
            
            if let message = tx.message {
                getRow("Msg.", message, showCopyButton: true)
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
                getRow("Quote id", quoteId, showCopyButton: true)
            }
            if let from = tx.from {
                getRow("From", from.shortAddress, showCopyButton: true, stringToCopy: from)
            }
            if let to = tx.to {
                getRow("To", to.shortAddress, showCopyButton: true, stringToCopy: to)
            }
            if let externalExtra = tx.externalExtra {
                getRow("External extra", externalExtra, showCopyButton: true)
            }
            if let externalExtraText = tx.externalExtraText {
                getRow("External extra text", externalExtraText, showCopyButton: true)
            }
            if let depositMemo = tx.depositMemo {
                getRow("Deposit memo", depositMemo, showCopyButton: true)
            }
            if let depositMemoType = tx.depositMemoType {
                getRow("Deposit memo type", depositMemoType)
            }
            if let withdrawAnchorAccount = tx.withdrawAnchorAccount {
                getRow("Withdraw anchor account", withdrawAnchorAccount.shortAddress, showCopyButton: true, stringToCopy: withdrawAnchorAccount)
            }
            if let startedAt = tx.startedAt {
                getRow("Started at", formatDateString("\(startedAt)"))
            }
            if let updatedAt = tx.updatedAt {
                getRow("Updated at", formatDateString("\(updatedAt)"))
            }
            if let completedAt = tx.completedAt {
                getRow("Completed at", formatDateString("\(completedAt)"))
            }
            if let stellarTransactionId = tx.stellarTransactionId {
                getRow("Stellar transaction id", stellarTransactionId, showCopyButton: true)
            }
            if let externalTransactionId = tx.externalTransactionId {
                getRow("External transaction id", externalTransactionId, showCopyButton: true)
            }
            if let refunded = tx.refunded {
                getRow("Refunded", "\(refunded)")
            }
            if let refunds = tx.refunds {
                sep6RefundsDetails(refunds)
            }
            if let requiredInfoMessage = tx.requiredInfoMessage {
                getRow("Required info msg.", requiredInfoMessage, showCopyButton: true)
            }
            if let claimableBalanceId = tx.claimableBalanceId {
                getRow("Claimable balance id.", claimableBalanceId, showCopyButton: true)
            }
            if let moreInfoUrl = tx.moreInfoUrl {
                getRow("More info url", "\(moreInfoUrl.prefix(20))...", showCopyButton: true, stringToCopy: moreInfoUrl)
            }
        }
    }
    
    private func sep24TransactionBox(_ tx:InteractiveFlowTransaction) -> some View {
        var title = getSep24TxTitle(tx)
        if let tx  = tx as? ProcessingAnchorTransaction {
            if let amount = tx.amountIn {
                title.append(" in: \(amount)  \(assetInfo.code)")
            } else if let amount = tx.amountOut {
                title.append(" out: \(amount)  \(assetInfo.code)")
            }
        }
        return GroupBox (title){
            Utils.divider
            getSep24TransactionBoxDetails(tx)
        }
    }
    
    private func getSep24TransactionBoxDetails(_ tx:InteractiveFlowTransaction) -> some View {
        return VStack {
            getRow("Id", "\(tx.id.prefix(6))...\(tx.id.suffix(4))", showCopyButton: true, stringToCopy: tx.id)
            
            if let tx = tx as? ProcessingAnchorTransaction {
                // Common ProcessingAnchorTransaction fields
                if let tx = tx as? DepositTransaction {
                    // Deposit-specific fields
                    if let from = tx.from {
                        getRow("From", from.shortAddress, showCopyButton: true, stringToCopy: from)
                    }
                    if let to = tx.to {
                        getRow("To", to.shortAddress, showCopyButton: true, stringToCopy: to)
                    }
                    if let depositMemo = tx.depositMemo {
                        getRow("Deposit memo", depositMemo, showCopyButton: true)
                    }
                    if let depositMemoType = tx.depositMemoType {
                        getRow("Deposit memo type", depositMemoType)
                    }
                    if let claimableBalanceId = tx.claimableBalanceId {
                        getRow("Claimable balance id", claimableBalanceId, showCopyButton: true)
                    }
                } else if let tx = tx as? WithdrawalTransaction {
                    // Withdrawal-specific fields
                    if let from = tx.from {
                        getRow("From", from.shortAddress, showCopyButton: true, stringToCopy: from)
                    }
                    if let to = tx.to {
                        getRow("To", to.shortAddress, showCopyButton: true, stringToCopy: to)
                    }
                    if let withdrawalMemo = tx.withdrawalMemo {
                        getRow("Withdrawal memo", withdrawalMemo, showCopyButton: true)
                    }
                    if let withdrawalMemoType = tx.withdrawalMemoType {
                        getRow("Withdrawal memo type", withdrawalMemoType)
                    }
                    if let withdrawAnchorAccount = tx.withdrawAnchorAccount {
                        getRow("Withdrawal anchor account", withdrawAnchorAccount.shortAddress, showCopyButton: true, stringToCopy: withdrawAnchorAccount)
                    }
                }
                
                // Common fields for ProcessingAnchorTransaction
                if let statusEta = tx.statusEta {
                    getRow("Status Eta", "\(statusEta)")
                }
                if let kycVerified = tx.kycVerified {
                    getRow("KYC verified", "\(kycVerified)")
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
                    getRow("Amount out asset", amountOutAsset)
                }
                if let amountFee = tx.amountFee {
                    getRow("Amount fee", amountFee)
                }
                if let amountFeeAsset = tx.amountFeeAsset {
                    getRow("Amount fee asset", amountFeeAsset)
                }
                if let completedAt = tx.completedAt {
                    getRow("Completed at", formatDateString("\(completedAt)"))
                }
                if let updatedAt = tx.updatedAt {
                    getRow("Updated at", formatDateString("\(updatedAt)"))
                }
                if let stellarTransactionId = tx.stellarTransactionId {
                    getRow("Stellar transaction id", stellarTransactionId, showCopyButton: true)
                }
                if let externalTransactionId = tx.externalTransactionId {
                    getRow("External transaction id", externalTransactionId, showCopyButton: true)
                }
                if let refunds = tx.refunds {
                    sep24RefundsDetails(refunds)
                }
            } else if let tx = tx as? IncompleteAnchorTransaction {
                // Incomplete transaction fields
                if let tx = tx as? IncompleteDepositTransaction {
                    if let to = tx.to {
                        getRow("To", to.shortAddress, showCopyButton: true, stringToCopy: to)
                    }
                } else if let tx = tx as? IncompleteWithdrawalTransaction {
                    if let from = tx.from {
                        getRow("From", from.shortAddress, showCopyButton: true, stringToCopy: from)
                    }
                }
            } else if let tx = tx as? ErrorTransaction {
                // Error transaction fields
                if let statusEta = tx.statusEta {
                    getRow("Status Eta", "\(statusEta)")
                }
                if let kycVerified = tx.kycVerified {
                    getRow("KYC verified", "\(kycVerified)")
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
                    getRow("Amount out asset", amountOutAsset)
                }
                if let amountFee = tx.amountFee {
                    getRow("Amount fee", amountFee)
                }
                if let amountFeeAsset = tx.amountFeeAsset {
                    getRow("Amount fee asset", amountFeeAsset)
                }
                if let quoteId = tx.quoteId {
                    getRow("Quote id", quoteId, showCopyButton: true)
                }
                if let completedAt = tx.completedAt {
                    getRow("Completed at", formatDateString("\(completedAt)"))
                }
                if let updatedAt = tx.updatedAt {
                    getRow("Updated at", formatDateString("\(updatedAt)"))
                }
                if let stellarTransactionId = tx.stellarTransactionId {
                    getRow("Stellar transaction id", stellarTransactionId, showCopyButton: true)
                }
                if let externalTransactionId = tx.externalTransactionId {
                    getRow("External transaction id", externalTransactionId, showCopyButton: true)
                }
                if let refunded = tx.refunded {
                    getRow("Refunded", "\(refunded)")
                }
                if let refunds = tx.refunds {
                    sep24RefundsDetails(refunds)
                }
                if let from = tx.from {
                    getRow("From", from.shortAddress, showCopyButton: true, stringToCopy: from)
                }
                if let to = tx.to {
                    getRow("To", to.shortAddress, showCopyButton: true, stringToCopy: to)
                }
                if let depositMemo = tx.depositMemo {
                    getRow("Deposit memo", depositMemo, showCopyButton: true)
                }
                if let depositMemoType = tx.depositMemoType {
                    getRow("Deposit memo type", depositMemoType)
                }
                if let claimableBalanceId = tx.claimableBalanceId {
                    getRow("Claimable balance id", claimableBalanceId, showCopyButton: true)
                }
                if let withdrawalMemo = tx.withdrawalMemo {
                    getRow("Withdrawal memo", withdrawalMemo, showCopyButton: true)
                }
                if let withdrawalMemoType = tx.withdrawalMemoType {
                    getRow("Withdrawal memo type", withdrawalMemoType)
                }
                if let withdrawAnchorAccount = tx.withdrawAnchorAccount {
                    getRow("Withdrawal anchor account", withdrawAnchorAccount.shortAddress, showCopyButton: true, stringToCopy: withdrawAnchorAccount)
                }
            }
            
            // Common fields for all transaction types
            getRow("Started at", formatDateString("\(tx.startedAt)"))
            if let message = tx.message {
                getRow("Message", message, showCopyButton: true)
            }
            if let moreInfoUrl = tx.moreInfoUrl {
                getRow("More info url", "\(moreInfoUrl.prefix(20))...", showCopyButton: true, stringToCopy: moreInfoUrl)
            }
        }
    }
    
    private func sep24RefundsDetails(_ refunds: Refunds) -> some View {
        var paymentInfos: [Sep24RefundPaymentInfo] = []
        for payment in refunds.payments {
            paymentInfos.append(Sep24RefundPaymentInfo(raw: payment))
        }
        return VStack {
            getRow("Refunds - amount refunded", refunds.amountRefunded)
            getRow("Refunds - amount fee", refunds.amountFee)
            ForEach(paymentInfos, id: \.id) { info in
                getRow("Refunds - payment id", info.id, showCopyButton: true)
                getRow("Refunds - payment id type", info.idType)
                getRow("Refunds - payment \(info.id) amount", info.amount)
                getRow("Refunds - payment \(info.id) fee", info.fee)
            }
        }
    }
    
    private func getSep24TxTitle(_ tx: InteractiveFlowTransaction) -> String {
        if let _ = tx as? DepositTransaction {
            return "Deposit"
        }
        if let _ = tx as? WithdrawalTransaction {
            return "Withdrawal"
        }
        if let _ = tx as? IncompleteDepositTransaction {
            return "Deposit (incomplete)"
        }
        if let _ = tx as? IncompleteWithdrawalTransaction {
            return "Withdrawal (incomplete)"
        }
        if let _ = tx as? ErrorTransaction {
            return "Error"
        }
        return tx.id
    }
    
    private func getCustomerInfo(txId: String) async {
        await MainActor.run {
            isGettingRequiredSep12Data = true
        }
        
        do {
            let sep12 = try await assetInfo.anchor.sep12(authToken: authToken)
            let response = try await sep12.get(transactionId: txId)
            
            let requiredFields: [String: Field] = {
                var fields: [String: Field] = [:]
                if let responseFields = response.fields {
                    for key in responseFields.keys {
                        let field = responseFields[key]!
                        if let optional = field.optional {
                            if !optional {
                                fields[key] = field
                            }
                        } else {
                            fields[key] = field
                        }
                    }
                }
                return fields
            }()
            
            await MainActor.run {
                if !requiredFields.isEmpty {
                    kycCustomerId = response.id
                    kycRequiredFields = requiredFields
                    kycTransactionId = txId
                    showKycFormSheet = true
                } else {
                    toastMessage = "No KYC information required"
                    showToast = true
                }
            }
            
        } catch {
            await MainActor.run {
                sep6ErrorMessage = "Error getting required SEP-12 info: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isGettingRequiredSep12Data = false
        }
    }
    
    private func uploadSep12CustomerData(customerId: String? = nil, requestedFieldsData: [String: String], txId: String) async {
        await MainActor.run {
            isUpdatingSep12Data = true
        }
        
        do {
            let sep12 = try await assetInfo.anchor.sep12(authToken: authToken)
            if let customerId = customerId {
                let _ = try await sep12.update(id: customerId, sep9Info: requestedFieldsData, transactionId: txId)
            } else {
                let _ = try await sep12.add(sep9Info: requestedFieldsData, transactionId: txId)
            }
            try await Task.sleep(nanoseconds: 5_000_000_000)
            await loadTransfers()
            
            await MainActor.run {
                toastMessage = "KYC information updated successfully"
                showToast = true
            }
        } catch {
            await MainActor.run {
                sep6ErrorMessage = "Error updating required SEP-12 info: \(error.localizedDescription)"
            }
        }
        
        await MainActor.run {
            isUpdatingSep12Data = false
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
                getRow("Refunds - payment id", info.id, showCopyButton: true)
                getRow("Refunds - payment id type:", info.idType)
                getRow("Refunds - payment \(info.id) amount", info.amount )
                getRow("Refunds - payment \(info.id) fee", info.fee )
            }
        }
    }
    
    private func getRow(_ title:String, _ txt:String, showCopyButton:Bool = false, stringToCopy:String? = nil) -> some View {
        HStack {
            HStack(spacing: 0) {
                Text("\(title):").font(.subheadline).font(.caption)
                    .fontWeight(.bold)
                Text(" \(txt)").font(.subheadline).font(.caption)
                    .fontWeight(.light).italic()
            }.frame(maxWidth: .infinity, alignment: .leading)
            if showCopyButton {
                Button("", systemImage: "doc.on.doc") {
                    let copyText = stringToCopy ?? txt
                    copyToClipboard(text: copyText)
                }
            }
        }.padding(.vertical, 3.0)
    }
    
    private func copyToClipboard(text:String) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = text
        toastMessage = "Copied to clipboard"
        showToast = true
    }
    
    private func formatDateString(_ dateString: String) -> String {
        return dateString.replacingOccurrences(of: " +0000", with: "")
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

public class Sep24RefundPaymentInfo: Hashable, Identifiable {

    public let raw:Payment
    
    internal init(raw: Payment) {
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
    
    public static func == (lhs: Sep24RefundPaymentInfo, rhs: Sep24RefundPaymentInfo) -> Bool {
        lhs.raw.id == rhs.raw.id
    }
}

