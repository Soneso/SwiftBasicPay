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
    
    /// A list of assets on the Stellar Test Network used to make
    /// testing easier. (to be used with testanchor.stellar.org)
    public static func testnetAssets() -> [IssuedAssetId] {
        return [
            try! IssuedAssetId(code: "SRT", issuer: "GCDNJUBQSX7AJWLJACMJ7I4BC3Z47BQUTMHEICZLE6MU4KQBRYG5JY6B"),
            try! IssuedAssetId(code: "USDC", issuer: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5"),
        ]
    }
    
    public static func addAssetSupport(asset:IssuedAssetId, userKeyPair:SigningKeyPair) async throws -> Bool {
        let stellar = wallet.stellar
        let txBuilder = try await stellar.transaction(sourceAddress: userKeyPair)
        let tx = try txBuilder.addAssetSupport(asset: asset).build()
        stellar.sign(tx: tx, keyPair: userKeyPair)
        return try await stellar.submitTransaction(signedTransaction: tx)
    }
    
    public static func removeAssetSupport(asset:IssuedAssetId, userKeyPair:SigningKeyPair)  async throws -> Bool {
        let stellar = wallet.stellar
        let txBuilder = try await stellar.transaction(sourceAddress: userKeyPair)
        let tx = try txBuilder.removeAssetSupport(asset: asset).build()
        stellar.sign(tx: tx, keyPair: userKeyPair)
        return try await stellar.submitTransaction(signedTransaction: tx)
    }
    
    public static func sendPayment(destinationAddress:String, 
                                   assetId:StellarAssetId,
                                   amount:Decimal,
                                   memo:Memo? = nil,
                                   userKeyPair:SigningKeyPair) async throws -> Bool {
        let stellar = wallet.stellar
        var txBuilder = try await stellar.transaction(sourceAddress: userKeyPair)
        txBuilder = try txBuilder.transfer(destinationAddress: destinationAddress,
                                        assetId: assetId,
                                        amount: amount)
        if let memo = memo {
            // TODO: split memo into memo and memo type as parameters of this `sendPayment´ function
            txBuilder = txBuilder.setMemo(memo: memo)
        }
        
        let tx = try txBuilder.build()
        stellar.sign(tx: tx, keyPair: userKeyPair)
        return try await stellar.submitTransaction(signedTransaction: tx)
        
    }
}

public class AssetInfo: Hashable, Identifiable {
    
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
    
    public var code:String {
        get {
            if let a = asset as? IssuedAssetId {
                return a.code
            } else if let _ = asset as? NativeAssetId {
                return "XLM"
            } else {
                return id
            }
        }
    }
    
    public var issuer:String? {
        get {
            if let a = asset as? IssuedAssetId {
                return a.issuer
            }
            return nil
        }
    }
    
    public static func == (lhs: AssetInfo, rhs: AssetInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
