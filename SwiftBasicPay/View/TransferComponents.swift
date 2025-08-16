//
//  TransferComponents.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 15.08.25.
//

import SwiftUI
import stellar_wallet_sdk

// MARK: - Transfer Status Card

struct TransferStatusCard: View {
    let title: String
    let status: String
    let statusColor: Color
    let amount: String?
    let assetCode: String
    let message: String?
    let isExpanded: Binding<Bool>?
    
    init(
        title: String,
        status: String,
        statusColor: Color = .blue,
        amount: String? = nil,
        assetCode: String,
        message: String? = nil,
        isExpanded: Binding<Bool>? = nil
    ) {
        self.title = title
        self.status = status
        self.statusColor = statusColor
        self.amount = amount
        self.assetCode = assetCode
        self.message = message
        self.isExpanded = isExpanded
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(statusColor)
                    }
                }
                
                Spacer()
                
                if let amount = amount {
                    VStack(alignment: .trailing) {
                        Text(amount)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(assetCode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let isExpanded = isExpanded {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                        .animation(.spring(response: 0.3), value: isExpanded.wrappedValue)
                }
            }
            
            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}

// MARK: - Transfer Action Card

struct TransferActionCard: View {
    let type: TransferType
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void
    
    enum TransferType {
        case deposit
        case withdrawal
        
        var title: String {
            switch self {
            case .deposit: return "Deposit"
            case .withdrawal: return "Withdraw"
            }
        }
        
        var icon: String {
            switch self {
            case .deposit: return "arrow.down.circle.fill"
            case .withdrawal: return "arrow.up.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .deposit: return .green
            case .withdrawal: return .orange
            }
        }
        
        var description: String {
            switch self {
            case .deposit: return "Add funds to your account"
            case .withdrawal: return "Transfer funds out"
            }
        }
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(type.color)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(type.color.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            )
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.6)
    }
}

// MARK: - Transfer Detail Row

struct TransferDetailRow: View {
    let label: String
    let value: String
    let showCopyButton: Bool
    let copyValue: String?
    @State private var showCopied = false
    
    init(
        label: String,
        value: String,
        showCopyButton: Bool = false,
        copyValue: String? = nil
    ) {
        self.label = label
        self.value = value
        self.showCopyButton = showCopyButton
        self.copyValue = copyValue
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            
            if showCopyButton {
                Button(action: {
                    UIPasteboard.general.string = copyValue ?? value
                    let impact = UISelectionFeedbackGenerator()
                    impact.selectionChanged()
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCopied = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopied = false
                        }
                    }
                }) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(showCopied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Transfer Empty State

struct TransferEmptyState: View {
    let type: EmptyStateType
    
    enum EmptyStateType {
        case noAssets
        case noTransfers
        case noAnchoredAssets
        
        var icon: String {
            switch self {
            case .noAssets: return "creditcard.trianglebadge.exclamationmark"
            case .noTransfers: return "clock.arrow.circlepath"
            case .noAnchoredAssets: return "link.badge.plus"
            }
        }
        
        var title: String {
            switch self {
            case .noAssets: return "No Assets Found"
            case .noTransfers: return "No Transfer History"
            case .noAnchoredAssets: return "No Anchored Assets"
            }
        }
        
        var message: String {
            switch self {
            case .noAssets: return "Your account needs to be funded before you can make transfers."
            case .noTransfers: return "You haven't made any transfers yet. Start by initiating a new transfer."
            case .noAnchoredAssets: return "Please trust an anchored asset first. You can use the Assets tab to do so."
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: type.icon)
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(type.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(type.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Transfer Progress Indicator

struct TransferProgressIndicator: View {
    let message: String
    let progress: Double?
    
    var body: some View {
        VStack(spacing: 16) {
            if let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.2)
            }
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Transfer Step Indicator

struct TransferStepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let stepTitles: [String]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color.blue : Color(.systemGray4))
                        .frame(height: 4)
                        .animation(.spring(response: 0.3), value: currentStep)
                    
                    if step < totalSteps - 1 {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 4)
            
            if currentStep < stepTitles.count {
                Text(stepTitles[currentStep])
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Transfer Skeleton Loader

struct TransferSkeletonLoader: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 120, height: 16)
                        
                        Spacer()
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 20)
                    }
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 200, height: 12)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                )
                .opacity(isAnimating ? 0.6 : 1.0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Transfer Section Header

struct TransferSectionHeader: View {
    let title: String
    let icon: String?
    let action: (() -> Void)?
    
    init(title: String, icon: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if let action = action {
                Button(action: action) {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Transfer Asset Selector

struct TransferAssetSelector: View {
    @Binding var selectedAsset: String
    let assets: [AnchoredAssetInfo]
    let placeholder: String
    
    private var currentAsset: AnchoredAssetInfo? {
        assets.first { $0.id == selectedAsset }
    }
    
    private var isPlaceholderSelected: Bool {
        selectedAsset == placeholder || currentAsset == nil
    }
    
    var body: some View {
        Menu {
            ForEach(assets, id: \.id) { asset in
                Button(action: {
                    let impact = UISelectionFeedbackGenerator()
                    impact.selectionChanged()
                    selectedAsset = asset.id
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.code)
                                .font(.body)
                            if !asset.asset.issuer.isEmpty {
                                Text(String(asset.asset.issuer.prefix(20)) + "...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if selectedAsset == asset.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        } label: {
            assetSelectorLabel
        }
    }
    
    @ViewBuilder
    private var assetSelectorLabel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label header
            labelHeader
            
            // Selected asset display
            selectedAssetDisplay
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isPlaceholderSelected ? Color(.systemGray4) : Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    @ViewBuilder
    private var labelHeader: some View {
        HStack {
            Label("Select Asset", systemImage: "bitcoinsign.circle.fill")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if !isPlaceholderSelected {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
    
    @ViewBuilder
    private var selectedAssetDisplay: some View {
        HStack {
            // Asset icon
            assetIcon
            
            // Asset details
            assetDetails
            
            Spacer()
            
            // Status indicator
            statusIndicator
        }
    }
    
    @ViewBuilder
    private var assetIcon: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: isPlaceholderSelected ? 
                        [Color(.systemGray5), Color(.systemGray5)] : 
                        [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 48, height: 48)
            
            if let asset = currentAsset {
                Text(String(asset.code.prefix(2)).uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
            } else {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var assetDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentAsset?.code ?? placeholder)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isPlaceholderSelected ? .secondary : .primary)
            
            if let asset = currentAsset {
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(formatIssuer(asset.asset.issuer))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                }
            } else {
                Text("Tap to choose an anchored asset")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        Image(systemName: isPlaceholderSelected ? "chevron.down.circle" : "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(isPlaceholderSelected ? Color.secondary : Color.green)
            .symbolRenderingMode(.hierarchical)
    }
    
    private func formatIssuer(_ issuer: String) -> String {
        if issuer.count > 16 {
            return String(issuer.prefix(8)) + "..." + String(issuer.suffix(4))
        }
        return issuer
    }
}