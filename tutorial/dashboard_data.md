# Dashboard data

After login, the users app data is managed by the class [`DashboardData`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/Model/DashboardData.swift).
It is an observable object that can load and hold the user data from the Stellar Network, such as for example the user trusted assets and their balances or recent payments. 

A `DashboardData` instance is created as soon as the user is logged in and set as an environment object in the different SwiftUI views of the app, so that they update automatically as soon as the stored data is updated.

See [`ContentView.swift`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/View/ContentView.swift):

```swift
if let userAddress = userAddress {
    let dashboardData = DashboardData(userAddress: userAddress)
    Dashboard(logoutUser: logoutUser).environmentObject(dashboardData)
}
```

To hold the loaded data in memory `DashboardData` uses different arrays, such as for example:

```swift
/// The assets currently hold by the user.
@Published var userAssets: [AssetInfo] = []

/// A list of recent payments that the user received or sent.
@Published var recentPayments: [PaymentInfo] = []

/// The list of contacts that the user stored locally.
@Published var userContacts: [ContactInfo] = []
```

All SwiftUI views in our app, that have our `DashboardData` instance set as an environment object automatically get updated as soon as the stored data changes. 
For example when the user's assets are loaded from the Stellar Network.

In [`DashboardData.swift`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/Model/DashboardData.swift):

```swift
func fetchUserAssets() async  {
    // ...
    let loadedAssets = try await StellarService.loadAssetsForAddress(address: userAddress)
    Task { @MainActor in
        self.userAssets = loadedAssets
    }
    // ..
}
```

In [`StellarService.swift`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/services/StellarService.swift) :

```swift
/// Loads the assets for a given account specified by `address` from the Stellar Network by using the wallet sdk.
///
/// - Parameters:
///   - address: Stellar account id (G...). E.g. the user's stellar account id
///
public static func loadAssetsForAddress(address:String) async throws -> [AssetInfo] {
    var loadedAssets:[AssetInfo] = []
    let info = try await wallet.stellar.account.getInfo(accountAddress: address)
    for balance in info.balances {
        let asset = try StellarAssetId.fromAssetData(type: balance.assetType,
                                                     code: balance.assetCode,
                                                     issuerAccountId: balance.assetIssuer)
        let assetInfo = AssetInfo(asset: asset, balance: balance.balance)
        loadedAssets.append(assetInfo)
    }
    return loadedAssets
}
```

## Next

Continue with [`Account creation`](account_creation.md).
