//
//  Overview.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import AlertToast
import Observation
import stellar_wallet_sdk

// MARK: - View Model

@Observable
final class OverviewViewModel {
    private let authService = AuthService()
    
    var showToast = false
    var toastMessage = ""
    var viewErrorMsg: String?
    
    var pin = ""
    var showSecret = false
    var secretKey: String?
    var isGettingSecret = false
    var getSecretErrorMsg: String?
    
    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        toastMessage = "Copied to clipboard"
        showToast = true
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    @MainActor
    func getSecretKey() async {
        guard !pin.isEmpty else {
            getSecretErrorMsg = "Please enter your PIN"
            return
        }
        
        isGettingSecret = true
        getSecretErrorMsg = nil
        
        do {
            secretKey = try authService.userKeyPair(pin: pin).secretKey
            pin = ""
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        } catch {
            getSecretErrorMsg = error.localizedDescription
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
        
        isGettingSecret = false
    }
    
    func toggleSecretVisibility() {
        showSecret.toggle()
        if !showSecret {
            secretKey = nil
            pin = ""
            getSecretErrorMsg = nil
        }
    }
    
    func cancelSecretReveal() {
        showSecret = false
        secretKey = nil
        pin = ""
        getSecretErrorMsg = nil
    }
}

// MARK: - Reusable Components

struct DashboardCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content
    var showDivider: Bool = true
    
    init(title: String, systemImage: String, showDivider: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.showDivider = showDivider
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 28, height: 28)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if showDivider {
                Divider()
                    .background(Color(.systemGray4))
            }
            
            content
                .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct MetricView: View {
    let label: String
    let value: String
    let trend: Trend?
    
    enum Trend {
        case up(percentage: Double)
        case down(percentage: Double)
        case neutral
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
        
        var text: String {
            switch self {
            case .up(let percentage): return "+\(Int(percentage))%"
            case .down(let percentage): return "-\(Int(percentage))%"
            case .neutral: return "0%"
            }
        }
    }
    
    init(label: String, value: String, trend: Trend? = nil) {
        self.label = label
        self.value = value
        self.trend = trend
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 8) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(trend.text)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(trend.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(trend.color.opacity(0.1))
                    .cornerRadius(4)
                }
            }
        }
    }
}

struct KeyInfoRow: View {
    let label: String
    let value: String
    let isSecret: Bool
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack {
                Text(value)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(isSecret ? .red : .primary)
                    .lineLimit(isSecret ? 3 : 1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy \(label)")
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct SecurePINInput: View {
    @Binding var pin: String
    var onSubmit: () -> Void
    var onCancel: () -> Void
    var error: String?
    var isLoading: Bool
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter PIN to reveal secret key")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                SecureField("6-digit PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(error != nil ? Color.red : (isFocused ? Color.blue : Color.clear), lineWidth: 2)
                            )
                    )
                    .focused($isFocused)
                    .onChange(of: pin) { oldValue, newValue in
                        if newValue.count > 6 {
                            pin = String(newValue.prefix(6))
                        }
                        pin = pin.filter { $0.isNumber }
                    }
                    .onSubmit(onSubmit)
            }
            
            if let error = error {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 12))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Button(action: onSubmit) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    } else {
                        Text("Reveal")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .disabled(isLoading || pin.count != 6)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Recent Payments View

struct RecentPaymentsView: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var selectedPayment: PaymentInfo?
    var onCopyAddress: ((String) -> Void)? = nil
    
    var body: some View {
        DashboardCard(title: "Recent Payments", systemImage: "arrow.left.arrow.right") {
            if dashboardData.isLoadingRecentPayments {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading payments...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let error = dashboardData.recentPaymentsLoadingError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    switch error {
                    case .accountNotFound(_):
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
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            } else if dashboardData.recentPayments.isEmpty {
                EmptyStateView(
                    icon: "arrow.left.arrow.right.circle",
                    title: "No Payments Yet",
                    message: "Your payment history will appear here"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(dashboardData.recentPayments.prefix(5), id: \.id) { payment in
                        PaymentRow(payment: payment, isSelected: selectedPayment?.id == payment.id, onCopyAddress: onCopyAddress)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedPayment = selectedPayment?.id == payment.id ? nil : payment
                                }
                            }
                    }
                    
                    if dashboardData.recentPayments.count > 5 {
                        Button(action: {}) {
                            Text("View All Payments")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
}

struct PaymentRow: View {
    let payment: PaymentInfo
    let isSelected: Bool
    var onCopyAddress: ((String) -> Void)? = nil
    
    private var assetCode: String {
        if payment.asset.id == "native" {
            return "XLM"
        } else if let issuedAsset = payment.asset as? IssuedAssetId {
            return issuedAsset.code
        } else {
            return payment.asset.id
        }
    }
    
    private var formattedAmount: String {
        payment.amount.amountWithoutTrailingZeros
    }
    
    private var directionIcon: String {
        payment.direction == .received ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }
    
    private var directionColor: Color {
        payment.direction == .received ? .green : .blue
    }
    
    private var counterpartyName: String {
        payment.contactName ?? payment.address.shortAddress
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: directionIcon)
                    .font(.system(size: 24))
                    .foregroundColor(directionColor)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(payment.direction == .received ? "Received" : "Sent")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("• \(payment.direction == .received ? "From" : "To") \(counterpartyName)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    HStack(spacing: 4) {
                        Text(formattedAmount)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(directionColor)
                        
                        Text(assetCode)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(180))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.05) : Color(.systemGray6))
            .cornerRadius(10)
            
            if isSelected {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(payment.direction == .received ? "From" : "To") Address:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text(payment.address)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
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
                    
                    HStack {
                        Text("Direction:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(payment.direction == .received ? "Incoming" : "Outgoing")
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Balances View

struct BalancesView: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var selectedAsset: AssetInfo?
    
    var body: some View {
        DashboardCard(title: "Balances", systemImage: "creditcard.fill") {
            if dashboardData.isLoadingAssets {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading balances...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let error = dashboardData.userAssetsLoadingError {
                ErrorStateView(error: error)
                    .environment(dashboardData)
            } else if dashboardData.userAssets.isEmpty {
                EmptyStateView(
                    icon: "creditcard.trianglebadge.exclamationmark",
                    title: "No Assets",
                    message: "Your account doesn't hold any assets yet"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(dashboardData.userAssets, id: \.id) { asset in
                        AssetRow(asset: asset, isSelected: selectedAsset?.id == asset.id)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedAsset = selectedAsset?.id == asset.id ? nil : asset
                                }
                            }
                    }
                }
            }
        }
    }
}

struct AssetRow: View {
    let asset: AssetInfo
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Asset icon
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(asset.id == "native" ? .orange : .blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(asset.code)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let issuer = asset.issuer, !issuer.isEmpty {
                        Text(issuer.shortAddress)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(asset.formattedBalance)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(asset.code)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(isSelected ? Color.blue.opacity(0.05) : Color(.systemGray6))
            .cornerRadius(10)
            
            if isSelected {
                HStack(spacing: 16) {
                    InfoItem(label: "Asset ID", value: asset.id)
                    if let issuer = asset.issuer, !issuer.isEmpty {
                        InfoItem(label: "Issuer", value: issuer.shortAddress)
                    }
                }
                .padding(.horizontal, 12)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
}

struct InfoItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorStateView: View {
    let error: DashboardDataError
    @State private var isFundingAccount = false
    @State private var fundingError: String?
    @Environment(DashboardData.self) var dashboardData
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
            
            switch error {
            case .accountNotFound(_):
                Text("Account Not Found")
                    .font(.system(size: 16, weight: .semibold))
                Text("Your account does not exist on the Stellar Test Network and needs to be funded")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if let fundingError = fundingError {
                    Text(fundingError)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if isFundingAccount {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.top, 8)
                } else {
                    Button(action: {
                        Task {
                            await fundAccount()
                        }
                    }) {
                        Text("Fund on Testnet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }
                
            case .fetchingError(let message):
                Text("Error Loading Data")
                    .font(.system(size: 16, weight: .semibold))
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
    
    @MainActor
    private func fundAccount() async {
        isFundingAccount = true
        fundingError = nil
        
        do {
            try await StellarService.fundTestnetAccount(address: dashboardData.userAddress)
            
            // Clear the account cache to force a fresh check
            dashboardData.clearAccountCache()
            
            // Force refresh all data (bypasses the 2-second minimum refresh interval)
            await dashboardData.forceRefreshAll()
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        } catch {
            fundingError = "Error funding account: \(error.localizedDescription)"
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
        
        isFundingAccount = false
    }
}

// MARK: - Main Overview View

@MainActor
struct Overview: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var viewModel: OverviewViewModel
    @State private var isRefreshing = false
    @Namespace private var animation
    
    init() {
        self._viewModel = State(wrappedValue: OverviewViewModel())
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                headerSection
                
                if let error = viewModel.viewErrorMsg {
                    ErrorBanner(message: error)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                
                accountOverviewSection
                BalancesView()
                    .environment(dashboardData)
                RecentPaymentsView(onCopyAddress: viewModel.copyToClipboard)
                    .environment(dashboardData)
                accountDetailsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refreshData()
        }
        .toast(isPresenting: $viewModel.showToast) {
            AlertToast(type: .regular, title: viewModel.toastMessage)
        }
        .onAppear {
            Task {
                await initialDataLoad()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Overview")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Manage your Stellar wallet")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
    
    private var accountOverviewSection: some View {
        HStack(spacing: 16) {
            MetricCard(
                title: "Total Assets",
                value: "\(dashboardData.userAssets.count)",
                icon: "banknote.fill",
                color: .blue
            )
            
            MetricCard(
                title: "Recent Payments",
                value: "\(dashboardData.recentPayments.count)",
                icon: "arrow.left.arrow.right",
                color: .green
            )
        }
    }
    
    private var accountDetailsSection: some View {
        DashboardCard(title: "Account Details", systemImage: "person.crop.circle.fill") {
            VStack(spacing: 16) {
                KeyInfoRow(
                    label: "Stellar Address",
                    value: dashboardData.userAddress,
                    isSecret: false,
                    onCopy: {
                        viewModel.copyToClipboard(dashboardData.userAddress)
                    }
                )
                
                Toggle(isOn: $viewModel.showSecret.animation(.easeInOut)) {
                    HStack {
                        Image(systemName: viewModel.showSecret ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text("Secret Key")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .onChange(of: viewModel.showSecret) { _, _ in
                    viewModel.toggleSecretVisibility()
                }
                
                if viewModel.showSecret {
                    VStack(spacing: 16) {
                        if let secretKey = viewModel.secretKey {
                            KeyInfoRow(
                                label: "Secret Key",
                                value: secretKey,
                                isSecret: true,
                                onCopy: {
                                    viewModel.copyToClipboard(secretKey)
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                        } else {
                            SecurePINInput(
                                pin: $viewModel.pin,
                                onSubmit: {
                                    Task {
                                        await viewModel.getSecretKey()
                                    }
                                },
                                onCancel: {
                                    viewModel.cancelSecretReveal()
                                },
                                error: viewModel.getSecretErrorMsg,
                                isLoading: viewModel.isGettingSecret
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                    }
                    .animation(.easeInOut, value: viewModel.secretKey)
                }
            }
        }
    }
    
    private func initialDataLoad() async {
        // Load contacts first so payment history can display contact names
        if dashboardData.userContacts.isEmpty {
            await dashboardData.loadUserContacts()
        }
        if dashboardData.userKycData.isEmpty {
            await dashboardData.loadUserKycData()
        }
        // Then fetch Stellar data including payments
        await dashboardData.fetchStellarData()
    }
    
    private func refreshData() async {
        withAnimation {
            isRefreshing = true
        }
        
        // Force refresh all data (bypasses cache and minimum refresh interval)
        await dashboardData.forceRefreshAll()
        await dashboardData.loadUserContacts()
        await dashboardData.loadUserKycData()
        
        withAnimation {
            isRefreshing = false
        }
        
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct ErrorBanner: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Preview

#Preview {
    Overview()
        .environment(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
}
