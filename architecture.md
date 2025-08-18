# SwiftBasicPay Architecture Documentation

## Overview

SwiftBasicPay is a demonstration iOS wallet application built with SwiftUI that showcases Stellar blockchain payment capabilities. The app follows modern iOS development patterns (iOS 17.5+) and implements a clean MVVM architecture with reactive state management.

## Table of Contents

1. [Technology Stack](#technology-stack)
2. [Architecture Overview](#architecture-overview)
3. [Project Structure](#project-structure)
4. [Core Components](#core-components)
5. [Data Flow](#data-flow)
6. [State Management](#state-management)
7. [Navigation Pattern](#navigation-pattern)
8. [Security Architecture](#security-architecture)
9. [Network Layer](#network-layer)
10. [Best Practices](#best-practices)

## Technology Stack

### Platform
- **iOS 17.5+** (minimum deployment target)
- **SwiftUI** for declarative UI
- **Swift Concurrency** (async/await)
- **@Observable macro** for reactive state management
- **@MainActor** for UI thread safety

### Key Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| stellar-wallet-sdk | 0.6.6+ | High-level Stellar wallet operations |
| stellar-ios-mac-sdk | 3.2.3+ | Core Stellar blockchain SDK |
| SimpleKeychain | 1.3.0 | Secure keychain storage |
| CryptoSwift | 1.8.4 | Cryptographic operations (AES, PBKDF2) |
| AlertToast | 1.3.9 | Toast notifications UI |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         SwiftUI Views                       │
│  (ContentView, Dashboard, Payments, Assets, Transfers, etc.)│
└──────────────────────┬──────────────────────────────────────┘
                       │ @Environment injection
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                      DashboardData                          │
│              (@Observable + @MainActor)                     │
│  ┌──────────┬──────────┬──────────┬──────────┐              │
│  │ Asset    │ Payment  │ Contact  │ KYC      │              │
│  │ Manager  │ Manager  │ Manager  │ Manager  │              │
│  └──────────┴──────────┴──────────┴──────────┘              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                     Service Layer                           │
│  ┌──────────────┬──────────────┬──────────────┐             │
│  │ Stellar      │ Auth         │ Secure       │             │
│  │ Service      │ Service      │ Storage      │             │
│  └──────────────┴──────────────┴──────────────┘             │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Systems                         │
│        (Stellar Network, Anchors, Keychain)                 │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
SwiftBasicPay/
├── Model/                        # Data models and state management
│   └── DashboardData.swift      # Central state coordinator with domain managers
│
├── View/                         # SwiftUI views
│   ├── ContentView.swift        # Root view with auth routing
│   ├── AuthView.swift           # Sign up/sign in interface
│   ├── Dashboard.swift          # Main tab container
│   ├── Overview.swift           # Dashboard overview
│   ├── PaymentsView.swift       # Payment interface
│   ├── SendPaymentBox.swift     # Standard payment component
│   ├── SendPathPaymentBox.swift # Path payment component
│   ├── AssetsView.swift         # Asset management
│   ├── TransfersView.swift      # SEP-6/24 transfers
│   ├── NewTransferView.swift    # New transfer interface
│   ├── TransferHistoryView.swift# Transfer history
│   ├── Sep6DepositStepper.swift # SEP-6 deposit flow
│   ├── Sep6WithdrawalStepper.swift # SEP-6 withdrawal flow
│   ├── Sep12KycFormSheet.swift  # KYC form interface
│   ├── ContactsView.swift       # Contact management
│   ├── KycView.swift            # KYC management
│   └── SettingsView.swift       # App settings
│
├── services/                     # Business logic layer
│   ├── StellarService.swift     # Stellar SDK operations wrapper
│   ├── AuthService.swift        # Authentication management
│   └── SecureStorage.swift      # Keychain wrapper for secure storage
│
├── common/                       # Shared utilities
│   ├── DemoError.swift          # Error definitions
│   ├── Utils.swift              # Helper functions
│   ├── KycFieldInfo.swift       # KYC field definitions
│   └── TransferFieldInfo.swift  # Transfer field definitions
│
├── extensions/                   # Swift extensions
│   ├── Double+BasicPay.swift    # Double formatting
│   └── String+BasicPay.swift    # String utilities
│
└── Assets.xcassets/             # Images and colors
```

## Core Components

### 1. DashboardData (State Coordinator)

Central state management using modern iOS 17+ patterns:

```swift
@MainActor
@Observable
class DashboardData {
    // Domain managers
    private let assetManager: AssetManager
    private let paymentManager: PaymentManager
    private let contactManager: ContactManager
    private let kycManager: KycManager
    
    // Public API (computed properties)
    var userAssets: [AssetInfo] { assetManager.userAssets }
    var recentPayments: [PaymentInfo] { paymentManager.recentPayments }
    // ...
}
```

**Key Features:**
- Coordinates all app state through domain managers
- Provides clean API via computed properties
- Implements performance optimizations (caching, debouncing)
- Thread-safe with @MainActor isolation

### 2. Domain Managers

Each manager handles a specific domain with DataState pattern:

```swift
enum DataState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
}

@MainActor
@Observable
class AssetManager {
    var userAssetsState = DataState<[AssetInfo]>.idle
    // Manages asset-related operations
}
```

### 3. Service Layer

**StellarService**: Wraps Stellar SDK operations
- Account management (creation, funding)
- Payment operations (standard, path payments)
- Asset operations (trust lines, balances)
- SEP protocol implementations (SEP-6, SEP-12, SEP-24)

**AuthService**: Authentication management
- PIN-based authentication
- Biometric authentication support
- Session management

**SecureStorage**: Keychain wrapper
- Encrypted storage for sensitive data
- Keypair management
- Contact and KYC data persistence

## Data Flow

### Standard Flow Pattern

1. **User Interaction** → View captures user action
2. **View Method** → Calls DashboardData method
3. **Manager Delegation** → DashboardData delegates to appropriate manager
4. **Service Call** → Manager calls service layer
5. **External Operation** → Service interacts with external systems
6. **State Update** → Manager updates DataState
7. **UI Update** → View reactively updates via @Observable

### Example: Loading Assets

```swift
// 1. View initiates load
await dashboardData.fetchUserAssets()

// 2. DashboardData delegates to AssetManager
await assetManager.fetchUserAssets()

// 3. AssetManager updates state and calls service
userAssetsState = .loading
let assets = try await StellarService.loadAssetsForAddress(address)

// 4. State updated with result
userAssetsState = .loaded(assets)

// 5. View automatically updates via binding
```

## State Management

### DataState Pattern

All async operations use the DataState enum:

```swift
enum DataState<T> {
    case idle       // Initial state
    case loading    // Operation in progress
    case loaded(T)  // Success with data
    case error(Error) // Failure with error
}
```

### Performance Optimizations

1. **Parallel Data Fetching**
   ```swift
   await withTaskGroup(of: Void.self) { group in
       group.addTask { await self.fetchAssets() }
       group.addTask { await self.fetchPayments() }
   }
   ```

2. **Intelligent Caching with TTL**
   ```swift
   struct CacheEntry<T> {
       let data: T
       let timestamp: Date
       let ttl: TimeInterval
       
       var isExpired: Bool {
           Date().timeIntervalSince(timestamp) > ttl
       }
   }
   ```
   
   **Cache TTL Configuration:**
   - Assets: 30 seconds
   - Payments: 20 seconds  
   - Account existence: 60 seconds
   - Contacts & KYC: No expiry (manual refresh)

3. **Debouncing & Rate Limiting**
   - 500ms debounce on refresh operations
   - Prevents rapid successive API calls
   - Minimum 2-second interval between full refreshes
   - Request deduplication (prevents concurrent identical requests)

## Navigation Pattern

### Tab-Based Navigation

```swift
enum DashboardTab: String, CaseIterable {
    case overview = "Overview"
    case payments = "Payments"
    case assets = "Assets"
    case transfers = "Transfers"
    case contacts = "Contacts"
    case kyc = "KYC"
    case settings = "Settings"
}
```

### Authentication Flow

```
App Launch
    ├── Splash Screen
    ├── Check Authentication State
    │   ├── Not Authenticated → AuthView
    │   │   ├── Sign Up Flow
    │   │   └── Sign In Flow
    │   └── Authenticated → Dashboard
    │       └── Tab Navigation
```

## Security Architecture

### Data Protection

1. **Keychain Storage** (via SimpleKeychain)
   - Encrypted Stellar keypairs
   - Sensitive user data

2. **In-Memory Protection**
   - No logging of secret keys
   - Secure string handling
   - Memory cleanup on logout

3. **Authentication Layers**
   - PIN verification for app access
   - Additional PIN for sensitive operations and for signing Stellar transactions

### Network Security

- HTTPS only for external communications
- Request signing for Stellar transactions

## Network Layer

### Stellar Network Integration

```swift
class StellarService {
    // Singleton instance
    static let shared = StellarService()
    
    // Network configuration
    private let wallet: Wallet
    private let stellar: StellarConfiguration
    
    // Operations
    func sendPayment(...) async throws -> PaymentResult
    func loadAssets(...) async throws -> [AssetInfo]
}
```

### SEP Protocol Support

- **SEP-6**: Deposit/Withdrawal via anchors
- **SEP-12**: KYC/AML data collection
- **SEP-24**: Interactive deposit/withdrawal flows via anchors

### Error Handling

```swift
enum DemoError: LocalizedError {
    case invalidAddress
    case insufficientBalance
    case networkError(String)
    case accountNotFunded
    // ...
}
```

## Best Practices

### Code Organization
- One view per file
- Separate view models when complex
- Group related components

### State Management
- Use @Observable for reactive state
- Implement DataState for async operations
- Cache expensive operations

### Error Handling
- Always provide user feedback
- Use AlertToast for notifications
- Log errors for debugging (not secrets)

### Performance
- Load data lazily when possible
- Implement pagination for large lists
- Use skeleton loaders for perceived performance

## Getting Started

### Prerequisites
1. Xcode 15+
2. iOS 17.5+ simulator/device
3. Stellar testnet account (app can create one)

### Initial Setup
1. Clone repository
2. Open `SwiftBasicPay.xcodeproj`
3. Build with iPhone 15 Plus simulator
4. Run the app

### Development Workflow
1. Create feature branch
2. Implement changes following patterns
3. Test on simulator
4. Submit pull request

## Common Tasks

### Adding a New Feature
1. Create view in `/SwiftBasicPay/View/`
2. Add state to appropriate manager
3. Implement service logic if needed
4. Add navigation entry if main feature

### Modifying State Management
1. Update domain manager
2. Ensure DataState pattern used
3. Update computed properties in DashboardData
4. Views automatically update

### Adding New API Integration
1. Extend StellarService
2. Implement error handling
3. Add caching if appropriate
4. Update relevant manager

## Resources

- [Stellar Documentation](https://developers.stellar.org)
- [Stellar Swift Wallet SDK](https://github.com/Soneso/stellar-swift-wallet-sdk)
- [Project Repository](https://github.com/Soneso/SwiftBasicPay)
