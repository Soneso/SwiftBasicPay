//
//  TransferHistoryView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 15.08.25.
//

import SwiftUI
import stellar_wallet_sdk
import AlertToast

// MARK: - View Model

@Observable
@MainActor
class TransferHistoryViewModel {
    // Properties
    let assetInfo: AnchoredAssetInfo
    let authToken: AuthToken
    let savedKycData: [KycEntry]
    
    // State
    enum HistoryMode: Int, CaseIterable {
        case sep6 = 1
        case sep24 = 2
        
        var title: String {
            switch self {
            case .sep6: return "SEP-6 Transfers"
            case .sep24: return "SEP-24 Transfers"
            }
        }
    }
    
    var mode: HistoryMode = .sep6
    var isLoadingTransfers = false
    var isUpdatingSep12Data = false
    var isGettingRequiredSep12Data = false
    
    // Error messages
    var sep6ErrorMessage: String?
    var sep24ErrorMessage: String?
    
    // Transaction data
    var rawSep6Transactions: [Sep6Transaction] = []
    var rawSep24Transactions: [InteractiveFlowTransaction] = []
    
    // KYC form state
    var showKycFormSheet = false
    var kycCustomerId: String?
    var kycRequiredFields: [String: Field] = [:]
    var kycTransactionId = ""
    
    // Toast notifications
    var showToast = false
    var toastMessage = ""
    var toastType: AlertToast.AlertType = .regular
    
    // Expanded states for transaction cards
    var expandedSep6Transactions: Set<String> = []
    var expandedSep24Transactions: Set<String> = []
    
    init(
        assetInfo: AnchoredAssetInfo,
        authToken: AuthToken,
        savedKycData: [KycEntry] = []
    ) {
        self.assetInfo = assetInfo
        self.authToken = authToken
        self.savedKycData = savedKycData
    }
    
    // MARK: - Computed Properties
    
    var sep6History: [Sep6TransactionInfo] {
        rawSep6Transactions.map { Sep6TransactionInfo(raw: $0) }
    }
    
    var sep24History: [Sep24TransactionInfo] {
        rawSep24Transactions.map { Sep24TransactionInfo(raw: $0) }
    }
    
    var hasTransactions: Bool {
        (mode == .sep6 && !rawSep6Transactions.isEmpty) ||
        (mode == .sep24 && !rawSep24Transactions.isEmpty)
    }
    
    // MARK: - Actions
    
    func loadTransfers() async {
        isLoadingTransfers = true
        await loadSep6Transfers()
        await loadSep24Transfers()
        isLoadingTransfers = false
        
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
    
    private func loadSep6Transfers() async {
        sep6ErrorMessage = nil
        do {
            let sep6 = assetInfo.anchor.sep6
            rawSep6Transactions = try await sep6.getTransactionsForAsset(
                authToken: authToken,
                assetCode: assetInfo.code
            )
        } catch {
            sep6ErrorMessage = "Error loading SEP-6 transfers: \(error.localizedDescription)"
        }
    }
    
    private func loadSep24Transfers() async {
        sep24ErrorMessage = nil
        do {
            let sep24 = assetInfo.anchor.sep24
            rawSep24Transactions = try await sep24.getTransactionsForAsset(
                authToken: authToken,
                asset: assetInfo.asset
            )
        } catch {
            sep24ErrorMessage = "Error loading SEP-24 transfers: \(error.localizedDescription)"
        }
    }
    
    func getCustomerInfo(txId: String) async {
        isGettingRequiredSep12Data = true
        
        do {
            let sep12 = try await assetInfo.anchor.sep12(authToken: authToken)
            let response = try await sep12.get(transactionId: txId)
            
            let requiredFields: [String: Field] = {
                var fields: [String: Field] = [:]
                if let responseFields = response.fields {
                    for (key, field) in responseFields {
                        if !(field.optional ?? false) {
                            fields[key] = field
                        }
                    }
                }
                return fields
            }()
            
            if !requiredFields.isEmpty {
                kycCustomerId = response.id
                kycRequiredFields = requiredFields
                kycTransactionId = txId
                showKycFormSheet = true
            } else {
                showToast(message: "No KYC information required", type: .complete(Color.green))
            }
            
        } catch {
            sep6ErrorMessage = "Error getting required SEP-12 info: \(error.localizedDescription)"
            showToast(message: "Failed to get KYC requirements", type: .error(Color.red))
        }
        
        isGettingRequiredSep12Data = false
    }
    
    func uploadSep12CustomerData(customerId: String? = nil, requestedFieldsData: [String: String], txId: String) async {
        isUpdatingSep12Data = true
        
        do {
            let sep12 = try await assetInfo.anchor.sep12(authToken: authToken)
            if let customerId = customerId {
                _ = try await sep12.update(id: customerId, sep9Info: requestedFieldsData, transactionId: txId)
            } else {
                _ = try await sep12.add(sep9Info: requestedFieldsData, transactionId: txId)
            }
            
            // Wait a bit for the server to process
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await loadTransfers()
            
            showToast(message: "KYC information updated successfully", type: .complete(Color.green))
            
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            
        } catch {
            sep6ErrorMessage = "Error updating SEP-12 info: \(error.localizedDescription)"
            showToast(message: "Failed to update KYC information", type: .error(Color.red))
            
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
        }
        
        isUpdatingSep12Data = false
    }
    
    func toggleTransactionExpanded(_ transactionId: String, mode: HistoryMode) {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        switch mode {
        case .sep6:
            if expandedSep6Transactions.contains(transactionId) {
                expandedSep6Transactions.remove(transactionId)
            } else {
                expandedSep6Transactions.insert(transactionId)
            }
        case .sep24:
            if expandedSep24Transactions.contains(transactionId) {
                expandedSep24Transactions.remove(transactionId)
            } else {
                expandedSep24Transactions.insert(transactionId)
            }
        }
    }
    
    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showToast(message: "Copied to clipboard", type: .regular)
        
        let selection = UISelectionFeedbackGenerator()
        selection.selectionChanged()
    }
    
    func showToast(message: String, type: AlertToast.AlertType = .regular) {
        toastMessage = message
        toastType = type
        showToast = true
    }
}

// MARK: - Main View

struct TransferHistoryView: View {
    @State private var viewModel: TransferHistoryViewModel?
    
    private let assetInfo: AnchoredAssetInfo
    private let authToken: AuthToken
    private let savedKycData: [KycEntry]
    
    init(
        assetInfo: AnchoredAssetInfo,
        authToken: AuthToken,
        savedKycData: [KycEntry] = []
    ) {
        self.assetInfo = assetInfo
        self.authToken = authToken
        self.savedKycData = savedKycData
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if let vm = viewModel {
                if vm.isLoadingTransfers && vm.rawSep6Transactions.isEmpty && vm.rawSep24Transactions.isEmpty {
                    TransferSkeletonLoader()
                        .padding(.top)
                } else if vm.isUpdatingSep12Data {
                    TransferProgressIndicator(
                        message: "Updating KYC information",
                        progress: nil
                    )
                } else {
                    // Mode selector
                    Picker(selection: .init(
                        get: { vm.mode },
                        set: {
                            let impact = UISelectionFeedbackGenerator()
                            impact.selectionChanged()
                            vm.mode = $0
                        }
                    ), label: Text("Transfer Type")) {
                        ForEach(TransferHistoryViewModel.HistoryMode.allCases, id: \.rawValue) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Content based on mode
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if vm.mode == .sep6 {
                                sep6Content
                            } else {
                                sep24Content
                            }
                        }
                        .padding(.top)
                    }
                    .refreshable {
                        await vm.loadTransfers()
                    }
                }
            } else {
                ProgressView()
                    .onAppear {
                        Task { @MainActor in
                            viewModel = TransferHistoryViewModel(
                                assetInfo: assetInfo,
                                authToken: authToken,
                                savedKycData: savedKycData
                            )
                            await viewModel?.loadTransfers()
                        }
                    }
            }
        }
        .toast(isPresenting: .init(
            get: { viewModel?.showToast ?? false },
            set: { viewModel?.showToast = $0 }
        )) {
            AlertToast(
                type: viewModel?.toastType ?? .regular,
                title: viewModel?.toastMessage ?? ""
            )
        }
        .sheet(isPresented: .init(
            get: { viewModel?.showKycFormSheet ?? false },
            set: { viewModel?.showKycFormSheet = $0 }
        )) {
            if let vm = viewModel {
                Sep12KycFormSheet(
                    customerId: vm.kycCustomerId,
                    requiredFields: vm.kycRequiredFields,
                    savedKycData: savedKycData,
                    txId: vm.kycTransactionId,
                    onSubmit: vm.uploadSep12CustomerData,
                    isPresented: .init(
                        get: { vm.showKycFormSheet },
                        set: { vm.showKycFormSheet = $0 }
                    )
                )
            }
        }
    }
    
    @ViewBuilder
    @MainActor
    private var sep6Content: some View {
        if let vm = viewModel {
            if let error = vm.sep6ErrorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await vm.loadTransfers() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if vm.sep6History.isEmpty {
                TransferEmptyState(type: .noTransfers)
                    .padding(.top, 40)
            } else {
                ForEach(vm.sep6History, id: \.id) { info in
                    Sep6TransactionCard(
                        transaction: info.raw,
                        assetCode: assetInfo.code,
                        isExpanded: .init(
                            get: { vm.expandedSep6Transactions.contains(info.id) },
                            set: { _ in vm.toggleTransactionExpanded(info.id, mode: .sep6) }
                        ),
                        onCopy: vm.copyToClipboard,
                        onGetKycInfo: { txId in
                            Task { await vm.getCustomerInfo(txId: txId) }
                        },
                        isLoadingKyc: vm.isGettingRequiredSep12Data
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    @MainActor
    private var sep24Content: some View {
        if let vm = viewModel {
            if let error = vm.sep24ErrorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await vm.loadTransfers() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if vm.sep24History.isEmpty {
                TransferEmptyState(type: .noTransfers)
                    .padding(.top, 40)
            } else {
                ForEach(vm.sep24History, id: \.id) { info in
                    Sep24TransactionCard(
                        transaction: info.raw,
                        assetCode: assetInfo.code,
                        isExpanded: .init(
                            get: { vm.expandedSep24Transactions.contains(info.id) },
                            set: { _ in vm.toggleTransactionExpanded(info.id, mode: .sep24) }
                        ),
                        onCopy: vm.copyToClipboard
                    )
                }
            }
        }
    }
}

// MARK: - Sep6 Transaction Card

struct Sep6TransactionCard: View {
    let transaction: Sep6Transaction
    let assetCode: String
    @Binding var isExpanded: Bool
    let onCopy: @MainActor (String) -> Void
    let onGetKycInfo: @MainActor (String) -> Void
    let isLoadingKyc: Bool
    
    private var title: String {
        var result = transaction.kind
        if let amount = transaction.amountIn, transaction.kind == "deposit" {
            result.append(" \(amount)")
        } else if let amount = transaction.amountOut, transaction.kind == "withdrawal" {
            result.append(" \(amount)")
        }
        result.append(" \(assetCode)")
        return result
    }
    
    private var statusColor: Color {
        switch transaction.transactionStatus {
        case .completed: return .green
        case .pendingExternal, .pendingAnchor, .pendingStellar, .pendingTrust, .pendingUser: return .orange
        case .pendingCustomerInfoUpdate: return .red
        case .pendingUserTransferStart, .pendingUserTransferComplete: return .blue
        case .incomplete, .noMarket, .tooSmall, .tooLarge: return .gray
        case .error: return .red
        case .expired: return .gray
        case .refunded: return .purple
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                TransferStatusCard(
                    title: title,
                    status: transaction.transactionStatus.rawValue,
                    statusColor: statusColor,
                    amount: nil,
                    assetCode: "",
                    message: transaction.message,
                    isExpanded: $isExpanded
                )
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(spacing: 4) {
                        TransferDetailRow(
                            label: "ID",
                            value: "\(transaction.id.prefix(8))...\(transaction.id.suffix(4))",
                            showCopyButton: true,
                            copyValue: transaction.id
                        )
                        .onTapGesture { onCopy(transaction.id) }
                        
                        TransferDetailRow(label: "Kind", value: transaction.kind)
                        
                        if transaction.transactionStatus == .pendingCustomerInfoUpdate {
                            HStack {
                                TransferDetailRow(
                                    label: "Status",
                                    value: transaction.transactionStatus.rawValue
                                )
                                .foregroundStyle(.red)
                                
                                if isLoadingKyc {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Button(action: { onGetKycInfo(transaction.id) }) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.body)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        } else {
                            TransferDetailRow(label: "Status", value: transaction.transactionStatus.rawValue)
                        }
                        
                        if let eta = transaction.statusEta {
                            TransferDetailRow(label: "ETA", value: "\(eta) seconds")
                        }
                        
                        if let from = transaction.from {
                            TransferDetailRow(
                                label: "From",
                                value: from.shortAddress,
                                showCopyButton: true,
                                copyValue: from
                            )
                            .onTapGesture { onCopy(from) }
                        }
                        
                        if let to = transaction.to {
                            TransferDetailRow(
                                label: "To",
                                value: to.shortAddress,
                                showCopyButton: true,
                                copyValue: to
                            )
                            .onTapGesture { onCopy(to) }
                        }
                        
                        if let stellarTxId = transaction.stellarTransactionId {
                            TransferDetailRow(
                                label: "Stellar TX",
                                value: "\(stellarTxId.prefix(8))...",
                                showCopyButton: true,
                                copyValue: stellarTxId
                            )
                            .onTapGesture { onCopy(stellarTxId) }
                        }
                        
                        if let startedAt = transaction.startedAt {
                            TransferDetailRow(
                                label: "Started",
                                value: formatDate(startedAt)
                            )
                        }
                        
                        if let completedAt = transaction.completedAt {
                            TransferDetailRow(
                                label: "Completed",
                                value: formatDate(completedAt)
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.3), value: isExpanded)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Sep24 Transaction Card

struct Sep24TransactionCard: View {
    let transaction: InteractiveFlowTransaction
    let assetCode: String
    @Binding var isExpanded: Bool
    let onCopy: @MainActor (String) -> Void
    
    private var title: String {
        if transaction is DepositTransaction {
            return "Deposit"
        } else if transaction is WithdrawalTransaction {
            return "Withdrawal"
        } else if transaction is IncompleteDepositTransaction {
            return "Deposit (Incomplete)"
        } else if transaction is IncompleteWithdrawalTransaction {
            return "Withdrawal (Incomplete)"
        } else if transaction is ErrorTransaction {
            return "Error"
        }
        return "Transaction"
    }
    
    private var amount: String? {
        if let tx = transaction as? ProcessingAnchorTransaction {
            return tx.amountIn ?? tx.amountOut
        }
        return nil
    }
    
    private var statusColor: Color {
        if transaction is ErrorTransaction {
            return .red
        } else if transaction is IncompleteAnchorTransaction {
            return .orange
        } else if let tx = transaction as? ProcessingAnchorTransaction,
                  tx.completedAt != nil {
            return .green
        }
        return .blue
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { isExpanded.toggle() }) {
                TransferStatusCard(
                    title: title,
                    status: getStatus(),
                    statusColor: statusColor,
                    amount: amount,
                    assetCode: assetCode,
                    message: transaction.message,
                    isExpanded: $isExpanded
                )
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(spacing: 4) {
                        TransferDetailRow(
                            label: "ID",
                            value: "\(transaction.id.prefix(8))...\(transaction.id.suffix(4))",
                            showCopyButton: true,
                            copyValue: transaction.id
                        )
                        .onTapGesture { onCopy(transaction.id) }
                        
                        TransferDetailRow(
                            label: "Started",
                            value: formatDate(transaction.startedAt)
                        )
                        
                        // Type-specific details
                        if let tx = transaction as? ProcessingAnchorTransaction {
                            if let amountIn = tx.amountIn {
                                TransferDetailRow(label: "Amount In", value: amountIn)
                            }
                            if let amountOut = tx.amountOut {
                                TransferDetailRow(label: "Amount Out", value: amountOut)
                            }
                            if let fee = tx.amountFee {
                                TransferDetailRow(label: "Fee", value: fee)
                            }
                            if let completedAt = tx.completedAt {
                                TransferDetailRow(
                                    label: "Completed",
                                    value: formatDate(completedAt)
                                )
                            }
                            if let stellarTxId = tx.stellarTransactionId {
                                TransferDetailRow(
                                    label: "Stellar TX",
                                    value: "\(stellarTxId.prefix(8))...",
                                    showCopyButton: true,
                                    copyValue: stellarTxId
                                )
                                .onTapGesture { onCopy(stellarTxId) }
                            }
                        }
                        
                        if let depositTx = transaction as? DepositTransaction {
                            if let from = depositTx.from {
                                TransferDetailRow(
                                    label: "From",
                                    value: from.shortAddress,
                                    showCopyButton: true,
                                    copyValue: from
                                )
                                .onTapGesture { onCopy(from) }
                            }
                            if let to = depositTx.to {
                                TransferDetailRow(
                                    label: "To",
                                    value: to.shortAddress,
                                    showCopyButton: true,
                                    copyValue: to
                                )
                                .onTapGesture { onCopy(to) }
                            }
                        }
                        
                        if let withdrawalTx = transaction as? WithdrawalTransaction {
                            if let from = withdrawalTx.from {
                                TransferDetailRow(
                                    label: "From",
                                    value: from.shortAddress,
                                    showCopyButton: true,
                                    copyValue: from
                                )
                                .onTapGesture { onCopy(from) }
                            }
                            if let to = withdrawalTx.to {
                                TransferDetailRow(
                                    label: "To",
                                    value: to.shortAddress,
                                    showCopyButton: true,
                                    copyValue: to
                                )
                                .onTapGesture { onCopy(to) }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.3), value: isExpanded)
    }
    
    private func getStatus() -> String {
        if transaction is ErrorTransaction {
            return "Error"
        } else if transaction is IncompleteAnchorTransaction {
            return "Incomplete"
        } else if let tx = transaction as? ProcessingAnchorTransaction {
            return tx.completedAt != nil ? "Completed" : "Processing"
        }
        return "Unknown"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Transaction info wrapper classes
public class Sep6TransactionInfo: Hashable, Identifiable {
    public let raw: Sep6Transaction
    
    internal init(raw: Sep6Transaction) {
        self.raw = raw
    }
    
    public var id: String {
        return raw.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw.id)
    }
    
    public static func == (lhs: Sep6TransactionInfo, rhs: Sep6TransactionInfo) -> Bool {
        lhs.raw.id == rhs.raw.id
    }
}

public class Sep24TransactionInfo: Hashable, Identifiable {
    public let raw: InteractiveFlowTransaction
    
    internal init(raw: InteractiveFlowTransaction) {
        self.raw = raw
    }
    
    public var id: String {
        return raw.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw.id)
    }
    
    public static func == (lhs: Sep24TransactionInfo, rhs: Sep24TransactionInfo) -> Bool {
        lhs.raw.id == rhs.raw.id
    }
}

