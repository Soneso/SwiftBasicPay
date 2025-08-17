//
//  SendPathPaymentBox.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 23.07.25.
//

import SwiftUI
import stellar_wallet_sdk
import stellarsdk
import AlertToast
import Observation

// MARK: - View Model

@Observable
@MainActor
final class SendPathPaymentViewModel {
    // Form State
    var selectedAssetToSend = "native"
    var selectedAssetToReceive = "native"
    var selectedRecipient = "Select recipient"
    var recipientAccountId = ""
    var pin = ""
    var amountToSend = ""
    var memoToSend = ""
    var strictSend = true
    
    // UI State
    var state: PathPaymentState = .initial
    var errorMessage: String?
    var showSuccessToast = false
    var toastMessage = ""
    var selectedPath: PaymentPath?
    
    // Validation State
    var recipientError: String?
    var amountError: String?
    var pinError: String?
    var pathError: String?
    
    // Assets
    var recipientAssets: [AssetInfo] = []
    
    // Constants
    static let xlmAssetItem = "native"
    static let selectRecipient = "Select recipient"
    static let otherRecipient = "Other"
    
    // Haptic Feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    init() {
        impactFeedback.prepare()
        notificationFeedback.prepare()
        selectionFeedback.prepare()
    }
    
    enum PathPaymentState: Int {
        case initial = 0
        case otherRecipientSelected = 1
        case loadingDestinationAssets = 2
        case destinationAssetsLoaded = 3
        case findingPath = 4
        case pathFound = 5
        case sendingPayment = 6
        
        var isLoading: Bool {
            switch self {
            case .loadingDestinationAssets, .findingPath, .sendingPayment:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Form Management
    
    func resetForm() {
        state = .initial
        errorMessage = nil
        recipientError = nil
        amountError = nil
        pinError = nil
        pathError = nil
        recipientAccountId = ""
        amountToSend = ""
        memoToSend = ""
        pin = ""
        selectedRecipient = SendPathPaymentViewModel.selectRecipient
        selectedAssetToSend = SendPathPaymentViewModel.xlmAssetItem
        selectedAssetToReceive = SendPathPaymentViewModel.xlmAssetItem
        selectedPath = nil
        recipientAssets = []
    }
    
    func handleStrictModeChange(_ newValue: Bool) {
        strictSend = newValue
        selectedPath = nil
        pathError = nil
        selectionFeedback.selectionChanged()
        
        // Reset selected receive asset when switching to strict receive mode
        if !strictSend && !recipientAssets.isEmpty {
            // If current selection is not in recipient assets, select the first one
            if !recipientAssets.contains(where: { $0.id == selectedAssetToReceive }) {
                selectedAssetToReceive = recipientAssets[0].id
            }
        }
    }
    
    // MARK: - Recipient Management
    
    func handleRecipientSelection(_ newValue: String, contacts: [ContactInfo]) async {
        selectionFeedback.selectionChanged()
        selectedRecipient = newValue
        selectedPath = nil
        pathError = nil
        
        if newValue == SendPathPaymentViewModel.selectRecipient {
            recipientAccountId = ""
            state = .initial
            return
        }
        
        if newValue == SendPathPaymentViewModel.otherRecipient {
            recipientAccountId = ""
            state = .otherRecipientSelected
            return
        }
        
        // Find contact
        guard let contact = contacts.first(where: { $0.id == newValue }) else {
            recipientError = "Contact not found"
            return
        }
        
        recipientAccountId = contact.accountId
        await validateAndLoadRecipientAssets()
    }
    
    func validateRecipientAddress() async {
        recipientError = nil
        
        if recipientAccountId.isEmpty {
            recipientError = "Recipient address is required"
            return
        }
        
        if !recipientAccountId.isValidEd25519PublicKey() {
            recipientError = "Invalid Stellar address"
            return
        }
        
        await validateAndLoadRecipientAssets()
    }
    
    private func validateAndLoadRecipientAssets() async {
        state = .loadingDestinationAssets
        
        do {
            let exists = try await StellarService.accountExists(address: recipientAccountId)
            if !exists {
                recipientError = "Account not found on Stellar Network. It needs to be funded first."
                state = .otherRecipientSelected
                return
            }
            
            // Load recipient assets directly
            recipientAssets = try await StellarService.loadAssetsForAddress(address: recipientAccountId)
            
            state = .destinationAssetsLoaded
            
            // Set default selected asset to receive if not already set or invalid
            if !recipientAssets.contains(where: { $0.id == selectedAssetToReceive }) {
                // Default to XLM since every account can receive it
                selectedAssetToReceive = SendPathPaymentViewModel.xlmAssetItem
            }
            
            // Haptic feedback on success
            impactFeedback.impactOccurred()
        } catch {
            recipientError = "Failed to load recipient assets: \(error.localizedDescription)"
            state = .otherRecipientSelected
        }
    }
    
    // MARK: - Path Finding
    
    func findPaymentPath(userAddress: String, userAssets: [AssetInfo]) async {
        // Clear previous errors
        pathError = nil
        amountError = nil
        
        // Validate amount
        guard validateAmount(userAssets: userAssets) else {
            notificationFeedback.notificationOccurred(.error)
            return
        }
        
        state = .findingPath
        impactFeedback.impactOccurred()
        
        // Determine which asset to use
        let assetList = strictSend ? userAssets : recipientAssets
        let assetId = strictSend ? selectedAssetToSend : selectedAssetToReceive
        
        guard let asset = assetList.first(where: { $0.id == assetId }) else {
            pathError = "Selected asset not found"
            state = .destinationAssetsLoaded
            notificationFeedback.notificationOccurred(.error)
            return
        }
        
        guard let stellarAsset = asset.asset as? StellarAssetId else {
            pathError = "Invalid asset type"
            state = .destinationAssetsLoaded
            notificationFeedback.notificationOccurred(.error)
            return
        }
        
        guard let amount = Double(amountToSend) else {
            pathError = "Invalid amount"
            state = .destinationAssetsLoaded
            notificationFeedback.notificationOccurred(.error)
            return
        }
        
        do {
            var paths: [PaymentPath] = []
            
            if strictSend {
                paths = try await StellarService.findStrictSendPaymentPath(
                    sourceAsset: stellarAsset,
                    sourceAmount: Decimal(amount),
                    destinationAddress: recipientAccountId
                )
            } else {
                paths = try await StellarService.findStrictReceivePaymentPath(
                    sourceAddress: userAddress,
                    destinationAsset: stellarAsset,
                    destinationAmount: Decimal(amount)
                )
            }
            
            if paths.isEmpty {
                pathError = "No payment path found. Try a different amount or asset."
                state = .destinationAssetsLoaded
                notificationFeedback.notificationOccurred(.error)
                return
            }
            
            // Select the first path (in a real app, let user choose)
            selectedPath = paths.first
            state = .pathFound
            
            // Success feedback
            notificationFeedback.notificationOccurred(.success)
        } catch {
            pathError = "Failed to find path: \(error.localizedDescription)"
            state = .destinationAssetsLoaded
            notificationFeedback.notificationOccurred(.error)
        }
    }
    
    // MARK: - Payment Execution
    
    func sendPathPayment(dashboardData: DashboardData) async {
        // Clear errors
        errorMessage = nil
        pinError = nil
        
        // Validate PIN
        guard validatePin() else {
            notificationFeedback.notificationOccurred(.error)
            return
        }
        
        guard let path = selectedPath else {
            errorMessage = "No path selected"
            notificationFeedback.notificationOccurred(.error)
            return
        }
        
        state = .sendingPayment
        impactFeedback.impactOccurred()
        
        do {
            // Get user keypair
            let authService = AuthService()
            let userKeyPair = try authService.userKeyPair(pin: pin)
            
            // Prepare memo
            var memoText = ""
            if !memoToSend.isEmpty {
                memoText = memoToSend
            }
            
            // Send payment
            var result = false
            
            if strictSend {
                result = try await StellarService.strictSendPayment(
                    sendAssetId: path.sourceAsset,
                    sendAmount: Decimal(Double(path.sourceAmount)!),
                    destinationAddress: recipientAccountId,
                    destinationAssetId: path.destinationAsset,
                    destinationMinAmount: Decimal(Double(path.destinationAmount)!),
                    path: path.path,
                    memo: memoText,
                    userKeyPair: userKeyPair
                )
            } else {
                result = try await StellarService.strictReceivePayment(
                    sendAssetId: path.sourceAsset,
                    sendMaxAmount: Decimal(Double(path.sourceAmount)!),
                    destinationAddress: recipientAccountId,
                    destinationAssetId: path.destinationAsset,
                    destinationAmount: Decimal(Double(path.destinationAmount)!),
                    path: path.path,
                    memo: memoText,
                    userKeyPair: userKeyPair
                )
            }
            
            if result {
                // Success
                toastMessage = "Path payment sent successfully!"
                showSuccessToast = true
                notificationFeedback.notificationOccurred(.success)
                
                // Reset form
                resetForm()
                
                // Refresh data
                await dashboardData.fetchStellarData()
            } else {
                errorMessage = "Payment failed. Please try again."
                state = .pathFound
                notificationFeedback.notificationOccurred(.error)
            }
        } catch {
            errorMessage = error.localizedDescription
            state = .pathFound
            notificationFeedback.notificationOccurred(.error)
        }
    }
    
    // MARK: - Validation
    
    func validateAmount(userAssets: [AssetInfo]) -> Bool {
        amountError = nil
        
        if amountToSend.isEmpty {
            amountError = "Amount is required"
            return false
        }
        
        guard let amount = Double(amountToSend) else {
            amountError = "Invalid amount format"
            return false
        }
        
        if amount <= 0 {
            amountError = "Amount must be greater than 0"
            return false
        }
        
        // Only validate max for strict send
        if strictSend {
            let maxAmount = calculateMaxAmount(userAssets: userAssets)
            if amount > maxAmount {
                amountError = "Insufficient balance (max: \(maxAmount.toStringWithoutTrailingZeros))"
                return false
            }
        }
        
        return true
    }
    
    func validatePin() -> Bool {
        pinError = nil
        
        if pin.isEmpty {
            pinError = "PIN is required"
            return false
        }
        
        if pin.count != 6 {
            pinError = "PIN must be 6 digits"
            return false
        }
        
        return true
    }
    
    func calculateMaxAmount(userAssets: [AssetInfo]) -> Double {
        guard let asset = userAssets.first(where: { $0.id == selectedAssetToSend }),
              let balance = Double(asset.balance) else { return 0 }
        
        // Reserve 2 XLM for fees
        if asset.id == SendPathPaymentViewModel.xlmAssetItem {
            return max(0, balance - 2.0)
        }
        
        return balance
    }
    
    // MARK: - UI Helpers
    
    var pathDescription: String? {
        guard let path = selectedPath else { return nil }
        
        let sourceAmountStr = path.sourceAmount.amountWithoutTrailingZeros
        let sourceAssetStr = path.sourceAsset.id == "native" ? "XLM" : (path.sourceAsset as? IssuedAssetId)?.code ?? "Unknown"
        let sendEstimated = strictSend ? "" : " (estimated)"
        
        let destAmountStr = path.destinationAmount.amountWithoutTrailingZeros
        let destAssetStr = path.destinationAsset.id == "native" ? "XLM" : (path.destinationAsset as? IssuedAssetId)?.code ?? "Unknown"
        let receiveEstimated = strictSend ? " (estimated)" : ""
        
        return "Send \(sourceAmountStr) \(sourceAssetStr)\(sendEstimated) → Receive \(destAmountStr) \(destAssetStr)\(receiveEstimated)"
    }
}

// MARK: - Main View

@MainActor
struct SendPathPaymentBox: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var viewModel: SendPathPaymentViewModel
    @FocusState private var focusedField: PathPaymentField?
    
    init() {
        self._viewModel = State(wrappedValue: SendPathPaymentViewModel())
    }
    
    enum PathPaymentField {
        case recipient, amount, memo, pin
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            
            Divider()
                .padding(.vertical, 16)
            
            if viewModel.state == .sendingPayment {
                sendingView
            } else {
                formContent
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
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
        HStack {
            Image(systemName: "arrow.triangle.swap")
                .font(.system(size: 24))
                .foregroundStyle(.purple)
                .frame(width: 32, height: 32)
            
            Text("Path Payment")
                .font(.system(size: 20, weight: .semibold))
            
            Spacer()
            
            if viewModel.state != .initial {
                Button(action: viewModel.resetForm) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Sending View
    
    private var sendingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Sending path payment...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Processing your cross-asset transaction")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Form Content
    
    @ViewBuilder
    private var formContent: some View {
        VStack(spacing: 20) {
            // Error Message
            if let error = viewModel.errorMessage {
                errorMessageView(error)
            }
            
            // Recipient Selection
            recipientSection
            
            // Asset Selection (after recipient is selected)
            if viewModel.state.rawValue >= SendPathPaymentViewModel.PathPaymentState.destinationAssetsLoaded.rawValue {
                if viewModel.state == .pathFound {
                    pathConfirmationSection
                } else {
                    assetSelectionSection
                }
            }
        }
    }
    
    // MARK: - Recipient Section
    
    private var recipientSection: some View {
        VStack(spacing: 16) {
            // Recipient Picker
            VStack(alignment: .leading, spacing: 8) {
                Label("Recipient", systemImage: "person.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Menu {
                    ForEach(dashboardData.userContacts, id: \.id) { contact in
                        Button(action: {
                            Task {
                                await viewModel.handleRecipientSelection(contact.id, contacts: dashboardData.userContacts)
                            }
                        }) {
                            Label(contact.name, systemImage: "person.fill")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        Task {
                            await viewModel.handleRecipientSelection(SendPathPaymentViewModel.otherRecipient, contacts: dashboardData.userContacts)
                        }
                    }) {
                        Label("Other Address", systemImage: "plus.circle")
                    }
                } label: {
                    HStack {
                        if viewModel.selectedRecipient == SendPathPaymentViewModel.selectRecipient {
                            Text("Select Recipient")
                                .foregroundColor(.secondary)
                        } else if viewModel.selectedRecipient == SendPathPaymentViewModel.otherRecipient {
                            Label("Other Address", systemImage: "plus.circle")
                                .foregroundColor(.primary)
                        } else if let contact = dashboardData.userContacts.first(where: { $0.id == viewModel.selectedRecipient }) {
                            Label(contact.name, systemImage: "person.fill")
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        if viewModel.state == .loadingDestinationAssets {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .disabled(viewModel.state.isLoading)
            }
            
            // Show address if selected
            if viewModel.state.rawValue >= SendPathPaymentViewModel.PathPaymentState.loadingDestinationAssets.rawValue &&
               viewModel.selectedRecipient != SendPathPaymentViewModel.otherRecipient &&
               !viewModel.recipientAccountId.isEmpty {
                HStack {
                    Image(systemName: "qrcode")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.recipientAccountId.shortAddress)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
            
            // Manual address input for "Other"
            if viewModel.state == .otherRecipientSelected {
                recipientAddressField
            }
            
            // Recipient Error
            if let error = viewModel.recipientError {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
    }
    
    private var recipientAddressField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Enter Stellar address (G...)", text: $viewModel.recipientAccountId)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(viewModel.recipientError != nil ? Color.red : Color.clear, lineWidth: 1)
                    )
                    .focused($focusedField, equals: .recipient)
                    .onChange(of: viewModel.recipientAccountId) { _, newValue in
                        if newValue.count > 56 {
                            viewModel.recipientAccountId = String(newValue.prefix(56))
                        }
                        viewModel.recipientError = nil
                    }
                
                Button(action: {
                    Task {
                        await viewModel.validateRecipientAddress()
                    }
                }) {
                    Text("Verify")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(10)
                }
                .disabled(viewModel.recipientAccountId.isEmpty)
            }
        }
    }
    
    // MARK: - Asset Selection Section
    
    private var assetSelectionSection: some View {
        VStack(spacing: 20) {
            // Strict Mode Toggle
            HStack {
                Label("Strict Send Mode", systemImage: "arrow.right.square")
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { viewModel.strictSend },
                    set: { newValue in
                        viewModel.handleStrictModeChange(newValue)
                    }
                ))
                .labelsHidden()
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(10)
            
            // Asset Selection
            if viewModel.strictSend {
                sendAssetPicker
            } else {
                receiveAssetPicker
            }
            
            // Amount Field
            amountField
            
            // Path Error
            if let error = viewModel.pathError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Find Path Button
            if viewModel.state == .findingPath {
                HStack {
                    Spacer()
                    ProgressView()
                    Text("Finding best path...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 12)
            } else {
                Button(action: findPath) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Find Path")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [.purple, .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                }
                .disabled(viewModel.amountToSend.isEmpty)
            }
        }
    }
    
    private var sendAssetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Send Asset", systemImage: "arrow.up.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Menu {
                ForEach(dashboardData.userAssets.filter { Double($0.balance) ?? 0 > 0 }, id: \.id) { asset in
                    Button(action: { viewModel.selectedAssetToSend = asset.id }) {
                        Label {
                            Text("\(asset.code) (\(asset.formattedBalance))")
                        } icon: {
                            Image(systemName: asset.id == "native" ? "star.circle" : "dollarsign.circle")
                        }
                    }
                }
            } label: {
                HStack {
                    if let asset = dashboardData.userAssets.first(where: { $0.id == viewModel.selectedAssetToSend }) {
                        Image(systemName: asset.id == "native" ? "star.circle.fill" : "dollarsign.circle.fill")
                            .foregroundStyle(asset.id == "native" ? .orange : .green)
                        
                        Text(asset.code)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("(\(asset.formattedBalance))")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }
    
    private var receiveAssetPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Receive Asset", systemImage: "arrow.down.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Menu {
                ForEach(viewModel.recipientAssets, id: \.id) { asset in
                    Button(action: { 
                        viewModel.selectedAssetToReceive = asset.id 
                        viewModel.selectedPath = nil
                        viewModel.pathError = nil
                    }) {
                        Label {
                            Text(asset.code)
                        } icon: {
                            Image(systemName: asset.id == "native" ? "star.circle" : "dollarsign.circle")
                        }
                    }
                }
            } label: {
                HStack {
                    if let asset = viewModel.recipientAssets.first(where: { $0.id == viewModel.selectedAssetToReceive }) {
                        Image(systemName: asset.id == "native" ? "star.circle.fill" : "dollarsign.circle.fill")
                            .foregroundStyle(asset.id == "native" ? .orange : .green)
                        
                        Text(asset.code)
                            .font(.system(size: 16, weight: .medium))
                    } else {
                        Text("Select Asset")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }
    
    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(viewModel.strictSend ? "Amount to Send" : "Amount to Receive", 
                      systemImage: "number.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if viewModel.strictSend {
                    let maxAmount = viewModel.calculateMaxAmount(userAssets: dashboardData.userAssets)
                    Text("Max: \(maxAmount.toStringWithoutTrailingZeros)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            TextField("0.00", text: $viewModel.amountToSend)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .keyboardType(.decimalPad)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(viewModel.amountError != nil ? Color.red : Color.clear, lineWidth: 1)
                )
                .focused($focusedField, equals: .amount)
                .onChange(of: viewModel.amountToSend) { oldValue, newValue in
                    if newValue != "" && Double(newValue) == nil {
                        viewModel.amountToSend = oldValue
                    }
                    viewModel.amountError = nil
                    viewModel.selectedPath = nil
                }
            
            if let error = viewModel.amountError {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Path Confirmation Section
    
    private var pathConfirmationSection: some View {
        VStack(spacing: 20) {
            // Path Details Card
            VStack(alignment: .leading, spacing: 12) {
                Label("Payment Path Found", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
                
                if let pathDesc = viewModel.pathDescription {
                    Text(pathDesc)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                }
                
                // Path visualization
                if let path = viewModel.selectedPath, !path.path.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Route", systemImage: "arrow.triangle.turn.up.right.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("\(path.path.count + 1) hops")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(12)
            
            // Memo Field
            memoField
            
            // PIN Field
            pinField
            
            // Error Message
            if let error = viewModel.errorMessage {
                errorMessageView(error)
            }
            
            // Action Buttons
            actionButtons
        }
    }
    
    private var memoField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Memo (Optional)", systemImage: "text.quote")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            TextField("Add a note...", text: $viewModel.memoToSend)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .focused($focusedField, equals: .memo)
                .onChange(of: viewModel.memoToSend) { _, newValue in
                    if newValue.count > 28 {
                        viewModel.memoToSend = String(newValue.prefix(28))
                    }
                }
            
            Text("\(viewModel.memoToSend.count)/28 characters")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private var pinField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("PIN", systemImage: "lock.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            SecureField("Enter 6-digit PIN", text: $viewModel.pin)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .keyboardType(.numberPad)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(viewModel.pinError != nil ? Color.red : Color.clear, lineWidth: 1)
                )
                .focused($focusedField, equals: .pin)
                .onChange(of: viewModel.pin) { _, newValue in
                    if newValue.count > 6 {
                        viewModel.pin = String(newValue.prefix(6))
                    }
                    viewModel.pin = viewModel.pin.filter { $0.isNumber }
                    viewModel.pinError = nil
                }
            
            if let error = viewModel.pinError {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Error Message View
    
    private func errorMessageView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
            
            Text(message)
                .font(.system(size: 14))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .foregroundColor(.white)
        .padding(12)
        .background(Color.red)
        .cornerRadius(10)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                viewModel.state = .destinationAssetsLoaded
                viewModel.selectedPath = nil
            }) {
                Text("Change Path")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Button(action: submitPayment) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Send")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [.purple, .purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Actions
    
    private func findPath() {
        focusedField = nil
        
        Task {
            await viewModel.findPaymentPath(
                userAddress: dashboardData.userAddress,
                userAssets: dashboardData.userAssets
            )
        }
    }
    
    private func submitPayment() {
        focusedField = nil
        
        Task {
            await viewModel.sendPathPayment(dashboardData: dashboardData)
        }
    }
}

// MARK: - Preview

#Preview {
    SendPathPaymentBox()
        .environment(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
        .padding()
}
