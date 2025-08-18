//
//  TransfersView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import stellar_wallet_sdk
import AlertToast

// MARK: - View Model

@Observable
class TransfersViewModel {
    // State management
    enum ViewState: Equatable {
        case initial
        case loading(message: String)
        case pinRequired
        case transferReady
        case error(String)
    }
    
    enum TransferMode: Int, CaseIterable {
        case newTransfer = 1
        case history = 2
        
        var title: String {
            switch self {
            case .newTransfer: return "New"
            case .history: return "History"
            }
        }
    }
    
    // Observable properties
    var mode: TransferMode = .newTransfer
    var state: ViewState = .initial
    var isLoadingAssets = false
    var selectedAssetId = "Select Asset"
    var selectedAssetInfo: AnchoredAssetInfo?
    var pin = ""
    var pinError: String?
    
    // Transfer data
    var sep10AuthToken: AuthToken?
    var tomlInfo: TomlInfo?
    var sep6Info: Sep6Info?
    var sep24Info: Sep24Info?
    
    // Anchored assets loaded directly
    var anchoredAssets: [AnchoredAssetInfo] = []
    var anchoredAssetsError: String?
    
    // Toast notifications
    var showToast = false
    var toastMessage = ""
    var toastType: AlertToast.AlertType = .regular
    
    // Constants
    static let selectAssetPlaceholder = "Select Asset"
    
    // Dependencies
    private let dashboardData: DashboardData
    
    init(dashboardData: DashboardData) {
        self.dashboardData = dashboardData
    }
    
    var hasAnchoredAssets: Bool {
        !anchoredAssets.isEmpty
    }
    
    @MainActor
    var isAccountFunded: Bool {
        !dashboardData.userAssets.isEmpty
    }
    
    // MARK: - Actions
    
    @MainActor
    func loadAnchoredAssets() async {
        isLoadingAssets = true
        anchoredAssetsError = nil
        
        do {
            // Check if account exists
            let accountExists = try await StellarService.accountExists(address: dashboardData.userAddress)
            if !accountExists {
                anchoredAssetsError = "Account not found on the network"
                anchoredAssets = []
                isLoadingAssets = false
                return
            }
            
            // Get anchored assets directly
            let loadedAssets = try await StellarService.getAnchoredAssets(fromAssets: dashboardData.userAssets)
            anchoredAssets = loadedAssets
            
        } catch {
            anchoredAssetsError = "Error loading anchored assets: \(error.localizedDescription)"
            anchoredAssets = []
        }
        
        isLoadingAssets = false
    }
    
    func selectAsset(_ assetId: String) {
        let impact = UISelectionFeedbackGenerator()
        impact.selectionChanged()
        
        selectedAssetId = assetId
        selectedAssetInfo = nil
        pinError = nil
        state = .initial
        
        guard assetId != Self.selectAssetPlaceholder else {
            return
        }
        
        guard let asset = anchoredAssets.first(where: { $0.id == assetId }) else {
            state = .error("Could not find selected asset")
            return
        }
        
        selectedAssetInfo = asset
        Task {
            await checkWebAuth(anchor: asset.anchor)
        }
    }
    
    @MainActor
    private func checkWebAuth(anchor: stellar_wallet_sdk.Anchor) async {
        state = .loading(message: "Loading anchor configuration")
        tomlInfo = nil
        
        do {
            tomlInfo = try await anchor.sep1
        } catch {
            state = .error("Could not load anchor data: \(error.localizedDescription)")
            return
        }
        
        guard tomlInfo?.webAuthEndpoint != nil else {
            state = .error("The anchor does not provide authentication service (SEP-10)")
            return
        }
        
        state = .pinRequired
    }
    
    @MainActor
    func authenticateWithPin() async {
        let feedback = UINotificationFeedbackGenerator()
        
        guard !pin.isEmpty else {
            pinError = "Please enter your PIN"
            feedback.notificationOccurred(.error)
            return
        }
        
        state = .loading(message: "Authenticating with anchor")
        pinError = nil
        
        var userKeyPair: SigningKeyPair?
        do {
            let authService = AuthService()
            userKeyPair = try authService.userKeyPair(pin: pin)
        } catch {
            pinError = error.localizedDescription
            state = .pinRequired
            feedback.notificationOccurred(.error)
            return
        }
        
        pin = ""
        
        guard let selectedAsset = selectedAssetInfo else {
            resetState()
            state = .error("Please select an asset")
            return
        }
        
        let anchor = selectedAsset.anchor
        do {
            let sep10 = try await anchor.sep10
            sep10AuthToken = try await sep10.authenticate(userKeyPair: userKeyPair!)
        } catch {
            pinError = error.localizedDescription
            state = .pinRequired
            feedback.notificationOccurred(.error)
            return
        }
        
        // Load SEP-6 & SEP-24 info
        await loadTransferInfo()
    }
    
    @MainActor
    private func loadTransferInfo() async {
        sep6Info = nil
        sep24Info = nil
        
        state = .loading(message: "Loading transfer services")
        
        let sep6Supported = tomlInfo?.transferServer != nil
        let sep24Supported = tomlInfo?.transferServerSep24 != nil
        
        guard sep6Supported || sep24Supported else {
            state = .error("The anchor does not support SEP-6 or SEP-24 transfers")
            return
        }
        
        var errorMessages: [String] = []
        
        if sep6Supported {
            do {
                sep6Info = try await selectedAssetInfo?.anchor.sep6.info(authToken: sep10AuthToken)
            } catch {
                errorMessages.append("SEP-6: \(error.localizedDescription)")
            }
        }
        
        if sep24Supported {
            do {
                sep24Info = try await selectedAssetInfo?.anchor.sep24.info
            } catch {
                errorMessages.append("SEP-24: \(error.localizedDescription)")
            }
        }
        
        if !errorMessages.isEmpty && sep6Info == nil && sep24Info == nil {
            state = .error(errorMessages.joined(separator: "\n"))
        } else {
            state = .transferReady
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        }
    }
    
    func cancelAuthentication() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        resetState()
    }
    
    func resetState() {
        selectedAssetId = Self.selectAssetPlaceholder
        selectedAssetInfo = nil
        pinError = nil
        sep10AuthToken = nil
        tomlInfo = nil
        sep6Info = nil
        sep24Info = nil
        pin = ""
        state = .initial
    }
    
    func showToast(message: String, type: AlertToast.AlertType = .regular) {
        toastMessage = message
        toastType = type
        showToast = true
    }
}

// MARK: - Main View

@MainActor
struct TransfersView: View {
    
    @Environment(DashboardData.self) var dashboardData
    @State private var viewModel: TransfersViewModel
    
    init() {
        // Will be properly initialized in onAppear
        _viewModel = State(initialValue: TransfersViewModel(dashboardData: DashboardData(userAddress: "")))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern header with gradient
            headerView
            
            if !viewModel.isAccountFunded {
                // Account not funded
                VStack(spacing: 16) {
                    TransferEmptyState(type: .noAssets)
                        .padding()
                }
                .padding(.top, 16)
            } else {
                contentView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Re-initialize with proper dashboardData
            viewModel = TransfersViewModel(dashboardData: dashboardData)
            Task {
                await viewModel.loadAnchoredAssets()
            }
        }
        .refreshable {
            await viewModel.loadAnchoredAssets()
        }
        .toast(isPresenting: .init(
            get: { viewModel.showToast },
            set: { viewModel.showToast = $0 }
        )) {
            AlertToast(
                type: viewModel.toastType,
                title: viewModel.toastMessage
            )
        }
    }
    
    // MARK: - Header View
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 0) {
            // Gradient header background
            LinearGradient(
                colors: [Color.blue.opacity(0.85), Color.blue.opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 80)
            .overlay(
                HStack(alignment: .bottom) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                        
                        Text("Transfers")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    // Tab selector in header
                    HStack(spacing: 4) {
                        ForEach(TransfersViewModel.TransferMode.allCases, id: \.rawValue) { mode in
                            Button(action: {
                                let impact = UISelectionFeedbackGenerator()
                                impact.selectionChanged()
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.mode = mode
                                }
                            }) {
                                Text(mode.title)
                                    .font(.system(size: 14, weight: viewModel.mode == mode ? .semibold : .medium))
                                    .foregroundStyle(viewModel.mode == mode ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(viewModel.mode == mode ? Color.white.opacity(0.25) : Color.clear)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.2))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                , alignment: .bottom
            )
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // Info banner with better styling
            if viewModel.mode == .newTransfer && !viewModel.anchoredAssets.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    
                    Text("Initiate transfers with anchors for your anchored assets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.05), Color.blue.opacity(0.02)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            } else if viewModel.mode == .history && !viewModel.anchoredAssets.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .foregroundStyle(.purple)
                    
                    Text("View your transaction history and details")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.05), Color.purple.opacity(0.02)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
            
            // Main content area
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoadingAssets {
                        TransferProgressIndicator(message: "Loading anchored assets", progress: nil)
                            .padding(.top, 40)
                    } else if let error = viewModel.anchoredAssetsError {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button(action: {
                                Task { await viewModel.loadAnchoredAssets() }
                            }) {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 40)
                    } else if viewModel.anchoredAssets.isEmpty {
                        TransferEmptyState(type: .noAnchoredAssets)
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 20) {
                            // Modern asset selector card
                            TransferAssetSelector(
                                selectedAsset: .init(
                                    get: { viewModel.selectedAssetId },
                                    set: { viewModel.selectAsset($0) }
                                ),
                                assets: viewModel.anchoredAssets,
                                placeholder: TransfersViewModel.selectAssetPlaceholder
                            )
                            
                            // State-based content
                            Group {
                                switch viewModel.state {
                                case .initial:
                                    EmptyView()
                                    
                                case .loading(let message):
                                    TransferProgressIndicator(message: message, progress: nil)
                                        .padding(.top, 20)
                                    
                                case .pinRequired:
                                    pinAuthenticationView
                                        .padding(.top, 20)
                                    
                                case .transferReady:
                                    transferReadyView
                                    
                                case .error(let message):
                                    VStack(spacing: 16) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 48))
                                            .foregroundStyle(.red)
                                        Text(message)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                        Button(action: {
                                            viewModel.resetState()
                                        }) {
                                            Label("Dismiss", systemImage: "xmark.circle")
                                                .fontWeight(.medium)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.red)
                                    }
                                    .padding(.top, 20)
                                }
                            }
                            .animation(.spring(response: 0.3), value: viewModel.state)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }
    
    @ViewBuilder
    private var pinAuthenticationView: some View {
        VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Authentication Required")
                        .font(.headline)
                    Text("Enter your PIN to authenticate with the anchor")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    SecureField("Enter PIN", text: .init(
                        get: { viewModel.pin },
                        set: { newValue in
                            viewModel.pin = String(newValue.prefix(6))
                            viewModel.pinError = nil
                        }
                    ))
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.pinError != nil ? Color.red : Color.clear, lineWidth: 1)
                    )
                    
                    if let error = viewModel.pinError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        Task { await viewModel.authenticateWithPin() }
                    }) {
                        Label("Authenticate", systemImage: "lock.open")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    Button(action: viewModel.cancelAuthentication) {
                        Label("Cancel", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
            )
            .padding(.horizontal)
    }
    
    @ViewBuilder
    private var transferReadyView: some View {
        if let assetInfo = viewModel.selectedAssetInfo,
           let authToken = viewModel.sep10AuthToken {
            ScrollView {
                if viewModel.mode == .newTransfer {
                    NewTransferView(
                        assetInfo: assetInfo,
                        authToken: authToken,
                        sep6Info: viewModel.sep6Info,
                        sep24Info: viewModel.sep24Info,
                        savedKycData: dashboardData.userKycData
                    )
                    .padding(.horizontal)
                } else {
                    TransferHistoryView(
                        assetInfo: assetInfo,
                        authToken: authToken,
                        savedKycData: dashboardData.userKycData,
                        dashboardData: dashboardData
                    )
                    .padding(.horizontal)
                }
            }
        }
    }
}

#Preview {
    TransfersView()
        .environment(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
}
