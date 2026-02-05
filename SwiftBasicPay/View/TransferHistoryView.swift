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
    let dashboardData: DashboardData
    
    // State
    enum HistoryMode: Int, CaseIterable {
        case sep24 = 1
        case sep6 = 2
        
        var title: String {
            switch self {
            case .sep6: return "SEP-6 Transfers"
            case .sep24: return "SEP-24 Transfers"
            }
        }
    }
    
    var mode: HistoryMode = .sep24
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
        savedKycData: [KycEntry] = [],
        dashboardData: DashboardData
    ) {
        self.assetInfo = assetInfo
        self.authToken = authToken
        self.savedKycData = savedKycData
        self.dashboardData = dashboardData
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
    
    @MainActor
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
    
    @MainActor
    func uploadSep12CustomerData(customerId: String? = nil, requestedFieldsData: [String: String], txId: String) async {
        isUpdatingSep12Data = true
        
        do {
            let sep12 = try await assetInfo.anchor.sep12(authToken: authToken)
            if let customerId = customerId {
                _ = try await sep12.update(id: customerId, sep9Info: requestedFieldsData, transactionId: txId)
            } else {
                _ = try await sep12.add(sep9Info: requestedFieldsData, transactionId: txId)
            }
            
            // Save KYC data locally using the domain manager to ensure proper cache management
            try await dashboardData.kycManagerDirect.updateKycEntries(requestedFieldsData)
            
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
    private let dashboardData: DashboardData
    
    init(
        assetInfo: AnchoredAssetInfo,
        authToken: AuthToken,
        savedKycData: [KycEntry] = [],
        dashboardData: DashboardData
    ) {
        self.assetInfo = assetInfo
        self.authToken = authToken
        self.savedKycData = savedKycData
        self.dashboardData = dashboardData
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
                            if vm.mode == .sep24 {
                                sep24Content
                            } else {
                                sep6Content
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
                                savedKycData: savedKycData,
                                dashboardData: dashboardData
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
                VStack(alignment: .leading, spacing: 0) {
                    // Divider with gradient fade
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color(.systemGray5), Color(.systemGray6).opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    VStack(spacing: 0) {
                        // ID Section with enhanced styling
                        HStack(spacing: 12) {
                            Image(systemName: "number.square.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Transaction ID")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(transaction.id.prefix(8))...\(transaction.id.suffix(4))")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: { onCopy(transaction.id) }) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6).opacity(0.5))
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        
                        // Type Badge
                        HStack {
                            Label(transaction.kind.capitalized, systemImage: transaction.kind == "deposit" ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(transaction.kind == "deposit" ? .green : .orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill((transaction.kind == "deposit" ? Color.green : Color.orange).opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .strokeBorder((transaction.kind == "deposit" ? Color.green : Color.orange).opacity(0.3), lineWidth: 1)
                                        )
                                )
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        
                        if transaction.transactionStatus == .pendingCustomerInfoUpdate {
                            // KYC Status Section with action button
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.red)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Action Required")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.red)
                                        Text(transaction.transactionStatus.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isLoadingKyc {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Button(action: { onGetKycInfo(transaction.id) }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.up.doc.fill")
                                                    .font(.system(size: 14, weight: .medium))
                                                Text("Upload KYC")
                                                    .font(.system(size: 13, weight: .semibold))
                                            }
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(LinearGradient(
                                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ))
                                            )
                                            .shadow(color: .blue.opacity(0.3), radius: 4, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.red.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        } else {
                            // Regular Status
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)
                                Text("Status:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(transaction.transactionStatus.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(statusColor)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        
                        if let eta = transaction.statusEta {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.blue)
                                Text("ETA:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(eta) seconds")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        
                        // Addresses Section
                        if transaction.from != nil || transaction.to != nil {
                            VStack(spacing: 8) {
                                if let from = transaction.from {
                                    HStack(spacing: 12) {
                                        Image(systemName: "location.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.orange)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("From")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(from.shortAddress)
                                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { onCopy(from) }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                if let to = transaction.to {
                                    HStack(spacing: 12) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.green)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("To")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(to.shortAddress)
                                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { onCopy(to) }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6).opacity(0.3))
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        
                        if let stellarTxId = transaction.stellarTransactionId {
                            HStack(spacing: 12) {
                                Image(systemName: "link.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.purple)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Stellar Transaction")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("\(stellarTxId.prefix(8))...")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.primary)
                                }
                                
                                Spacer()
                                
                                Button(action: { onCopy(stellarTxId) }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        
                        // Timestamps Section
                        if transaction.startedAt != nil || transaction.completedAt != nil {
                            VStack(spacing: 6) {
                                if let startedAt = transaction.startedAt {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar.badge.clock")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                        Text("Started:")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatDate(startedAt))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                    }
                                }
                                
                                if let completedAt = transaction.completedAt {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.green)
                                        Text("Completed:")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(formatDate(completedAt))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6).opacity(0.2))
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
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
                VStack(alignment: .leading, spacing: 0) {
                    // Divider with gradient fade
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color(.systemGray5), Color(.systemGray6).opacity(0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    
                    VStack(spacing: 0) {
                        // ID Section with enhanced styling
                        HStack(spacing: 12) {
                            Image(systemName: "number.square.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Transaction ID")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(transaction.id.prefix(8))...\(transaction.id.suffix(4))")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: { onCopy(transaction.id) }) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6).opacity(0.5))
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        
                        // Type and Status Badge
                        HStack {
                            Label(title, systemImage: title.contains("Deposit") ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(title.contains("Deposit") ? .green : .orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill((title.contains("Deposit") ? Color.green : Color.orange).opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .strokeBorder((title.contains("Deposit") ? Color.green : Color.orange).opacity(0.3), lineWidth: 1)
                                        )
                                )
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)
                                Text(getStatus())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(statusColor)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(statusColor.opacity(0.1))
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        
                        // Started Date
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("Started:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatDate(transaction.startedAt))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                        
                        // Type-specific details
                        if let tx = transaction as? ProcessingAnchorTransaction {
                            // Amounts Section
                            if tx.amountIn != nil || tx.amountOut != nil || tx.amountFee != nil {
                                VStack(spacing: 8) {
                                    if let amountIn = tx.amountIn {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.down.square.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.green)
                                            Text("Amount In:")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(amountIn)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                    }
                                    if let amountOut = tx.amountOut {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.up.square.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.orange)
                                            Text("Amount Out:")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(amountOut)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                    }
                                    if let fee = tx.amountFee {
                                        HStack(spacing: 8) {
                                            Image(systemName: "dollarsign.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.purple)
                                            Text("Fee:")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(fee)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.primary)
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray6).opacity(0.3))
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                            
                            if let completedAt = tx.completedAt {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.green)
                                    Text("Completed:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(formatDate(completedAt))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                            
                            if let stellarTxId = tx.stellarTransactionId {
                                HStack(spacing: 12) {
                                    Image(systemName: "link.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.purple)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Stellar Transaction")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("\(stellarTxId.prefix(8))...")
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { onCopy(stellarTxId) }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }
                        }
                        
                        // Addresses for Deposit/Withdrawal
                        if let depositTx = transaction as? DepositTransaction {
                            VStack(spacing: 8) {
                                if let from = depositTx.from {
                                    HStack(spacing: 12) {
                                        Image(systemName: "location.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.orange)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("From")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(from.shortAddress)
                                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { onCopy(from) }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                if let to = depositTx.to {
                                    HStack(spacing: 12) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.green)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("To")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(to.shortAddress)
                                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { onCopy(to) }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6).opacity(0.3))
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                        
                        if let withdrawalTx = transaction as? WithdrawalTransaction {
                            VStack(spacing: 8) {
                                if let from = withdrawalTx.from {
                                    HStack(spacing: 12) {
                                        Image(systemName: "location.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.orange)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("From")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(from.shortAddress)
                                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { onCopy(from) }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                if let to = withdrawalTx.to {
                                    HStack(spacing: 12) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.green)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("To")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(to.shortAddress)
                                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                                .foregroundStyle(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: { onCopy(to) }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6).opacity(0.3))
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
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

