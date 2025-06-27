//
//  SecureStorage.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import Foundation
import SimpleKeychain
import stellar_wallet_sdk
import CryptoSwift

public class SecureStorage {

    private static let simpleKeychain = SimpleKeychain()
    private static let userSecretStorageKey:String = "secret"
    private static let salt:String = "stellar"
    
    public static var hasUser:Bool {
        get throws {
            try simpleKeychain.hasItem(forKey:userSecretStorageKey)
        }
    }
    
    public static func storeUserKeyPair(userSigningKeyPair: SigningKeyPair, pin:String) throws {
        print("step 1")
        let key = try calculateEncryptionKey(pin: pin)
        
        /* Generate random IV value. IV is public value. */
        let iv = AES.randomIV(AES.blockSize)

        // see https://github.com/krzyzanowskim/CryptoSwift?tab=readme-ov-file#aes
        let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
        let encryptedSeed = try aes.encrypt(Array(userSigningKeyPair.secretKey.utf8))
        let encryptedSeedB64 = encryptedSeed.toBase64()
        let data = iv.toBase64() + ";" + encryptedSeedB64 // store iv + encrypted seed separated by ;
        try simpleKeychain.set(data, forKey: userSecretStorageKey)
        
    }
    
    private static func calculateEncryptionKey(pin:String) throws -> Array<UInt8> {
        return try PKCS5.PBKDF2(
            password: Array(pin.utf8),
            salt: Array(salt.utf8),
            iterations: 4096,
            keyLength: 32, /* AES-256 */
            variant: .sha2(SHA2.Variant.sha256)
        ).calculate()
    }
    
    public static func getUserKeyPair(pin:String) throws -> SigningKeyPair {
        if (try !simpleKeychain.hasItem(forKey: userSecretStorageKey)) {
            throw SecureStorageError.userNotFound
        }
        let data = try! simpleKeychain.string(forKey: userSecretStorageKey)
        let values = data.split(separator: ";") // data contains iv + encrypted seed separated by ;
        if values.count != 2 {
            throw SecureStorageError.userNotFound
        }
        let ivB64 = String(values.first!)
        let ivBytes = Array(Data(base64Encoded: ivB64, options: .ignoreUnknownCharacters)!)
        let encryptedSeedB64 = String(values.last!)
        let encryptedSeedBytes = Array(Data(base64Encoded: encryptedSeedB64, options: .ignoreUnknownCharacters)!)
        
        do {
            let key = try calculateEncryptionKey(pin: pin)
            let aes = try AES(key: key, blockMode: CBC(iv: ivBytes))
            let decrypted = try aes.decrypt(encryptedSeedBytes)
            return try SigningKeyPair(secretKey: String(decoding: Data(decrypted), as: UTF8.self))
        } catch {
            throw SecureStorageError.invalidPin
        }
    }
    
}


public enum SecureStorageError: Error {
    case userNotFound
    case invalidPin
}

extension SecureStorageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .userNotFound:
            return NSLocalizedString("user secret not found in keychain", comment: "Secure storage error")
        case .invalidPin:
            return NSLocalizedString("sorry, pin is wrong", comment: "Secure storage error")
        }
    }
}
