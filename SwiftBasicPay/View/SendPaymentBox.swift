//
//  SendPaymentBox.swift
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
final class SendPaymentViewModel {
    // Form State
    var selectedAsset = "native"
    var selectedRecipient = "Select"
    var recipientAccountId = ""
    var pin = ""
    var amountToSend = ""
    var memoToSend = ""
    
    // UI State
    var errorMessage: String?
    var isSendingPayment = false
    var showSuccessToast = false
    var toastMessage = ""
    var isFormExpanded = false
    
    // Validation State
    var recipientError: String?
    var amountError: String?
    var pinError: String?
    
    // Constants
    static let xlmAssetItem = "native"
    static let selectRecipient = "Select"
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
    
    // MARK: - Form Management
    
    func resetForm() {
        errorMessage = nil
        recipientError = nil
        amountError = nil
        pinError = nil
        recipientAccountId = ""
        amountToSend = ""
        memoToSend = ""
        pin = ""
        selectedRecipient = SendPaymentViewModel.selectRecipient
        selectedAsset = SendPaymentViewModel.xlmAssetItem
        isFormExpanded = false
    }
    
    func expandForm() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isFormExpanded = true
        }
        selectionFeedback.selectionChanged()
    }
    
    func collapseForm() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            resetForm()
        }
        selectionFeedback.selectionChanged()
    }
    
    // MARK: - Validation
    
    func validateRecipient() -> Bool {
        recipientError = nil
        
        if recipientAccountId.isEmpty {
            recipientError = "Recipient address is required"
            return false
        }
        
        if !recipientAccountId.isValidEd25519PublicKey() {
            recipientError = "Invalid Stellar address"
            return false
        }
        
        return true
    }
    
    func validateAmount(maxAmount: Double) -> Bool {
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
        
        if amount > maxAmount {
            amountError = "Insufficient balance (max: \(maxAmount.toStringWithoutTrailingZeros))"
            return false
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
    
    // MARK: - Payment Execution
    
    func sendPayment(userAssets: [AssetInfo], userContacts: [ContactInfo], dashboardData: DashboardData) async {
        // Clear previous errors
        errorMessage = nil
        
        // Set recipient from contact if needed
        if selectedRecipient != SendPaymentViewModel.selectRecipient &&
           selectedRecipient != SendPaymentViewModel.otherRecipient {
            guard let contact = userContacts.first(where: { $0.id == selectedRecipient }) else {
                errorMessage = "Selected contact not found"
                notificationFeedback.notificationOccurred(.error)
                return
            }
            recipientAccountId = contact.accountId
        }
        
        // Find selected asset
        guard let asset = userAssets.first(where: { $0.id == selectedAsset }) else {
            errorMessage = "Selected asset not found"
            notificationFeedback.notificationOccurred(.error)
            return
        }
        
        // Calculate max amount
        let maxAmount = calculateMaxAmount(for: asset)
        
        // Validate all fields
        guard validateRecipient() && validateAmount(maxAmount: maxAmount) && validatePin() else {
            notificationFeedback.notificationOccurred(.error)
            return
        }
        
        isSendingPayment = true
        impactFeedback.impactOccurred()
        
        do {
            // Verify PIN and get user keypair
            let authService = AuthService()
            let userKeyPair = try authService.userKeyPair(pin: pin)
            
            // Check if destination account exists
            let destinationExists = try await StellarService.accountExists(address: recipientAccountId)
            
            // Fund destination if it doesn't exist (testnet only)
            if !destinationExists {
                try await StellarService.fundTestnetAccount(address: recipientAccountId)
            }
            
            // Verify recipient can receive the asset
            if let issuedAsset = asset.asset as? IssuedAssetId, issuedAsset.issuer != recipientAccountId {
                let recipientAssets = try await StellarService.loadAssetsForAddress(address: recipientAccountId)
                if !recipientAssets.contains(where: { $0.id == selectedAsset }) {
                    errorMessage = "Recipient cannot receive \(asset.code)"
                    isSendingPayment = false
                    notificationFeedback.notificationOccurred(.error)
                    return
                }
            }
            
            // Prepare stellar asset
            guard let stellarAssetId = asset.asset as? StellarAssetId else {
                errorMessage = "Invalid asset type"
                isSendingPayment = false
                notificationFeedback.notificationOccurred(.error)
                return
            }
            
            // Prepare memo if provided
            var memo: Memo?
            if !memoToSend.isEmpty {
                memo = try Memo(text: memoToSend)
            }
            
            // Send payment
            let result = try await StellarService.sendPayment(
                destinationAddress: recipientAccountId,
                assetId: stellarAssetId,
                amount: Decimal(Double(amountToSend)!),
                memo: memo,
                userKeyPair: userKeyPair
            )
            
            if result {
                // Success
                toastMessage = "Payment sent successfully!"
                showSuccessToast = true
                notificationFeedback.notificationOccurred(.success)
                
                // Reset form
                resetForm()
                
                // Refresh data
                await dashboardData.fetchStellarData()
            } else {
                errorMessage = "Payment failed. Please try again."
                notificationFeedback.notificationOccurred(.error)
            }
        } catch {
            errorMessage = error.localizedDescription
            notificationFeedback.notificationOccurred(.error)
        }
        
        isSendingPayment = false
    }
    
    func calculateMaxAmount(for asset: AssetInfo) -> Double {
        guard let balance = Double(asset.balance) else { return 0 }
        
        // Reserve 2 XLM for fees if sending XLM
        if asset.id == SendPaymentViewModel.xlmAssetItem {
            return max(0, balance - 2.0)
        }
        
        return balance
    }
    
    // MARK: - UI Helpers
    
    func handleAssetSelection(_ newValue: String) {
        selectionFeedback.selectionChanged()
        selectedAsset = newValue
    }
    
    func handleRecipientSelection(_ newValue: String) {
        selectionFeedback.selectionChanged()
        selectedRecipient = newValue
        
        if newValue != SendPaymentViewModel.selectRecipient {
            expandForm()
        } else {
            collapseForm()
        }
    }
}

// MARK: - Main View

@MainActor
struct SendPaymentBox: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var viewModel: SendPaymentViewModel
    @FocusState private var focusedField: PaymentField?
    
    enum PaymentField {
        case recipient, amount, memo, pin
    }
    
    init() {
        self._viewModel = State(wrappedValue: SendPaymentViewModel())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            
            Divider()
                .padding(.vertical, 16)
            
            if viewModel.isSendingPayment {
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
            Image(systemName: "paperplane.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
            
            Text("Send Payment")
                .font(.system(size: 20, weight: .semibold))
            
            Spacer()
            
            if viewModel.isFormExpanded {
                Button(action: viewModel.collapseForm) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
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
            
            Text("Sending payment...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Please wait while we process your transaction")
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
            // Asset and Recipient Selection
            selectionSection
            
            // Expanded Form Fields
            if viewModel.isFormExpanded {
                expandedFormFields
            }
        }
    }
    
    // MARK: - Selection Section
    
    private var selectionSection: some View {
        VStack(spacing: 16) {
            // Asset Picker
            VStack(alignment: .leading, spacing: 8) {
                Label("Asset", systemImage: "dollarsign.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Menu {
                    ForEach(dashboardData.userAssets, id: \.id) { asset in
                        Button(action: { viewModel.handleAssetSelection(asset.id) }) {
                            Label {
                                Text(asset.code)
                            } icon: {
                                Image(systemName: asset.id == "native" ? "star.circle" : "dollarsign.circle")
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let selectedAsset = dashboardData.userAssets.first(where: { $0.id == viewModel.selectedAsset }) {
                            Image(systemName: selectedAsset.id == "native" ? "star.circle.fill" : "dollarsign.circle.fill")
                                .foregroundStyle(selectedAsset.id == "native" ? .orange : .green)
                            
                            Text(selectedAsset.code)
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("(\(selectedAsset.formattedBalance))")
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
            
            // Recipient Picker
            VStack(alignment: .leading, spacing: 8) {
                Label("Recipient", systemImage: "person.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Menu {
                    ForEach(dashboardData.userContacts, id: \.id) { contact in
                        Button(action: { viewModel.handleRecipientSelection(contact.id) }) {
                            Label(contact.name, systemImage: "person.fill")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { viewModel.handleRecipientSelection(SendPaymentViewModel.otherRecipient) }) {
                        Label("Other Address", systemImage: "plus.circle")
                    }
                } label: {
                    HStack {
                        if viewModel.selectedRecipient == SendPaymentViewModel.selectRecipient {
                            Text("Select Recipient")
                                .foregroundColor(.secondary)
                        } else if viewModel.selectedRecipient == SendPaymentViewModel.otherRecipient {
                            Label("Other Address", systemImage: "plus.circle")
                                .foregroundColor(.primary)
                        } else if let contact = dashboardData.userContacts.first(where: { $0.id == viewModel.selectedRecipient }) {
                            Label(contact.name, systemImage: "person.fill")
                                .foregroundColor(.primary)
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
    }
    
    // MARK: - Expanded Form Fields
    
    @ViewBuilder
    private var expandedFormFields: some View {
        VStack(spacing: 20) {
            // Recipient Address Field (for "Other")
            if viewModel.selectedRecipient == SendPaymentViewModel.otherRecipient {
                recipientAddressField
            }
            
            // Amount Field
            amountField
            
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
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
    }
    
    // MARK: - Form Fields
    
    private var recipientAddressField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Recipient Address", systemImage: "qrcode")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            TextField("G...", text: $viewModel.recipientAccountId)
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
            
            if let error = viewModel.recipientError {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
    }
    
    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Amount", systemImage: "number.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if let asset = dashboardData.userAssets.first(where: { $0.id == viewModel.selectedAsset }) {
                    Text("Max: \(viewModel.calculateMaxAmount(for: asset).toStringWithoutTrailingZeros)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                TextField("0.00", text: $viewModel.amountToSend)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .onChange(of: viewModel.amountToSend) { oldValue, newValue in
                        if newValue != "" && Double(newValue) == nil {
                            viewModel.amountToSend = oldValue
                        }
                        viewModel.amountError = nil
                    }
                
                if let asset = dashboardData.userAssets.first(where: { $0.id == viewModel.selectedAsset }) {
                    Text(asset.code)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(viewModel.amountError != nil ? Color.red : Color.clear, lineWidth: 1)
            )
            
            if let error = viewModel.amountError {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
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
            Button(action: viewModel.collapseForm) {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.red.opacity(0.1))
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
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Actions
    
    private func submitPayment() {
        focusedField = nil
        
        Task {
            await viewModel.sendPayment(
                userAssets: dashboardData.userAssets,
                userContacts: dashboardData.userContacts,
                dashboardData: dashboardData
            )
        }
    }
}

// MARK: - Preview

#Preview {
    SendPaymentBox()
        .environment(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
        .padding()
}