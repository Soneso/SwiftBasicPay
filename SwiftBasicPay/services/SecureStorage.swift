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
    private static let userContactsStorageKey:String = "contacts"
    private static let salt:String = "stellar"
    
    public static var hasUser:Bool {
        get throws {
            try simpleKeychain.hasItem(forKey:userSecretStorageKey)
        }
    }
    
    public static func storeUserKeyPair(userSigningKeyPair: SigningKeyPair, pin:String) throws {
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
    

    
    public static func getContacts() -> [ContactInfo] {
        var contacts:[ContactInfo] = []
        if let hasContacts = try? simpleKeychain.hasItem(forKey:userContactsStorageKey),
            hasContacts,
            let jsonString = try? simpleKeychain.string(forKey: userContactsStorageKey)  {
            let jsonData = Data(jsonString.utf8)
            let jsonDecoder = JSONDecoder()
            if let c = try? jsonDecoder.decode([ContactInfo].self, from: jsonData) {
                contacts = c
            }
        }
        return contacts
    }
    
    public static func saveContacts(contacts: [ContactInfo]) throws {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        let encodeContacts = try jsonEncoder.encode(contacts)
        let endcodeStringContacts = String(data: encodeContacts, encoding: .utf8)!
        try simpleKeychain.set(endcodeStringContacts, forKey: userContactsStorageKey)
    }
    
    public static func deleteAll() throws {
        if try hasUser {
            try simpleKeychain.deleteAll()
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

public struct ContactInfo: Identifiable, Codable {
    public let id: String
    public let name: String
    public let accountId: String
    
    enum CodingKeys: String, CodingKey {
           case id, name, accountId
    }
    
    public init(name: String, accountId:String) {
        self.id = UUID().uuidString
        self.name = name
        self.accountId = accountId
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        accountId = try container.decode(String.self, forKey: .accountId)
    }
}
