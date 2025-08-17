//
//  PaymentsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import stellar_wallet_sdk
import stellarsdk
import AlertToast
import Observation

// MARK: - View Model

@Observable
final class PaymentsViewModel {
    // UI State
    var pathPaymentMode = false
    var showSuccessToast = false
    var toastMessage = ""
    var selectedSegment = 0
    
    // Haptic feedback generator
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    init() {
        impactFeedback.prepare()
        selectionFeedback.prepare()
    }
    
    func togglePaymentMode() {
        selectionFeedback.selectionChanged()
        pathPaymentMode.toggle()
    }
    
    func showSuccess(message: String) {
        toastMessage = message
        showSuccessToast = true
        impactFeedback.impactOccurred()
    }
    
    func segmentChanged(to value: Int) {
        selectionFeedback.selectionChanged()
        selectedSegment = value
        pathPaymentMode = value == 1
    }
    
    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        toastMessage = "Address copied to clipboard"
        showSuccessToast = true
        selectionFeedback.selectionChanged()
    }
}

// MARK: - Main View

@MainActor
struct PaymentsView: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var viewModel: PaymentsViewModel
    @State private var isRefreshing = false
    
    init() {
        self._viewModel = State(wrappedValue: PaymentsViewModel())
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                headerSection
                
                if dashboardData.userAssets.isEmpty {
                    EmptyWalletCard()
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    BalancesCard()
                        .environment(dashboardData)
                        .padding(.horizontal)
                        .padding(.top, 16)
                } else {
                    paymentTypeSelector
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    paymentFormSection
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    BalancesCard()
                        .environment(dashboardData)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    RecentPaymentsCard(onCopyAddress: viewModel.copyToClipboard)
                        .environment(dashboardData)
                        .padding(.horizontal)
                        .padding(.top, 16)
                }
                
                // Bottom padding for tab bar
                Color.clear.frame(height: 20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refreshData()
        }
        .toast(isPresenting: $viewModel.showSuccessToast) {
            AlertToast(
                displayMode: .banner(.slide),
                type: .complete(.green),
                title: viewModel.toastMessage
            )
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white, .blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Payments")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    
                    Text("Send payments across the Stellar network")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    // MARK: - Payment Type Selector
    
    private var paymentTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Type")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Picker("Payment Type", selection: $viewModel.selectedSegment) {
                Label("Standard", systemImage: "arrow.right.circle")
                    .tag(0)
                Label("Path Payment", systemImage: "arrow.triangle.swap")
                    .tag(1)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedSegment) { _, newValue in
                viewModel.segmentChanged(to: newValue)
            }
        }
    }
    
    // MARK: - Payment Form Section
    
    @ViewBuilder
    private var paymentFormSection: some View {
        if viewModel.pathPaymentMode {
            ModernSendPathPaymentCard(
                onSuccess: { message in
                    viewModel.showSuccess(message: message)
                }
            )
            .environment(dashboardData)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        } else {
            ModernSendPaymentCard(
                onSuccess: { message in
                    viewModel.showSuccess(message: message)
                }
            )
            .environment(dashboardData)
            .transition(.asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
        }
    }
    
    // MARK: - Helper Methods
    
    private func refreshData() async {
        isRefreshing = true
        await dashboardData.fetchStellarData()
        
        // Add haptic feedback
        await MainActor.run {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isRefreshing = false
        }
    }
}

// MARK: - Empty Wallet Card

struct EmptyWalletCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 8) {
                Text("Wallet Not Funded")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Your account needs to be funded before you can send payments")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

// MARK: - Modern Balances Card

struct BalancesCard: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var isFundingAccount = false
    @State private var fundingError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                
                Text("Balances")
                    .font(.system(size: 18, weight: .semibold))
                
                Spacer()
                
                if dashboardData.isLoadingAssets {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Divider()
            
            if dashboardData.isLoadingAssets {
                HStack {
                    Spacer()
                    ProgressView()
                    Text("Loading balances...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if let error = dashboardData.userAssetsLoadingError {
                errorContent(error: error)
            } else if let fundingError = fundingError {
                VStack(spacing: 12) {
                    Label(fundingError, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    
                    Button(action: { self.fundingError = nil }) {
                        Text("Dismiss")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
            } else if dashboardData.userAssets.isEmpty {
                EmptyStateView(
                    icon: "creditcard.circle",
                    title: "No Assets",
                    message: "Fund your account to start"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(dashboardData.userAssets, id: \.id) { asset in
                        AssetBalanceRow(asset: asset)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    @ViewBuilder
    private func errorContent(error: DashboardDataError) -> some View {
        switch error {
        case .accountNotFound:
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.octagon")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("Account Not Found")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Your account needs to be funded on the Stellar Test Network")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: { Task { await fundAccount() } }) {
                    if isFundingAccount {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Label("Fund on Testnet", systemImage: "arrow.down.circle.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isFundingAccount)
            }
            .padding(.vertical, 8)
            
        case .fetchingError(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundColor(.red)
                
                Text("Error Loading Balances")
                    .font(.system(size: 16, weight: .semibold))
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 8)
        }
    }
    
    private func fundAccount() async {
        isFundingAccount = true
        fundingError = nil
        
        do {
            try await StellarService.fundTestnetAccount(address: dashboardData.userAddress)
            await dashboardData.fetchStellarData()
            
            // Haptic feedback on success
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } catch {
            fundingError = "Failed to fund account: \(error.localizedDescription)"
            
            // Haptic feedback on error
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
        
        isFundingAccount = false
    }
}

// MARK: - Asset Balance Row

struct AssetBalanceRow: View {
    let asset: AssetInfo
    
    private var assetIcon: String {
        return "star.circle.fill"
    }
    
    private var assetColor: Color {
        if asset.id == "native" {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: assetIcon)
                .font(.system(size: 24))
                .foregroundStyle(assetColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.code)
                    .font(.system(size: 14, weight: .semibold))
                
                if let issuedAsset = asset.asset as? IssuedAssetId {
                    Text(issuedAsset.issuer.shortAddress)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(asset.formattedBalance)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recent Payments Card

struct RecentPaymentsCard: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var expandedPaymentIndex: Int?
    var onCopyAddress: ((String) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            
            Divider()
            
            contentView
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    @MainActor
    private var headerView: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
            
            Text("Recent Payments")
                .font(.system(size: 18, weight: .semibold))
            
            Spacer()
            
            if dashboardData.isLoadingRecentPayments {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
    
    @MainActor
    @ViewBuilder
    private var contentView: some View {
        if dashboardData.isLoadingRecentPayments {
            PaymentSkeletonLoader()
        } else if let error = dashboardData.recentPaymentsLoadingError {
            errorContent(error: error)
        } else if dashboardData.recentPayments.isEmpty {
            EmptyStateView(
                icon: "arrow.left.arrow.right.circle",
                title: "No Payments Yet",
                message: "Your payment history will appear here"
            )
        } else {
            paymentsListView
        }
    }
    
    @MainActor
    private var paymentsListView: some View {
        VStack(spacing: 12) {
            ForEach(Array(dashboardData.recentPayments.prefix(5).enumerated()), id: \.offset) { index, payment in
                paymentRowView(payment: payment, index: index)
            }
            
            if dashboardData.recentPayments.count > 5 {
                viewAllButton
            }
        }
    }
    
    private func paymentRowView(payment: PaymentInfo, index: Int) -> some View {
        ModernPaymentRow(
            payment: payment,
            isExpanded: expandedPaymentIndex == index,
            onCopyAddress: onCopyAddress
        )
        .onTapGesture {
            togglePaymentExpansion(index: index)
        }
    }
    
    private var viewAllButton: some View {
        Button(action: {}) {
            Label("View All Payments", systemImage: "arrow.right")
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.top, 8)
    }
    
    private func togglePaymentExpansion(index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedPaymentIndex == index {
                expandedPaymentIndex = nil
            } else {
                expandedPaymentIndex = index
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }
    
    @ViewBuilder
    private func errorContent(error: DashboardDataError) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            switch error {
            case .accountNotFound:
                Text("Account Not Found")
                    .font(.system(size: 16, weight: .semibold))
                Text("No payment history available")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            case .fetchingError(let message):
                Text("Error Loading Payments")
                    .font(.system(size: 16, weight: .semibold))
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Modern Payment Row

struct ModernPaymentRow: View {
    let payment: PaymentInfo
    let isExpanded: Bool
    var onCopyAddress: ((String) -> Void)? = nil
    
    private var directionIcon: String {
        payment.direction == .received ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }
    
    private var directionColor: Color {
        payment.direction == .received ? .green : .blue
    }
    
    private var assetCode: String {
        if payment.asset.id == "native" {
            return "XLM"
        } else if let issuedAsset = payment.asset as? IssuedAssetId {
            return issuedAsset.code
        } else {
            return payment.asset.id
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: directionIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(directionColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(payment.direction == .received ? "Received" : "Sent")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text("·")
                            .foregroundColor(.secondary)
                        
                        Text(payment.amount.amountWithoutTrailingZeros)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        
                        Text(assetCode)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(payment.direction == .received ? "From" : "To") \(payment.contactName ?? payment.address.shortAddress)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(payment.direction == .received ? "From" : "To") Address:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text(payment.address)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if let onCopyAddress = onCopyAddress {
                                Button(action: {
                                    onCopyAddress(payment.address)
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12))
                                        .foregroundColor(.blue)
                                        .padding(4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.leading, 36)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isExpanded ? Color(.systemGray6) : Color.clear)
        )
    }
}

// MARK: - Payment Skeleton Loader

struct PaymentSkeletonLoader: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 28, height: 28)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 120, height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 10)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .opacity(isAnimating ? 0.5 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Placeholder for Modern Send Payment Cards
// These will be implemented in separate files

struct ModernSendPaymentCard: View {
    let onSuccess: (String) -> Void
    @Environment(DashboardData.self) var dashboardData
    
    var body: some View {
        SendPaymentBox()
            .environment(dashboardData)
    }
}

struct ModernSendPathPaymentCard: View {
    let onSuccess: (String) -> Void
    @Environment(DashboardData.self) var dashboardData
    
    var body: some View {
        SendPathPaymentBox()
            .environment(dashboardData)
    }
}

// MARK: - Supporting Views
// EmptyStateView is already defined in Overview.swift

// MARK: - Preview

#Preview {
    PaymentsView()
        .environment(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
}