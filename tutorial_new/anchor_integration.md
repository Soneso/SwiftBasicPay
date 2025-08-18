# Anchor Integration

Anchors are Stellar-specific on/off-ramps connecting the network to traditional financial systems. They enable deposits (fiat → crypto) and withdrawals (crypto → fiat) through standardized protocols. Read more in the [Stellar docs anchor section](https://developers.stellar.org/docs/learn/fundamentals/anchors).

## Supported Protocols

SwiftBasicPay integrates multiple Stellar Ecosystem Proposals (SEPs):

- **[SEP-1](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0001.md)**: Stellar TOML for anchor information
- **[SEP-10](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0010.md)**: Stellar Web Authentication
- **[SEP-6](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0006.md)**: Deposit and Withdrawal API
- **[SEP-9](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0009.md)**: Standard KYC Fields
- **[SEP-12](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0012.md)**: KYC API
- **[SEP-24](https://github.com/stellar/stellar-protocol/blob/master/ecosystem/sep-0024.md)**: Hosted Deposit and Withdrawal

## Transfers Architecture

The [`TransfersView`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/View/TransfersView.swift) manages anchor operations:

<img src="./img/anchor/transfers_view.png" alt="Transfers view" width="40%">

```swift
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
    
    // Transfer data
    var sep10AuthToken: AuthToken?
    var tomlInfo: TomlInfo?
    var sep6Info: Sep6Info?
    var sep24Info: Sep24Info?
    
    // Anchored assets
    var anchoredAssets: [AnchoredAssetInfo] = []
    var selectedAssetInfo: AnchoredAssetInfo?
}
```

## Finding Anchored Assets

Assets with anchors are identified by their `home_domain`:

```swift
public static func getAnchoredAssets(
    fromAssets: [AssetInfo]
) async throws -> [AnchoredAssetInfo] {
    var anchoredAssets: [AnchoredAssetInfo] = []
    let stellar = wallet.stellar
    
    for assetInfo in fromAssets {
        // Only check issued assets (not XLM)
        if let issuedAsset = asset as? IssuedAssetId {
            var anchorDomain: String?
            
            // Check if it's a known test anchor asset
            if testAnchorAssets.contains(where: { 
                $0.code == issuedAsset.code && 
                $0.issuer == issuedAsset.issuer 
            }) {
                anchorDomain = testAnchorDomain
            } else {
                // Load home domain from issuer account
                let issuerAccountInfo = try await stellar.account.getInfo(
                    accountAddress: issuedAsset.issuer
                )
                anchorDomain = issuerAccountInfo.homeDomain
            }
            
            if let domain = anchorDomain {
                let info = AnchoredAssetInfo(
                    asset: issuedAsset,
                    balance: assetInfo.balance,
                    anchor: wallet.anchor(homeDomain: domain)
                )
                anchoredAssets.append(info)
            }
        }
    }
    
    return anchoredAssets
}
```
<img src="./img/anchor/anchored_assets_dropdown.png" alt="Anchored assets dropdown" width="40%">

## SEP-1: Loading Anchor Information

The stellar.toml file provides anchor configuration:

```swift
@MainActor
private func checkWebAuth(anchor: stellar_wallet_sdk.Anchor) async {
    state = .loading(message: "Loading anchor configuration")
    tomlInfo = nil
    
    do {
        // Load TOML information through wallet SDK
        tomlInfo = try await anchor.sep1
    } catch {
        state = .error("Could not load anchor data: \(error.localizedDescription)")
        return
    }
    
    // Check for required endpoints
    guard tomlInfo?.webAuthEndpoint != nil else {
        state = .error("The anchor does not provide authentication service (SEP-10)")
        return
    }
    
    // Check for transfer servers
    let hasSep6 = tomlInfo?.transferServer != nil
    let hasSep24 = tomlInfo?.transferServerSep24 != nil
    
    if !hasSep6 && !hasSep24 {
        state = .error("Anchor does not support transfers")
        return
    }
    
    state = .pinRequired
}
```

## SEP-10: Web Authentication

Authenticating with the anchor using Stellar account:

<img src="./img/anchor/sep_10_pin.png" alt="SEP-10 PIN" width="40%">

```swift
@MainActor
func authenticateWithPin() async {
    guard !pin.isEmpty else {
        pinError = "Please enter your PIN"
        return
    }
    
    state = .loading(message: "Authenticating with anchor")
    
    // Get user's signing keypair
    var userKeyPair: SigningKeyPair?
    do {
        let authService = AuthService()
        userKeyPair = try authService.userKeyPair(pin: pin)
    } catch {
        pinError = error.localizedDescription
        state = .pinRequired
        return
    }
    
    // Clear PIN after use
    pin = ""
    
    // Authenticate with anchor
    let anchor = selectedAssetInfo.anchor
    do {
        let sep10 = try await anchor.sep10
        
        // Get authentication token
        sep10AuthToken = try await sep10.authenticate(
            userKeyPair: userKeyPair!
        )
        
        // Authentication successful
        await loadTransferInfo()
    } catch {
        pinError = "Authentication failed: \(error.localizedDescription)"
        state = .pinRequired
    }
}
```

## Loading Transfer Information

After authentication, load available transfer options:

```swift
@MainActor
private func loadTransferInfo() async {
    state = .loading(message: "Loading transfer options")
    
    guard let selectedAsset = selectedAssetInfo,
          let authToken = sep10AuthToken else {
        return
    }
    
    let anchor = selectedAsset.anchor
    
    // Load SEP-6 info if available
    if tomlInfo?.transferServer != nil {
        do {
            let sep6 = try await anchor.sep6()
            sep6Info = try await sep6.info(authToken: authToken)
        } catch {
            // SEP-6 not available or failed
        }
    }
    
    // Load SEP-24 info if available
    if tomlInfo?.transferServerSep24 != nil {
        do {
            let sep24 = try await anchor.sep24()
            sep24Info = try await sep24.info()
        } catch {
            // SEP-24 not available or failed
        }
    }
    
    state = .transferReady
}
```

## New Transfer View

The [`NewTransferView`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/View/NewTransferView.swift) displays transfer options:

<img src="./img/anchor/sep_6_methods_buttons.png" alt="Transfer methods" width="40%">

```swift
struct NewTransferView: View {
    private var assetInfo: AnchoredAssetInfo
    private var authToken: AuthToken
    private var sep6Info: Sep6Info?
    private var sep24Info: Sep24Info?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if sep6Info != nil {
                    sep6TransferCard
                }
                
                if sep24Info != nil {
                    sep24TransferCard
                }
            }
        }
    }
}
```

## SEP-6 Deposit

<img src="./img/anchor/sep_6_deposit_stepper.png" alt="SEP-6 deposit stepper" width="40%">

The deposit process using SEP-6:

```swift
private var sep6TransferCard: some View {
    VStack(alignment: .leading, spacing: 16) {
        // Header
        HStack {
            Image(systemName: "6.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text("SEP-6 Transfers")
                    .font(.headline)
                Text("Traditional transfer protocol")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        
        // Deposit button
        if let depositInfo = sep6Info?.deposit,
           let assetDepositInfo = depositInfo[assetInfo.code],
           assetDepositInfo.enabled {
            
            Button(action: { showSep6DepositSheet = true }) {
                transferButton(
                    title: "Deposit",
                    icon: "arrow.down.circle.fill",
                    color: .green
                )
            }
            .sheet(isPresented: $showSep6DepositSheet) {
                Sep6DepositStepper(
                    anchoredAsset: assetInfo,
                    depositInfo: assetDepositInfo,
                    authToken: authToken,
                    savedKycData: savedKycData
                )
            }
        }
    }
}
```
## Transfer data

## SEP-12: KYC Integration

<img src="./img/anchor/sep_6_deposit_kyc_form.png" alt="SEP-6 deposit KYC form" width="40%">


Managing KYC data for transfers:

```swift

```

<img src="./img/anchor/sep_6_deposit_kyc_accepted.png" alt="SEP-6 deposit KYC accepted" width="40%">


## Fee Calculation

Getting fee information before transfers:

```swift
private func loadFeeInfo() async {
    guard let sep6Info = sep6Info,
          sep6Info.fee?.enabled == true else {
        return
    }
    
    do {
        let sep6 = try await anchor.sep6()
        let feeResponse = try await sep6.fee(
            authToken: authToken,
            operation: "deposit",
            assetCode: asset.code,
            amount: amount
        )
        
        feeAmount = feeResponse.fee
    } catch {
        // Handle fee loading error
    }
}
```

<img src="./img/anchor/sep_6_deposit_fee.png" alt="Fee display" width="40%">


## Summary

<img src="./img/anchor/sep_6_depost_summary.png" alt="Deposit sumary" width="40%">

## Success Handling

After successful transfer initiation:

<img src="./img/anchor/sep_6_deposit_submitted.png" alt="Deposit sumary" width="40%">

// TODO: update image

```swift
struct Sep6TransferResponseView: View {
    let response: Sep6TransferResponse
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Transfer Initiated")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let instructions = response.instructions {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions:")
                        .font(.headline)
                    
                    ForEach(instructions, id: \.self) { instruction in
                        Text("• \(instruction)")
                            .font(.body)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            if let eta = response.eta {
                Label("Estimated time: \(eta) seconds", 
                      systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

## Transfer History

<img src="./img/anchor/history_mode.png" alt="Transfer history" width="40%">

Track transfer status and history:

```swift
struct TransferHistoryView: View {
    @State private var transfers: [TransferRecord] = []
    
    var body: some View {
        List(transfers) { transfer in
            TransferRow(transfer: transfer)
        }
        .onAppear {
            Task {
                await loadTransferHistory()
            }
        }
    }
    
    private func loadTransferHistory() async {
        // Load from anchor's transaction endpoint
        let sep6 = try await anchor.sep6()
        let transactions = try await sep6.transactions(
            authToken: authToken,
            assetCode: asset.code
        )
        
        transfers = transactions.transactions
    }
}
```

## SEP-6 Withdrawal

![SEP-6 withdrawal](./img/anchor/sep_6_methods_buttons.png)

```swift
// Withdrawal button
if let withdrawInfo = sep6Info?.withdraw,
   let assetWithdrawInfo = withdrawInfo[assetInfo.code],
   assetWithdrawInfo.enabled {
    
    Button(action: { showSep6WithdrawalSheet = true }) {
        transferButton(
            title: "Withdraw",
            icon: "arrow.up.circle.fill",
            color: .orange
        )
    }
    .sheet(isPresented: $showSep6WithdrawalSheet) {
        Sep6WithdrawalStepper(
            anchoredAsset: assetInfo,
            withdrawInfo: assetWithdrawInfo,
            authToken: authToken,
            savedKycData: savedKycData
        )
    }
}
```

## SEP-24: Interactive Transfers

### Hosted Deposit/Withdrawal

SEP-24 uses web views for the transfer process:

![SEP-24 interactive](./img/anchor/sep_24_deposit_interactive.png)

```swift
private func loadSep24InteractiveUrl(forMode mode: String) async {
    isLoadingSep24InteractiveUrl = true
    loadingSep24InteractiveUrlErrorMessage = nil
    
    do {
        let sep24 = try await assetInfo.anchor.sep24()
        
        // Prepare interactive request
        let request = Sep24InteractiveRequest(
            authToken: authToken,
            assetCode: assetInfo.code,
            assetIssuer: assetInfo.issuer
        )
        
        // Get interactive URL based on mode
        let response: Sep24InteractiveResponse
        if mode == "deposit" {
            response = try await sep24.deposit(request: request)
        } else {
            response = try await sep24.withdraw(request: request)
        }
        
        sep24InteractiveUrl = response.url
        sep24OperationMode = mode
        showSep24InteractiveUrlSheet = true
        
    } catch {
        loadingSep24InteractiveUrlErrorMessage = error.localizedDescription
    }
    
    isLoadingSep24InteractiveUrl = false
}
```

### Interactive Web View

Display the anchor's web interface:

```swift
struct InteractiveWebView: View {
    let url: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            WebView(url: URL(string: url)!)
                .navigationTitle("Complete Transfer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
```

## Key Features

1. **Multi-Protocol Support**: SEP-6 and SEP-24 transfers
2. **Authentication**: SEP-10 web authentication
3. **KYC Management**: SEP-12 data collection
4. **Fee Transparency**: Pre-transfer fee calculation
5. **Status Tracking**: Monitor transfer progress
6. **Interactive Flows**: Web-based transfers via SEP-24
7. **Secure Storage**: KYC data encrypted locally

## Testing with Stellar Test Anchor

Use predefined test assets (SRT, USDC) from `anchor-sep-server-dev.stellar.org`:
1. Add trustline to SRT or USDC
2. Navigate to Transfers tab
3. Select the anchored asset
4. Authenticate with PIN
5. Choose deposit or withdrawal
6. Complete the transfer flow

## Production Considerations

1. **Anchor Discovery**: Implement anchor search/directory
2. **Multi-Anchor Support**: Allow multiple anchors per asset
3. **Transaction Monitoring**: WebSocket connections for updates
4. **Error Recovery**: Retry mechanisms for failed transfers
5. **Compliance**: Implement required regulatory checks
6. **User Education**: Clear explanations of transfer processes

## Next Steps

This completes the SwiftBasicPay tutorial series. You now have a comprehensive understanding of:
- Secure key management
- Stellar account operations
- Asset management and trustlines
- Payment systems (simple and path)
- Anchor integrations for fiat on/off-ramps

For more information, visit the [Stellar documentation](https://developers.stellar.org).