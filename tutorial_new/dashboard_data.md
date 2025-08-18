# Dashboard Data

After login, the [`DashboardData`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/Model/DashboardData.swift) class manages all user data with a performance-optimized architecture. It provides reactive state management with domain-driven design patterns.

## Modern Architecture

### Core Design Principles

1. **Domain Managers**: Specialized managers for different data domains
2. **DataState Enum**: Unified state management for async operations
3. **Smart Caching**: TTL-based caching with configurable expiration
4. **Performance Optimization**: Parallel data fetching, debouncing, and request deduplication

### State Management with DataState

```swift
/// Unified state management for async data loading
enum DataState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
    
    // Convenience computed properties
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var data: T? {
        if case .loaded(let data) = self { return data }
        return nil
    }
    
    var error: Error? {
        if case .error(let error) = self { return error }
        return nil
    }
}
```

### Cache Implementation

```swift
/// Cache entry with TTL support
struct CacheEntry<T> {
    let data: T
    let timestamp: Date
    let ttl: TimeInterval
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}
```

## DashboardData Class

The central orchestrator for all user data:

```swift
@MainActor
@Observable
class DashboardData {
    
    /// The user's Stellar account id
    let userAddress: String
    
    /// Manager instances for different data domains
    private let assetManager: AssetManager
    private let paymentManager: PaymentManager
    private let contactManager: ContactManager
    private let kycManager: KycManager
    
    /// Performance optimization settings
    private var refreshDebounceTimer: Timer?
    private let refreshDebounceInterval: TimeInterval = 0.5 // 500ms debounce
    private let minimumRefreshInterval: TimeInterval = 2.0 // Min 2s between refreshes
    
    internal init(userAddress: String) {
        self.userAddress = userAddress
        
        // Initialize domain managers
        self.assetManager = AssetManager(userAddress: userAddress)
        self.paymentManager = PaymentManager(userAddress: userAddress)
        self.contactManager = ContactManager()
        self.kycManager = KycManager()
        
        // Set up manager dependencies
        self.paymentManager.setContactManager(self.contactManager)
    }
}
```

### Environment Object Integration

In [`ContentView.swift`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/View/ContentView.swift):

```swift
if let userAddress = userAddress {
    let dashboardData = DashboardData(userAddress: userAddress)
    Dashboard(logoutUser: logoutUser)
        .environmentObject(dashboardData)
}
```

## Domain Managers

### AssetManager

Manages user assets and balances with intelligent caching:

```swift
@MainActor
@Observable
class AssetManager {
    
    /// Data state for user assets
    private(set) var userAssetsState: DataState<[AssetInfo]> = .idle
    
    /// Cache configurations
    private let assetsCacheTTL: TimeInterval = 30.0 // 30 seconds
    private let accountExistenceTTL: TimeInterval = 60.0 // 1 minute
    
    /// Fetch user assets from the Stellar Network
    func fetchUserAssets() async {
        // Check cache first
        if let cached = assetsCache, !cached.isExpired {
            userAssetsState = .loaded(cached.data)
            return
        }
        
        userAssetsState = .loading
        
        do {
            // Use wallet SDK to fetch assets
            let loadedAssets = try await StellarService.loadAssetsForAddress(
                address: userAddress
            )
            
            // Cache the results
            assetsCache = CacheEntry(
                data: loadedAssets, 
                timestamp: Date(), 
                ttl: assetsCacheTTL
            )
            userAssetsState = .loaded(loadedAssets)
            
        } catch {
            userAssetsState = .error(
                DashboardDataError.fetchingError(message: error.localizedDescription)
            )
        }
    }
}
```

### PaymentManager

Handles payment history with smart pagination:

```swift
@MainActor
@Observable
class PaymentManager {
    
    /// Cache TTL - more frequent updates for payments
    private let paymentsCacheTTL: TimeInterval = 20.0 // 20 seconds
    
    /// Pagination support
    private var lastPagingToken: String?
    private let pageLimit = 20 // Load 20 payments at a time
    
    /// Fetch recent payments from the Stellar Network
    func fetchRecentPayments() async {
        // Prevent duplicate concurrent requests
        guard !isCurrentlyLoading else { return }
        
        // Check cache first
        if let cached = paymentsCache, !cached.isExpired {
            recentPaymentsState = .loaded(cached.data)
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        recentPaymentsState = .loading
        
        do {
            // Ensure account existence is checked
            await checkAccountExists()
            
            guard userAccountExists else {
                recentPaymentsState = .error(
                    DashboardDataError.accountNotFound(accountId: userAddress)
                )
                return
            }
            
            // Load payments from Stellar Network
            let loadedPayments = try await StellarService.loadRecentPayments(
                address: userAddress
            )
            
            // Update payment contact names
            if let contactManager = contactManager {
                for payment in loadedPayments {
                    if let contact = contactManager.findContact(
                        byAccountId: payment.address
                    ) {
                        payment.contactName = contact.name
                    }
                }
            }
            
            // Cache the results
            paymentsCache = CacheEntry(
                data: loadedPayments, 
                timestamp: Date(), 
                ttl: paymentsCacheTTL
            )
            recentPaymentsState = .loaded(loadedPayments)
            
        } catch {
            recentPaymentsState = .error(
                DashboardDataError.fetchingError(message: error.localizedDescription)
            )
        }
    }
}
```

## Stellar SDK Integration

The managers use [`StellarService`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/services/StellarService.swift) to interact with the Stellar Network through the wallet SDK:

```swift
/// Load assets using the wallet SDK
public static func loadAssetsForAddress(address:String) async throws -> [AssetInfo] {
    var loadedAssets:[AssetInfo] = []
    
    // Use wallet SDK to get account info
    let info = try await wallet.stellar.account.getInfo(accountAddress: address)
    
    for balance in info.balances {
        let asset = try StellarAssetId.fromAssetData(
            type: balance.assetType,
            code: balance.assetCode,
            issuerAccountId: balance.assetIssuer
        )
        let assetInfo = AssetInfo(asset: asset, balance: balance.balance)
        loadedAssets.append(assetInfo)
    }
    return loadedAssets
}
```

## Performance Optimizations

### Parallel Data Fetching

```swift
func fetchStellarData() async {
    // Check minimum refresh interval
    if let lastRefresh = lastFullRefreshTime,
       Date().timeIntervalSince(lastRefresh) < minimumRefreshInterval {
        return // Skip if called too frequently
    }
    
    // Parallel fetching with TaskGroup
    await withTaskGroup(of: Void.self) { group in
        group.addTask { [weak self] in
            await self?.assetManager.fetchUserAssets()
        }
        
        group.addTask { [weak self] in
            await self?.paymentManager.fetchRecentPayments()
        }
        
        await group.waitForAll()
    }
}
```

### Smart Refresh with Debouncing

```swift
func refreshDataIfNeeded() async {
    // Cancel any pending refresh
    refreshDebounceTimer?.invalidate()
    
    // Debounce: Wait before executing
    await withCheckedContinuation { continuation in
        refreshDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: refreshDebounceInterval, 
            repeats: false
        ) { _ in
            continuation.resume()
        }
    }
    
    // Only refresh expired caches
    await withTaskGroup(of: Void.self) { group in
        if assetManager.shouldRefresh() {
            group.addTask { [weak self] in
                await self?.assetManager.fetchUserAssets()
            }
        }
        
        if paymentManager.shouldRefresh() {
            group.addTask { [weak self] in
                await self?.paymentManager.fetchRecentPayments()
            }
        }
        
        await group.waitForAll()
    }
}
```

## View Integration

Views automatically update when data changes:

```swift
struct Overview: View {
    @EnvironmentObject var dashboardData: DashboardData
    
    var body: some View {
        ScrollView {
            // Assets display with state handling
            switch dashboardData.userAssetsState {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView("Loading assets...")
            case .loaded(let assets):
                ForEach(assets) { asset in
                    AssetRow(asset: asset)
                }
            case .error(let error):
                ErrorView(error: error)
            }
        }
        .onAppear {
            Task {
                await dashboardData.fetchStellarData()
            }
        }
        .refreshable {
            await dashboardData.forceRefreshAll()
        }
    }
}
```

## Key Features

1. **Reactive Updates**: `@Observable` ensures UI updates automatically
2. **Smart Caching**: TTL-based with configurable expiration times
3. **Parallel Loading**: TaskGroup for concurrent data fetching
4. **Debouncing**: Prevents excessive API calls
5. **Error Handling**: Unified error states with DataState enum
6. **Memory Efficient**: Weak references and proper cleanup
7. **Testable**: Domain managers can be tested independently

## Cache Configuration

| Data Type         | TTL       | Rationale                              |
|-------------------|-----------|----------------------------------------|
| Assets            |       30s | Balance changes are important          |
| Payments          |       20s | Recent activity needs frequent updates |
| Account Existence |       60s | Rarely changes once funded             |
| Contacts          | No expiry | Local data, manual refresh             |
| KYC Data          | No expiry | Local data, updated by user            |

## Next

Continue with [`Account creation`](account_creation.md).