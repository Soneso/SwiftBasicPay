//
//  StellarService.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 28.06.25.
//

import Foundation
import stellar_wallet_sdk
import stellarsdk

public class StellarService {
    
    public static var wallet = Wallet.testNet
    
    public static func accountExists(address:String) async throws -> Bool {
        return try await wallet.stellar.account.accountExists(accountAddress: address)
    }
    
    public static func fundTestnetAccount(address:String) async throws {
        return try await wallet.stellar.fundTestNetAccount(address: address)
    }
    
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
}

public class AssetInfo {
    
    public var asset:AssetId
    public var balance:String
    
    internal init(asset: any AssetId, balance: String) {
        self.asset = asset
        self.balance = balance
    }
    
    public var id:String {
        get {
            asset.id
        }
    }
}
