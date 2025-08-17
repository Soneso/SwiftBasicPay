//
//  StellarService.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 28.06.25.
//

import Foundation
import stellar_wallet_sdk
import stellarsdk

/// Service used to interact with the Stellar Network by using the wallet sdk.
public class StellarService {
    
    public static var wallet = Wallet.testNet
    public static let testAnchorDomain = "anchor-sep-server-dev.stellar.org"//"testanchor.stellar.org"
    
    /// Checks if an account for the given address (account id) exists on the Stellar Network.
    /// 
    /// - Parameters:
    ///   - address: Stellar account id (G...) to check.
    ///
    public static func accountExists(address:String) async throws -> Bool {
        return try await wallet.stellar.account.accountExists(accountAddress: address)
    }
    
    /// Funds the user account on the Stellar Test Network by using Friendbot.
    ///
    /// - Parameters:
    ///   - address: Stellar account id (G...) to be funded. E.g. the user's stellar account id
    ///
    public static func fundTestnetAccount(address:String) async throws {
        return try await wallet.stellar.fundTestNetAccount(address: address)
    }
    
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
    
    /// A list of assets on the Stellar Test Network used to make
    /// testing easier. (to be used with testanchor.stellar.org)
    public static var testAnchorAssets : [IssuedAssetId] {
        return [
            try! IssuedAssetId(code: "SRT", issuer: "GCDNJUBQSX7AJWLJACMJ7I4BC3Z47BQUTMHEICZLE6MU4KQBRYG5JY6B"),
            try! IssuedAssetId(code: "USDC", issuer: "GBBD47IF6LWK7P7MDEVSCWR7DPUWV3NY3DTQEVFL4NAT4AQH3ZLLFLA5"),
        ]
    }
    
    /// Adds a trust line by using the wallet sdk, so that the user can hold the given asset. Requires the user's signing keypair to
    /// sign the transaction before sending it to the Stellar Network. Returns true on success.
    ///
    /// - Parameters:
    ///   - asset: The asset for which the trustline should be added
    ///   - userKeyPair: The user's signing keypair needed to sign the transaction
    ///
    public static func addAssetSupport(asset:IssuedAssetId, userKeyPair:SigningKeyPair) async throws -> Bool {
        let stellar = wallet.stellar
        let txBuilder = try await stellar.transaction(sourceAddress: userKeyPair)
        let tx = try txBuilder.addAssetSupport(asset: asset).build()
        stellar.sign(tx: tx, keyPair: userKeyPair)
        return try await stellar.submitTransaction(signedTransaction: tx)
    }
    
    /// Removes a trust line by using the wallet sdk, so that the user can not hold the given asset any more.
    /// It only works if the user has a balance of 0 for the given asset. Requires the user's signing keypair to
    /// sign the transaction before sending it to the Stellar Network. Returns true on success.
    ///
    /// - Parameters:
    ///   - asset: The asset to remove the trustline for
    ///   - userKeyPair: The user's signing keypair needed to sign the transaction
    ///
    public static func removeAssetSupport(asset:IssuedAssetId, userKeyPair:SigningKeyPair)  async throws -> Bool {
        let stellar = wallet.stellar
        let txBuilder = try await stellar.transaction(sourceAddress: userKeyPair)
        let tx = try txBuilder.removeAssetSupport(asset: asset).build()
        stellar.sign(tx: tx, keyPair: userKeyPair)
        return try await stellar.submitTransaction(signedTransaction: tx)
    }
    
    /// Submits a payment to the Stellar Network by using the wallet sdk. It requires the destinationAddress (account id) of the recipient,
    /// the assetId representing the asset to send, amount, optional memo and the user's signing keypair,
    /// needed to sign the transaction before submission. Returns true on success.
    ///
    /// - Parameters:
    ///   - destinationAddress: Account id of the recipient (G...)
    ///   - assetId: Asset to send
    ///   - assetId: Amount to send
    ///   - memo: Optional memo to attach to the transaction
    ///   - userKeyPair: The user's signing keypair needed to sign the transaction
    ///
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
    
    /// Submits a transaction to the Stellar Network that funds an account for the destination address.
    /// The starting balance must be min. one XLM. The signing user keypair is needed to sign the transaction before submission.
    /// The users stellar address  will be used as the source account of the transaction.
    ///
    /// - Parameters:
    ///   - destinationAddress: Account id of the recipient (G...)
    ///   - startingBalance: The XLM amount that the new account will receive as a starting balance (min. 1 XLM)
    ///   - memo: Optional memo to attach to the transaction
    ///   - userKeyPair: The user's signing keypair needed to sign the transaction
    ///
    public static func createAccount(destinationAddress:String,
                                     startingBalance:Decimal = 1,
                                     memo:Memo?,
                                     userKeyPair:SigningKeyPair) async throws -> Bool {
        
        let stellar = wallet.stellar
        var txBuilder = try await stellar.transaction(sourceAddress: userKeyPair)
        txBuilder = try txBuilder.createAccount(newAccount: try PublicKeyPair(accountId: destinationAddress),
                                            startingBalance: startingBalance)
        
        if let memo = memo {
            txBuilder = txBuilder.setMemo(memo: memo)
        }
        
        let tx = try txBuilder.build()
        stellar.sign(tx: tx, keyPair: userKeyPair)
        return try await stellar.submitTransaction(signedTransaction: tx)
    }
    
    /// Searches for a strict send payment path by using the wallet sdk.
    /// Requires the source asset, the source amount and the destination address of the recipient.
    ///
    /// - Parameters:
    ///   - sourceAsset: The asset you want to send
    ///   - sourceAmount: The amount you want to send
    ///   - destinationAddress: Account id of the recipient
    ///
    public static func findStrictSendPaymentPath(sourceAsset: StellarAssetId,
                                                 sourceAmount:Decimal,
                                                 destinationAddress:String) async throws -> [PaymentPath] {
        
        let stellar = wallet.stellar
        return try await stellar.findStrictSendPathForDestinationAddress(destinationAddress: destinationAddress,
                                                                         sourceAssetId: sourceAsset,
                                                                         sourceAmount: sourceAmount.description)
        
    }
    
    /// Searches for a strict receive payment path by using the wallet sdk. Requires the account id of the sending account,
    /// the destination asset to be received and the destination amount to be recived by the recipient. It will search for all source assets hold by the user (sending account).
    ///
    /// - Parameters:
    ///   - sourceAddress: The account id of the sending account
    ///   - destinationAsset: The asset the recipient should receive
    ///   - destinationAmount: The amount of the destination asset the recipient shopuld receive
    ///
    public static func findStrictReceivePaymentPath(sourceAddress:String,
                                                    destinationAsset:StellarAssetId,
                                                    destinationAmount:Decimal) async throws -> [PaymentPath] {
        let stellar = wallet.stellar
        return try await stellar.findStrictReceivePathForSourceAddress(sourceAddress: sourceAddress,
                                                                       destinationAssetId: destinationAsset,
                                                                       destinationAmount: destinationAmount.description)
    }
    
    /// Sends a strict send path payment by using the wallet sdk. Requires  the asset to send, strict amount to send and the account id of the recipient.
    /// Also requires the the destination asset to be received, the minimum destination amount to be received and the assets path from the
    /// payment path previously obtained by [findStrictSendPaymentPath]. Optionaly you can pass a text memo but the signing user's keypair is needed to sign
    /// the transaction before submission. Returns true on success.
    ///
    /// - Parameters:
    ///   - sendAssetId: The asset you want to send
    ///   - sendAmount: The amount you want to send
    ///   - destinationAddress: Account id of the recipient
    ///   - destinationAssetId: The asset you want the recipient to recieve
    ///   - destinationMinAmount: The min amount you want the recipient to recive
    ///   - path: the transaction path previously received from findStrictSendPaymentPath
    ///   - memo: Optional memo to attache to the transaction
    ///   - userKeyPair: The user's signing keypair for signing the transaction
    ///
    ///
    public static func strictSendPayment(sendAssetId: StellarAssetId,
                                         sendAmount: Decimal,
                                         destinationAddress:String,
                                         destinationAssetId: StellarAssetId,
                                         destinationMinAmount:Decimal,
                                         path: [StellarAssetId],
                                         memo:String? = nil,
                                         userKeyPair: SigningKeyPair) async throws -> Bool {
        let stellar = wallet.stellar
        var txBuilder = try await stellar.transaction(sourceAddress: userKeyPair)
        txBuilder = txBuilder.strictSend(sendAssetId: sendAssetId,
                                         sendAmount: sendAmount,
                                         destinationAddress: destinationAddress,
                                         destinationAssetId: destinationAssetId,
                                         destinationMinAmount: destinationMinAmount,
                                         path: path)
        
        if let memo = memo {
            guard let memoObj = try Memo(text: memo) else {
                throw StellarServiceError.runtimeError("invalid argument 'memo' value: \(memo)")
            }
            txBuilder = txBuilder.setMemo(memo: memoObj)
        }
        let tx = try txBuilder.build()
        stellar.sign(tx: tx, keyPair: userKeyPair)
        return try await stellar.submitTransaction(signedTransaction: tx)
    }
    
    /// Sends a strict receive path payment by using the wallet sdk. Requires  the asset to send, maximum amount to send and the account id of the recipient.
    /// Also requires the the destination asset to be received, the destination amount to be received and the assets path from the
    /// payment path previously obtained by [findStrictReceivePaymentPath]. Optionaly you can pass a text memo but the signing user's keypair is needed to sign
    /// the transaction before submission. Returns true on success.
    ///
    /// - Parameters:
    ///   - sendAssetId: The asset you want to send
    ///   - sendMaxAmount: The maximal amount you want to send
    ///   - destinationAddress: Account id of the recipient
    ///   - destinationAssetId: The asset you want the recipient to recieve
    ///   - destinationAmount: The amount you want the recipient to recive
    ///   - path: the transaction path previously received from findStrictSendPaymentPath
    ///   - memo: Optional memo to attache to the transaction
    ///   - userKeyPair: The user's signing keypair for signing the transaction
    ///
    ///
    public static func strictReceivePayment(sendAssetId: StellarAssetId,
                                            sendMaxAmount: Decimal,
                                            destinationAddress:String,
                                            destinationAssetId: StellarAssetId,
                                            destinationAmount:Decimal,
                                            path: [StellarAssetId],
                                            memo:String? = nil,
                                            userKeyPair: SigningKeyPair) async throws -> Bool {
        let stellar = wallet.stellar
        var txBuilder = try await stellar.transaction(sourceAddress: userKeyPair)
        txBuilder = txBuilder.strictReceive(sendAssetId: sendAssetId,
                                            destinationAddress: destinationAddress,
                                            destinationAssetId: destinationAssetId,
                                            destinationAmount: destinationAmount,
                                            sendMaxAmount: sendMaxAmount,
                                            path: path)
        if let memo = memo {
            guard let memoObj = try Memo(text: memo) else {
                throw StellarServiceError.runtimeError("invalid argument 'memo' value: \(memo)")
            }
            txBuilder = txBuilder.setMemo(memo: memoObj)
        }
        let tx = try txBuilder.build()
        stellar.sign(tx: tx, keyPair: userKeyPair)
        return try await stellar.submitTransaction(signedTransaction: tx)
        
    }
    
    
    /// Loads the list of the 5 most recent payments for given address (account id).
    ///
    /// - Parameters:
    ///   - address: Account id to load the most recent payments for
    ///
    public static func loadRecentPayments(address:String) async throws -> [PaymentInfo] {
        let server = wallet.stellar.server
        let paymentsResponseEnum = await server.payments.getPayments(forAccount: address, order: Order.descending, limit: 5)
        switch paymentsResponseEnum {
        case .success(let page):
            let records = page.records
            var result:[PaymentInfo] = []
            for record in records {
                if let payment = record as? PaymentOperationResponse {
                    let info = try paymentInfoFromPaymentOperationResponse(payment: payment, address: address)
                    result.append(info)
                } else if let payment = record as? AccountCreatedOperationResponse {
                    let info = paymentInfoFromAccountCreatedOperationResponse(payment: payment)
                    result.append(info)
                } else if let payment = record as? PathPaymentStrictReceiveOperationResponse {
                    let info = try paymentInfoFromPathPaymentStrictReceiveOperationResponse(payment: payment, address: address)
                    result.append(info)
                } else if let payment = record as? PathPaymentStrictSendOperationResponse {
                    let info = try paymentInfoFromPathPaymentStrictSendOperationResponse(payment: payment, address: address)
                    result.append(info)
                }
            }
            return result
        case .failure(_):
            throw StellarServiceError.runtimeError("could not load recent payments for \(address)")
        }
    }
    
    public static func getAnchoredAssets(fromAssets:[AssetInfo]) async throws -> [AnchoredAssetInfo] {
        var anchoredAssets:[AnchoredAssetInfo] = []
        let stellar = wallet.stellar
        
        for assetInfo in fromAssets {
            let asset = assetInfo.asset
            var anchorDomain:String?
            
            // We are only interested in issued assets (not XLM)
            if let issuedAsset = asset as? IssuedAssetId {
                let issuerExists = try await stellar.account.accountExists(accountAddress: issuedAsset.issuer)
                if !issuerExists {
                    continue
                }
                // check if it is a known stellar testanchor asset
                // if yes, we can use testanchor.stellar.org as anchor.
                if let _ = testAnchorAssets.filter({$0.code == issuedAsset.code && $0.issuer == issuedAsset.issuer}).first {
                    anchorDomain = testAnchorDomain
                } else {
                    // otherwise load from home domain (maybe it is an anchor ...)
                    let issuerAccountInfo = try await stellar.account.getInfo(accountAddress: issuedAsset.issuer)
                    if let homeDomain = issuerAccountInfo.homeDomain {
                        anchorDomain = homeDomain
                    }
                }
                
                if let domain = anchorDomain {
                    let info = AnchoredAssetInfo(asset: issuedAsset, 
                                                 balance: assetInfo.balance,
                                                 anchor: wallet.anchor(homeDomain: domain))
                    anchoredAssets.append(info)
                }
            }
        }
        
        return anchoredAssets
    }
    
    private static func paymentInfoFromPaymentOperationResponse(payment: PaymentOperationResponse, address:String) throws -> PaymentInfo{
        let direction = payment.to == address ? PaymentDirection.received : PaymentDirection.sent
        let asset = try StellarAssetId.fromAssetData(type: payment.assetType, code: payment.assetCode, issuerAccountId: payment.assetIssuer)
        let address = direction == PaymentDirection.sent ? payment.to : payment.from
        return PaymentInfo(asset: asset, amount: payment.amount, direction: direction, address: address)
    }
    
    private static func paymentInfoFromAccountCreatedOperationResponse(payment: AccountCreatedOperationResponse) -> PaymentInfo{
        
        let amount = payment.startingBalance.description.amountWithoutTrailingZeros
        return PaymentInfo(asset: NativeAssetId(), amount: amount, direction: PaymentDirection.received, address: payment.funder)
    }
    
    private static func paymentInfoFromPathPaymentStrictSendOperationResponse(payment: PathPaymentStrictSendOperationResponse, address:String) throws -> PaymentInfo{
        let direction = payment.to == address ? PaymentDirection.received : PaymentDirection.sent
        let asset = try StellarAssetId.fromAssetData(type: payment.assetType, code: payment.assetCode, issuerAccountId: payment.assetIssuer)
        let address = direction == PaymentDirection.sent ? payment.to : payment.from
        return PaymentInfo(asset: asset, amount: payment.amount, direction: direction, address: address)
    }
    
    
    private static func paymentInfoFromPathPaymentStrictReceiveOperationResponse(payment: PathPaymentStrictReceiveOperationResponse, address:String) throws -> PaymentInfo{
        let direction = payment.to == address ? PaymentDirection.received : PaymentDirection.sent
        let asset = try StellarAssetId.fromAssetData(type: payment.assetType, code: payment.assetCode, issuerAccountId: payment.assetIssuer)
        let address = direction == PaymentDirection.sent ? payment.to : payment.from
        return PaymentInfo(asset: asset, amount: payment.amount, direction: direction, address: address)
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
    
    public var formattedBalance:String {
        self.balance.amountWithoutTrailingZeros
    }
    
    public static func == (lhs: AssetInfo, rhs: AssetInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public class PaymentInfo: Hashable, Identifiable {
    
    let asset:StellarAssetId
    let amount:String
    let direction:PaymentDirection
    let address:String
    var contactName:String?
    
    internal init(asset: StellarAssetId, amount: String, direction: PaymentDirection, address: String, contactName: String? = nil) {
        self.asset = asset
        self.amount = amount
        self.direction = direction
        self.address = address
        self.contactName = contactName
    }
    
    public var description:String {
        let strAmount = amount.amountWithoutTrailingZeros
        let id = asset.id == "native" ? "XLM" : (asset is IssuedAssetId ? (asset as! IssuedAssetId).code : asset.id)
        let dir = direction.rawValue
        let name = contactName ?? address.shortAddress
        return "\(strAmount) \(id) \(dir) \(name)"
    }
    
    public static func == (lhs: PaymentInfo, rhs: PaymentInfo) -> Bool {
        lhs.asset.id == rhs.asset.id &&
        lhs.amount == rhs.amount &&
        lhs.direction == rhs.direction &&
        lhs.address == rhs.address &&
        lhs.contactName == rhs.contactName
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(asset.id)
        hasher.combine(amount)
        hasher.combine(direction)
        hasher.combine(address)
        hasher.combine(contactName)
    }
    
}

public class AnchoredAssetInfo: Hashable, Identifiable {

    public var asset:IssuedAssetId
    public var balance:String
    public var anchor:Anchor
    
    internal init(asset: IssuedAssetId, balance: String, anchor: Anchor) {
        self.asset = asset
        self.balance = balance
        self.anchor = anchor
    }
    
    public var id:String {
        get {
            asset.id
        }
    }
    
    public var code:String {
        get {
            return asset.code
        }
    }
    
    public var issuer:String? {
        get {
            return asset.issuer
        }
    }
    
    public var formattedBalance:String {
        self.balance.amountWithoutTrailingZeros
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(asset.id)
        hasher.combine(balance)
        hasher.combine(anchor.homeDomain)
    }
    
    public static func == (lhs: AnchoredAssetInfo, rhs: AnchoredAssetInfo) -> Bool {
        return lhs.asset.id == rhs.asset.id &&
                lhs.balance == rhs.balance &&
                lhs.anchor.homeDomain == rhs.anchor.homeDomain
    }
    
}

public enum PaymentDirection:String {
    case sent = "sent to"
    case received = "received from"
}

public enum StellarServiceError: Error {
    case runtimeError(String)
}

extension StellarServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .runtimeError(let val):
            return NSLocalizedString(val, comment: "Stellar service error")
        }
    }
}
