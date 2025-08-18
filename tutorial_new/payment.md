# Payment

Payment operations send assets (XLM or tokens) to destination accounts. SwiftBasicPay provides a payment interface with comprehensive validation, contact management, and real-time status updates.

## Modern Payment Architecture

The [`PaymentsView`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/View/PaymentsView.swift) uses iOS 17+ patterns with reactive state management:

<img src="./img/payment/simple_payment.png" alt="Payments view" width="40%">

```swift
@Observable
final class PaymentsViewModel {
    // UI State
    var pathPaymentMode = false
    var showSuccessToast = false
    var selectedSegment = 0
    
    // Haptic feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    func segmentChanged(to value: Int) {
        selectionFeedback.selectionChanged()
        selectedSegment = value
        pathPaymentMode = value == 1
    }
}
```

## Payment Type Selection

Users can choose between standard and path payments:

```swift
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
```

## Send Payment Implementation

### Send Payment Card

The [`SendPaymentBox`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/View/SendPaymentBox.swift) provides the payment form:

```swift
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
    
    // Validation State
    var recipientError: String?
    var amountError: String?
    var pinError: String?
    
    // Loading State
    var isSendingPayment = false
}
```

### Recipient Selection

Users can select from contacts or enter a custom address:

```swift
Menu {
    ForEach(userContacts) { contact in
        Button(action: {
            selectedRecipient = contact.id
            recipientAccountId = contact.accountId
            expandForm()
        }) {
            Label(contact.name, systemImage: "person.circle")
        }
    }
    
    Divider()
    
    Button(action: {
        selectedRecipient = "Other"
        recipientAccountId = ""
        expandForm()
    }) {
        Label("Other (Enter Address)", systemImage: "plus.circle")
    }
} label: {
    HStack {
        Image(systemName: "person.crop.circle")
            .foregroundColor(.blue)
        Text(displayRecipientName)
            .foregroundColor(.primary)
        Spacer()
        Image(systemName: "chevron.down")
            .foregroundColor(.secondary)
    }
    .padding(12)
    .background(Color(.systemGray6))
    .cornerRadius(10)
}
```

### Asset Selection

Display available assets with balances:

```swift
Menu {
    ForEach(userAssets) { asset in
        Button(action: {
            selectedAsset = asset.id
        }) {
            HStack {
                Text(asset.displayName)
                Spacer()
                Text(asset.formattedBalance)
                    .foregroundColor(.secondary)
            }
        }
    }
} label: {
    HStack {
        Image(systemName: "star.circle")
            .foregroundColor(.orange)
        Text(selectedAssetDisplay)
            .foregroundColor(.primary)
        Spacer()
        Text(availableBalance)
            .font(.system(size: 14, design: .rounded))
            .foregroundColor(.secondary)
        Image(systemName: "chevron.down")
            .foregroundColor(.secondary)
    }
    .padding(12)
    .background(Color(.systemGray6))
    .cornerRadius(10)
}
```

### Amount Input with Validation

Modern amount input with real-time validation:

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("Amount")
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.secondary)
    
    HStack {
        TextField("0.00", text: $amountToSend)
            .keyboardType(.decimalPad)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .onChange(of: amountToSend) { _, newValue in
                // Format input to valid decimal
                let filtered = newValue.filter { 
                    $0.isNumber || $0 == "." 
                }
                if filtered != newValue {
                    amountToSend = filtered
                }
                
                // Validate amount
                if let amount = Double(filtered) {
                    if amount > maxAmount {
                        amountError = "Insufficient balance"
                    } else {
                        amountError = nil
                    }
                }
            }
        
        Button("Max") {
            amountToSend = String(maxAmount)
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.blue)
    }
    .padding(12)
    .background(Color(.systemGray6))
    .cornerRadius(10)
    
    if let error = amountError {
        Text(error)
            .font(.system(size: 12))
            .foregroundColor(.red)
    }
}
```

### Payment Validation

Comprehensive validation before submission:

```swift
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
    
    guard let amount = Double(amountToSend) else {
        amountError = "Invalid amount format"
        return false
    }
    
    if amount <= 0 {
        amountError = "Amount must be greater than 0"
        return false
    }
    
    if amount > maxAmount {
        amountError = "Insufficient balance"
        return false
    }
    
    return true
}
```

## Stellar SDK Payment Execution

### Complete Payment Flow

Async payment implementation:

```swift
func sendPayment(userAssets: [AssetInfo], dashboardData: DashboardData) async {
    isSendingPayment = true
    impactFeedback.impactOccurred()
    
    do {
        // 1. Verify PIN and get signing keypair
        let authService = AuthService()
        let userKeyPair = try authService.userKeyPair(pin: pin)
        
        // 2. Check if recipient account exists
        let destinationExists = try await StellarService.accountExists(
            address: recipientAccountId
        )
        
        // 3. Fund if needed (testnet only)
        if !destinationExists {
            try await StellarService.fundTestnetAccount(
                address: recipientAccountId
            )
        }
        
        // 4. Verify recipient can receive the asset
        if let issuedAsset = asset.asset as? IssuedAssetId {
            let recipientAssets = try await StellarService.loadAssetsForAddress(
                address: recipientAccountId
            )
            if !recipientAssets.contains(where: { $0.id == selectedAsset }) {
                throw PaymentError.recipientCannotReceiveAsset
            }
        }
        
        // 5. Create memo if provided
        let memo = memoToSend.isEmpty ? nil : try Memo(text: memoToSend)
        
        // 6. Send payment through wallet SDK
        let result = try await StellarService.sendPayment(
            destinationAddress: recipientAccountId,
            assetId: asset.asset,
            amount: Decimal(Double(amountToSend)!),
            memo: memo,
            userKeyPair: userKeyPair
        )
        
        if result {
            // 7. Refresh data
            await dashboardData.fetchStellarData()
            
            // 8. Show success
            toastMessage = "Payment sent successfully!"
            showSuccessToast = true
            notificationFeedback.notificationOccurred(.success)
            
            // 9. Reset form
            resetForm()
        }
    } catch {
        errorMessage = error.localizedDescription
        notificationFeedback.notificationOccurred(.error)
    }
    
    isSendingPayment = false
}
```

### Stellar Service Integration

Using the wallet SDK for payment submission:

```swift
/// Submits a payment to the Stellar Network using the wallet SDK
public static func sendPayment(
    destinationAddress: String,
    assetId: StellarAssetId,
    amount: Decimal,
    memo: Memo? = nil,
    userKeyPair: SigningKeyPair
) async throws -> Bool {
    let stellar = wallet.stellar
    
    // Build transaction
    var txBuilder = try await stellar.transaction(sourceAddress: userKeyPair)
    
    // Add payment operation
    txBuilder = try txBuilder.transfer(
        destinationAddress: destinationAddress,
        assetId: assetId,
        amount: amount
    )
    
    // Add memo if provided
    if let memo = memo {
        txBuilder = txBuilder.setMemo(memo: memo)
    }
    
    // Build, sign, and submit
    let tx = try txBuilder.build()
    stellar.sign(tx: tx, keyPair: userKeyPair)
    return try await stellar.submitTransaction(signedTransaction: tx)
}
```

## Recent Payments Display

<img src="./img/payment/recent_payments_updated.png" alt="Recent payments" width="40%">

The recent payments card with interactive features:

```swift
struct RecentPaymentsCard: View {
    @Environment(DashboardData.self) var dashboardData
    let onCopyAddress: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                Text("Recent Activity")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            
            if dashboardData.recentPayments.isEmpty {
                EmptyStateView(
                    icon: "tray",
                    title: "No Payments Yet",
                    message: "Your payment history will appear here"
                )
            } else {
                ForEach(dashboardData.recentPayments) { payment in
                    PaymentRow(
                        payment: payment,
                        userAddress: dashboardData.userAddress,
                        onCopyAddress: onCopyAddress
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}
```

### Payment Row Component

```swift
struct PaymentRow: View {
    let payment: PaymentInfo
    let userAddress: String
    let onCopyAddress: (String) -> Void
    
    var isIncoming: Bool {
        payment.toAccount == userAddress
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(isIncoming ? Color.green : Color.red)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: isIncoming ? "arrow.down" : "arrow.up")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.contactName ?? payment.counterpartyAddress.shortAddress)
                    .font(.system(size: 15, weight: .medium))
                
                Text(payment.formattedDate)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(isIncoming ? "+" : "-")\(payment.formattedAmount)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isIncoming ? .green : .red)
                
                Text(payment.assetCode)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onCopyAddress(payment.counterpartyAddress)
        }
    }
}
```

## Loading Recent Payments

Using the wallet SDK to fetch payment history:

```swift
/// Loads recent payments from the Stellar Network
public static func loadRecentPayments(address: String) async throws -> [PaymentInfo] {
    let server = wallet.stellar.server
    
    // Fetch payments in descending order
    let paymentsResponseEnum = await server.payments.getPayments(
        forAccount: address,
        order: Order.descending,
        limit: 20
    )
    
    switch paymentsResponseEnum {
    case .success(let page):
        var result: [PaymentInfo] = []
        
        for record in page.records {
            // Process different payment types
            if let payment = record as? PaymentOperationResponse {
                let info = try paymentInfoFromPaymentOperationResponse(
                    payment: payment,
                    address: address
                )
                result.append(info)
            } else if let payment = record as? AccountCreatedOperationResponse {
                let info = paymentInfoFromAccountCreatedOperationResponse(
                    payment: payment
                )
                result.append(info)
            } else if let payment = record as? PathPaymentStrictReceiveOperationResponse {
                let info = try paymentInfoFromPathPaymentStrictReceiveOperationResponse(
                    payment: payment,
                    address: address
                )
                result.append(info)
            }
        }
        
        return result
        
    case .failure(let error):
        throw StellarServiceError.runtimeError(
            "Could not load recent payments: \(error.localizedDescription)"
        )
    }
}
```

## Key Features

1. **Contact Integration**: Select from saved contacts
2. **Real-time Validation**: Instant feedback on invalid inputs
3. **Asset Verification**: Ensures recipient can receive the asset
4. **Testnet Support**: Auto-funds unfunded accounts
5. **Memo Support**: Optional transaction memos
6. **Haptic Feedback**: Physical feedback for actions
7. **Error Recovery**: Clear error messages and retry options

## Transaction Fees

SwiftBasicPay uses the default base fee (100,000 stroops = 0.00001 XLM):

```swift
// Fee is handled automatically by the wallet SDK
let tx = try txBuilder.build() // Uses default base fee
```

For custom fees:

```swift
txBuilder = txBuilder.setBaseFee(fee: 200) // 200 stroops
```

## Next

Continue with [`Path payment`](path_payment.md).