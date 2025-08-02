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

/// Service used to securely store private user data in the keychain.
public class SecureStorage {

    private static let simpleKeychain = SimpleKeychain()
    private static let userSecretStorageKey:String = "secret"
    private static let userContactsStorageKey:String = "contacts"
    private static let userKycDataStorageKey:String = "kyc_data"
    private static let salt:String = "stellar"
    
    /// true if secure user data is stored in the storage.
    public static var hasUser:Bool {
        get throws {
            try simpleKeychain.hasItem(forKey:userSecretStorageKey)
        }
    }
    
    /// Stores the signing `userSigningKeyPair` to secure storage. Uses the `pin` to
    /// cryptographically encode the secret key before storing it, so that
    /// it can only be retrieved by the user who knows the pin.
    ///
    /// - Parameters:
    ///   - userSigningKeyPair: The user's signing keypair containing the user's secret key
    ///   - pin: The user's pin code.
    ///
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
    
    /// Returns the signing user keypair from the storage. Requires the user's `pin` to decode the stored user's secret key.
    /// It can only construct the keypair if there is user data in the storage (see `hasUser`) and if the given `pin` is valid.
    ///
    /// - Throws:
    ///   - `SecureStorageError.userNotFound`  if the user data could not be found in the secure storage.
    ///   - `SecureStorageError.invalidPin` if the pin is invalid and the data could not be decrypted.
    ///
    /// - Parameters:
    ///   - pin: The users pin code.
    ///
    public static func getUserKeyPair(pin:String) throws -> SigningKeyPair {
        if (try !hasUser) {
            throw SecureStorageError.userNotFound
        }
        let data = try simpleKeychain.string(forKey: userSecretStorageKey)
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
    
    public static func getKycData() -> [KycEntry] {
        var data:[KycEntry] = []
        if let hasKycData = try? simpleKeychain.hasItem(forKey:userKycDataStorageKey),
           hasKycData,
            let jsonString = try? simpleKeychain.string(forKey: userKycDataStorageKey)  {
            let jsonData = Data(jsonString.utf8)
            let jsonDecoder = JSONDecoder()
            if let d = try? jsonDecoder.decode([KycEntry].self, from: jsonData) {
                data = d
            }
        }
        if data.isEmpty {
            data = emtpyKycData
        }
        return data
    }
    
    public static func saveKycData(data: [KycEntry]) throws {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        let encodeKycData = try jsonEncoder.encode(data)
        let endcodeStringKycData = String(data: encodeKycData, encoding: .utf8)!
        try simpleKeychain.set(endcodeStringKycData, forKey: userKycDataStorageKey)
    }
    
    public static func updateKycDataEntry(id:String, val:String) throws -> KycEntry {
        var kycData = getKycData()
        let newEntry = KycEntry(id: id, val: val)
        if let index = kycData.firstIndex(where: {$0.id == id}) {
            kycData[index] = newEntry
        } else {
            kycData.append(newEntry)
        }
        try saveKycData(data: kycData)
        return newEntry
    }
    
    public static var emtpyKycData:[KycEntry] {
        // some example etries, in a real app you should add more
        var data:[KycEntry] = []
        data.append(KycEntry(id: Sep9PersonKeys.lastName, val: ""))
        data.append(KycEntry(id: Sep9PersonKeys.firstName, val: ""))
        data.append(KycEntry(id: Sep9PersonKeys.emailAddress, val: ""))
        data.append(KycEntry(id: Sep9PersonKeys.mobileNumber, val: ""))
        data.append(KycEntry(id: Sep9PersonKeys.taxId, val: ""))
        data.append(KycEntry(id: Sep9FinancialKeys.bankAccountNumber, val: ""))
    
        return data
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

public struct ContactInfo: Identifiable, Codable, Hashable {
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
    
    public static func == (lhs: ContactInfo, rhs: ContactInfo) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public struct KycEntry: Identifiable, Codable, Hashable {

    public let id: String
    public var val: String
    
    enum CodingKeys: String, CodingKey {
           case id, val
    }
    
    internal init(id: String, val: String) {
        self.id = id
        self.val = val
    }
    
    public var keyLabel:String {
        // Replace underscores with spaces
        let replaced = id.replacingOccurrences(of: "_", with: " ")
        
        // Capitalize the first letter
        guard let first = replaced.first else {
            return ""
        }
        
        let capitalizedFirst = String(first).uppercased()
        let remaining = String(replaced.dropFirst())
        
        return capitalizedFirst + remaining
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        val = try container.decode(String.self, forKey: .val)
    }
    
    public static func == (lhs: KycEntry, rhs: KycEntry) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
