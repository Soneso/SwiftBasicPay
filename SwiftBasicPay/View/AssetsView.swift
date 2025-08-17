//
//  AssetsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import stellar_wallet_sdk
import Observation
import AlertToast

// MARK: - View Model

@Observable
final class AssetsViewModel {
    private let authService = AuthService()
    
    // UI State
    var showToast = false
    var toastMessage = ""
    var viewErrorMsg: String?
    
    // Asset Management
    var selectedAsset = "Custom asset"
    var assetCode = ""
    var assetIssuer = ""
    var pin = ""
    
    // Loading States
    var isAddingAsset = false
    var isRemovingAsset = false
    
    // Error Messages
    var addAssetErrorMsg: String?
    var removeAssetErrorMsg: String?
    
    // Sheet Management
    var showRemovalSheet = false
    var assetToRemove: IssuedAssetId?
    
    @MainActor
    func addAsset(dashboardData: DashboardData) async {
        addAssetErrorMsg = nil
        
        guard !pin.isEmpty else {
            addAssetErrorMsg = "Please enter your PIN"
            return
        }
        
        isAddingAsset = true
        
        do {
            let assetToAdd = try await getSelectedAsset(dashboardData: dashboardData)
            let userKeyPair = try authService.userKeyPair(pin: pin)
            let success = try await StellarService.addAssetSupport(asset: assetToAdd, userKeyPair: userKeyPair)
            
            if !success {
                addAssetErrorMsg = "Error submitting transaction. Please try again."
                isAddingAsset = false
                return
            }
            
            // Reset form
            assetCode = ""
            assetIssuer = ""
            pin = ""
            selectedAsset = "Custom asset"
            
            // Reload data
            await dashboardData.fetchUserAssets()
            
            // Success feedback
            toastMessage = "Asset added successfully"
            showToast = true
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
        } catch {
            addAssetErrorMsg = error.localizedDescription
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
        
        isAddingAsset = false
    }
    
    @MainActor
    func removeAsset(asset: IssuedAssetId, dashboardData: DashboardData) async {
        removeAssetErrorMsg = nil
        
        guard !pin.isEmpty else {
            removeAssetErrorMsg = "Please enter your PIN"
            return
        }
        
        isRemovingAsset = true
        
        do {
            let userKeyPair = try authService.userKeyPair(pin: pin)
            let success = try await StellarService.removeAssetSupport(asset: asset, userKeyPair: userKeyPair)
            
            if !success {
                removeAssetErrorMsg = "Error removing asset. Please try again."
                isRemovingAsset = false
                return
            }
            
            // Reset state
            pin = ""
            showRemovalSheet = false
            assetToRemove = nil
            
            // Reload data
            await dashboardData.fetchUserAssets()
            
            // Success feedback
            toastMessage = "Asset removed successfully"
            showToast = true
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
        } catch {
            removeAssetErrorMsg = error.localizedDescription
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
        
        isRemovingAsset = false
    }
    
    @MainActor
    private func getSelectedAsset(dashboardData: DashboardData) async throws -> IssuedAssetId {
        if selectedAsset != "Custom asset" {
            let availableAssets = getAvailableAssets(dashboardData: dashboardData)
            guard let selectedIssuedAsset = availableAssets.first(where: { $0.id == selectedAsset }) else {
                throw DemoError.runtimeError("Error finding selected asset")
            }
            return selectedIssuedAsset
        } else {
            let selectedIssuedAsset = try IssuedAssetId(code: assetCode, issuer: assetIssuer)
            
            // Verify issuer exists
            let issuerExists = try await StellarService.accountExists(address: assetIssuer)
            if !issuerExists {
                throw DemoError.runtimeError("Asset issuer not found on the Stellar Network")
            }
            
            return selectedIssuedAsset
        }
    }
    
    @MainActor
    func getAvailableAssets(dashboardData: DashboardData) -> [IssuedAssetId] {
        var result = StellarService.testAnchorAssets
        for asset in dashboardData.userAssets {
            result = result.filter { $0.id != asset.id }
        }
        return result
    }
    
    func prepareRemoval(asset: IssuedAssetId) {
        assetToRemove = asset
        pin = ""
        removeAssetErrorMsg = nil
        showRemovalSheet = true
    }
    
    func cancelRemoval() {
        showRemovalSheet = false
        assetToRemove = nil
        pin = ""
        removeAssetErrorMsg = nil
    }
}

// MARK: - Enhanced Asset Card

struct AssetCard: View {
    let asset: AssetInfo
    let onRemove: (() -> Void)?
    @State private var isExpanded = false
    @State private var isHovered = false
    
    var canRemove: Bool {
        if let issuedAsset = asset.asset as? IssuedAssetId,
           Double(asset.balance) == 0 {
            return true
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(asset.id == "native" ? .orange : .blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.code)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if let issuer = asset.issuer, !issuer.isEmpty {
                                Text(issuer.shortAddress)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(asset.formattedBalance)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Text(asset.code)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        // Chevron indicator for expandability
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(canRemove ? .orange : .blue)
                            .opacity(isHovered ? 1.0 : 0.7)
                            .animation(.easeInOut(duration: 0.2), value: isHovered)
                    }
                }
            }
            .padding(16)
            .background(
                Color(.systemBackground)
                    .overlay(
                        // Subtle highlight on hover
                        isHovered ? Color.blue.opacity(0.03) : Color.clear
                    )
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .background(Color(.systemGray4))
                    
                    VStack(spacing: 8) {
                        if let issuer = asset.issuer {
                            HStack {
                                Text("Issuer:")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Text(issuer)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        
                        HStack {
                            Text("Asset ID:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(asset.id)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        
                        if canRemove, let onRemove = onRemove {
                            Button(action: onRemove) {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Remove Trustline")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red)
                                .cornerRadius(8)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Add Asset Form

struct AddAssetForm: View {
    @Binding var selectedAsset: String
    @Binding var assetCode: String
    @Binding var assetIssuer: String
    @Binding var pin: String
    var availableAssets: [IssuedAssetId]
    var error: String?
    var isLoading: Bool
    var onSubmit: () -> Void
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case assetCode, assetIssuer, pin
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Select Asset")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Menu {
                    ForEach(availableAssets, id: \.id) { asset in
                        Button(asset.id) {
                            selectedAsset = asset.id
                        }
                    }
                    Button("Custom asset") {
                        selectedAsset = "Custom asset"
                    }
                } label: {
                    HStack {
                        Text(selectedAsset)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
            }
            
            if selectedAsset == "Custom asset" {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Asset Code")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., USDC", text: $assetCode)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .assetCode)
                        .onChange(of: assetCode) { _, newValue in
                            if newValue.count > 12 {
                                assetCode = String(newValue.prefix(12))
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Issuer Account")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("G...", text: $assetIssuer)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, design: .monospaced))
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .assetIssuer)
                        .onChange(of: assetIssuer) { _, newValue in
                            if newValue.count > 56 {
                                assetIssuer = String(newValue.prefix(56))
                            }
                        }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("PIN")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                SecureField("6-digit PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .focused($focusedField, equals: .pin)
                    .onChange(of: pin) { _, newValue in
                        if newValue.count > 6 {
                            pin = String(newValue.prefix(6))
                        }
                        pin = pin.filter { $0.isNumber }
                    }
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
            
            Button(action: onSubmit) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                } else {
                    Text("Add Asset")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
            .disabled(isLoading || pin.isEmpty)
        }
    }
}

// MARK: - Asset Removal Sheet

struct AssetRemovalSheet: View {
    let asset: IssuedAssetId
    @Binding var pin: String
    var error: String?
    var isLoading: Bool
    var onConfirm: () -> Void
    var onCancel: () -> Void
    
    @FocusState private var isPinFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Remove Trustline")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    Text("You are about to remove the trustline for:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text(asset.code)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(asset.issuer.shortAddress)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter PIN to confirm")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    SecureField("6-digit PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .focused($isPinFocused)
                        .onChange(of: pin) { _, newValue in
                            if newValue.count > 6 {
                                pin = String(newValue.prefix(6))
                            }
                            pin = pin.filter { $0.isNumber }
                        }
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
                    Button(action: {
                        onCancel()
                        dismiss()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                    }
                    
                    Button(action: onConfirm) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        } else {
                            Text("Remove")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.red)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isLoading || pin.count != 6)
                }
            }
        }
        .padding(24)
        .onAppear {
            isPinFocused = true
        }
    }
}

// MARK: - Main Assets View

@MainActor
struct AssetsView: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var viewModel: AssetsViewModel
    @State private var isRefreshing = false
    
    init() {
        self._viewModel = State(wrappedValue: AssetsViewModel())
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
                
                descriptionCard
                
                if !dashboardData.userAssets.isEmpty {
                    addAssetSection
                }
                
                assetsListSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refreshData()
        }
        .sheet(isPresented: $viewModel.showRemovalSheet) {
            if let asset = viewModel.assetToRemove {
                AssetRemovalSheet(
                    asset: asset,
                    pin: $viewModel.pin,
                    error: viewModel.removeAssetErrorMsg,
                    isLoading: viewModel.isRemovingAsset,
                    onConfirm: {
                        Task {
                            await viewModel.removeAsset(asset: asset, dashboardData: dashboardData)
                        }
                    },
                    onCancel: {
                        viewModel.cancelRemoval()
                    }
                )
            }
        }
        .toast(isPresenting: $viewModel.showToast) {
            AlertToast(type: .regular, title: viewModel.toastMessage)
        }
        .onAppear {
            Task {
                await refreshData()
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Assets")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Manage your Stellar assets")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await refreshData()
                }
            }) {
                Image(systemName: isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .disabled(isRefreshing)
        }
        .padding(.bottom, 8)
    }
    
    private var descriptionCard: some View {
        DashboardCard(title: "About Assets", systemImage: "info.circle.fill") {
            Text("Manage the Stellar assets your account carries trustlines to. Select from pre-suggested assets, or specify your own asset to trust using an asset code and issuer public key. You can also remove trustlines that already exist on your account.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var addAssetSection: some View {
        DashboardCard(title: "Add Trustline", systemImage: "plus.circle.fill") {
            AddAssetForm(
                selectedAsset: $viewModel.selectedAsset,
                assetCode: $viewModel.assetCode,
                assetIssuer: $viewModel.assetIssuer,
                pin: $viewModel.pin,
                availableAssets: viewModel.getAvailableAssets(dashboardData: dashboardData),
                error: viewModel.addAssetErrorMsg,
                isLoading: viewModel.isAddingAsset || dashboardData.isLoadingAssets,
                onSubmit: {
                    Task {
                        await viewModel.addAsset(dashboardData: dashboardData)
                    }
                }
            )
        }
    }
    
    private var assetsListSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Assets")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if !dashboardData.userAssets.isEmpty {
                    Text("\(dashboardData.userAssets.count) total")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            if dashboardData.isLoadingAssets {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading assets...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            } else if let error = dashboardData.userAssetsLoadingError {
                ErrorStateView(error: error)
                    .environment(dashboardData)
            } else if dashboardData.userAssets.isEmpty {
                EmptyStateView(
                    icon: "star.circle.badge.xmark",
                    title: "No Assets Yet",
                    message: "Your account doesn't hold any assets. Start by adding a trustline above."
                )
                .padding(.vertical, 20)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            } else {
                VStack(spacing: 12) {
                    ForEach(dashboardData.userAssets, id: \.id) { asset in
                        AssetCard(
                            asset: asset,
                            onRemove: {
                                if let issuedAsset = asset.asset as? IssuedAssetId {
                                    viewModel.prepareRemoval(asset: issuedAsset)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    private func refreshData() async {
        withAnimation {
            isRefreshing = true
        }
        
        await dashboardData.fetchUserAssets()
        
        if let error = dashboardData.userAssetsLoadingError {
            switch error {
            case .accountNotFound(_):
                break
            case .fetchingError(let message):
                viewModel.viewErrorMsg = message
            }
        }
        
        withAnimation {
            isRefreshing = false
        }
        
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
}

// MARK: - Preview

#Preview {
    AssetsView()
        .environment(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
}