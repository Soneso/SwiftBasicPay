# Secure Data Storage

SwiftBasicPay is a non-custodial wallet application. The user's private data is stored locally and securely on the device's keychain, never shared with external services. The app stores three types of sensitive data:
- User's Stellar secret key (encrypted with PIN)
- Contact list
- KYC data for anchor integrations

## Secret Key Management

Owning a Stellar account means possessing a keypair: a public key (shared with others) and a secret key (kept private). The secret key starts with 'S':

`SB3MIS23KDF67IGB6YH2IZKE4W6UMICIEL7JYQCL5DZUM4ZM4VUBMUF3`

On the Stellar Network, this secret key (master key) is the sole signer on newly created accounts and authorizes all transactions.

## Code Implementation

The [`SecureStorage`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/services/SecureStorage.swift) class handles secure data storage using [`SimpleKeychain`](https://github.com/auth0/SimpleKeychain) for iOS keychain integration.

### Storage Keys

```swift
private static let userSecretStorageKey:String = "secret"
private static let userContactsStorageKey:String = "contacts"
private static let userKycDataStorageKey:String = "kyc_data"
```

### User's Signing Keypair

The [`SecureStorage`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/services/SecureStorage.swift) class provides these key methods:

```swift
static func storeUserKeyPair(userSigningKeyPair: SigningKeyPair, pin:String) throws
static var hasUser:Bool
static func getUserKeyPair(pin:String) throws -> SigningKeyPair
```

#### Storing the Secret Key

```swift
/// Stores the signing keypair with PIN-based encryption
public static func storeUserKeyPair(userSigningKeyPair: SigningKeyPair, pin:String) throws {
    let key = try calculateEncryptionKey(pin: pin)
    
    // Generate random IV for AES encryption
    let iv = AES.randomIV(AES.blockSize)

    // Encrypt the secret key with AES-256-CBC
    let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
    let encryptedSeed = try aes.encrypt(Array(userSigningKeyPair.secretKey.utf8))
    let encryptedSeedB64 = encryptedSeed.toBase64()
    
    // Store IV and encrypted seed together
    let data = iv.toBase64() + ";" + encryptedSeedB64
    try simpleKeychain.set(data, forKey: userSecretStorageKey)
}
```

The method uses PBKDF2 key derivation to create an encryption key from the user's PIN:

```swift
private static func calculateEncryptionKey(pin:String) throws -> Array<UInt8> {
    return try PKCS5.PBKDF2(
        password: Array(pin.utf8),
        salt: Array(salt.utf8),
        iterations: 4096,
        keyLength: 32, // AES-256
        variant: .sha2(SHA2.Variant.sha256)
    ).calculate()
}
```

#### Checking User Existence

```swift
/// Returns true if user data exists in secure storage
public static var hasUser:Bool {
    get throws {
        try simpleKeychain.hasItem(forKey:userSecretStorageKey)
    }
}
```

#### Retrieving the Keypair

```swift
/// Retrieves and decrypts the user's signing keypair
public static func getUserKeyPair(pin:String) throws -> SigningKeyPair {
    if (try !hasUser) {
        throw SecureStorageError.userNotFound
    }
    
    let data = try simpleKeychain.string(forKey: userSecretStorageKey)
    let values = data.split(separator: ";")
    
    if values.count != 2 {
        throw SecureStorageError.userNotFound
    }
    
    // Extract IV and encrypted seed
    let ivB64 = String(values.first!)
    let ivBytes = Array(Data(base64Encoded: ivB64, options: .ignoreUnknownCharacters)!)
    let encryptedSeedB64 = String(values.last!)
    let encryptedSeedBytes = Array(Data(base64Encoded: encryptedSeedB64, options: .ignoreUnknownCharacters)!)
    
    do {
        // Decrypt using the PIN-derived key
        let key = try calculateEncryptionKey(pin: pin)
        let aes = try AES(key: key, blockMode: CBC(iv: ivBytes))
        let decrypted = try aes.decrypt(encryptedSeedBytes)
        return try SigningKeyPair(secretKey: String(decoding: Data(decrypted), as: UTF8.self))
    } catch {
        throw SecureStorageError.invalidPin
    }
}
```

### Contact Management

Contacts are stored as JSON in the keychain:

```swift
public static func saveContacts(contacts: [ContactInfo]) throws {
    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting = .prettyPrinted
    let encodeContacts = try jsonEncoder.encode(contacts)
    let endcodeStringContacts = String(data: encodeContacts, encoding: .utf8)!
    try simpleKeychain.set(endcodeStringContacts, forKey: userContactsStorageKey)
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
```

The `ContactInfo` struct represents a contact with name and Stellar address:

```swift
struct ContactInfo: Codable {
    let name: String
    let stellarAddress: String
}
```

### KYC Data Storage

Similar to contacts, KYC data for anchor integrations is stored as JSON:

```swift
public static func saveKycData(data: [KycEntry]) throws {
    let jsonEncoder = JSONEncoder()
    jsonEncoder.outputFormatting = .prettyPrinted
    let encodeKycData = try jsonEncoder.encode(data)
    let endcodeStringKycData = String(data: encodeKycData, encoding: .utf8)!
    try simpleKeychain.set(endcodeStringKycData, forKey: userKycDataStorageKey)
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
    // Return demo data if none exists
    if data.isEmpty {
        data = demoKycData
    }
    return data
}
```

## Security Considerations

1. **PIN-based Encryption**: The secret key is always encrypted with the user's PIN using AES-256-CBC
2. **Key Derivation**: PBKDF2 with 4096 iterations prevents brute-force attacks
3. **Transaction Signing**: Every transaction requires PIN entry to decrypt the signing key
4. **Keychain Storage**: iOS keychain provides hardware-backed security
5. **Non-custodial**: The app never transmits the secret key or PIN

## Next

Continue with [`Authentication`](authentication.md).