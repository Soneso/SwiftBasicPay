# Secure data storage

 SwiftBasicPay is a non-custodial app. The user's private data is stored locally and securely on the user's device. It is never shared with other applications or services. Private data that is stored is the user's Stellar secret key and the list of their contacts.

## Secret key
Owning a Stellar account means possessing a key for that account. That key is made up of two parts: the public key, which you share with others, and the secret key, which you keep to yourself. This is what the secret key looks like. 

It starts with an `S`:

`SB3MIS23KDF67IGB6YH2IZKE4W6UMICIEL7JYQCL5DZUM4ZM4VUBMUF3`

On the Stellar Network, the secret key that defines your account address is called the master key. By default, when you create a new account on the network, the master key is the sole signer on that account: it's the only key that can authorize transactions.


 ## Code implementation

To store the user's private data, we have built the [`SecureStorage`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/services/SecureStorage.swift) class. 
It uses the [`SimpleKeychain library`](https://github.com/auth0/SimpleKeychain). With this library we can easily store key value pairs in the secure storage of the device (keychain).


### The user`s public and secret key

We store only the secret key, because the public key can be derived from it. To store the user's Stellar secret key, the following storage key is defined:

```swift
static let userSecretStorageKey:String = "secret"
```

The [`SecureStorage`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/services/SecureStorage.swift) class offers the following static functions to handle the storage and retrieval of the user's secret key:

```swift
static func storeUserKeyPair(userSigningKeyPair: SigningKeyPair, pin:String) throws
static var hasUser:Bool
static func getUserKeyPair(pin:String) throws -> SigningKeyPair
```

Let's now look at their implementation.

```swift
/// Stores the signing `userSigningKeyPair` to secure storage. Uses the `pin` to
/// cryptographically encode the secret key before storing it, so that
/// it can only be retrieved by the user who knows the pin.
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
```

As parameters we need the users signing keypair and their pin. The user signing keypair is transferred with the help of the wallet sdk class `SigningKeyPair`. The given `SigningKeyPair` instance contains the user's Stellar public key and secret key. By using the `SigningKeyPair` class we can make sure that the contained secret key is a valid secret key. We also need the user's pin to encrypt the secret key, so that only the user themselves can decrypt it later with the help of their pin.

Before saving the secret key in the secure storage, we encrypt it with the user's pin. This guarantees that even our app can only access it later with the user's pin. 

The secret key is required to sign Stellar transactions, such as payment transactions. This means that we will need the user's permission for every transaction that we want to sign. The user must enter their pin on request, so that we can decrypt the secret key to sign the transaction for the user.

To find out whether we have already stored user data in the secure storage, we have implemented the var `hasUser`:

```swift
/// true if secure user data is stored in the storage.
public static var hasUser:Bool {
    get throws {
        try simpleKeychain.hasItem(forKey:userSecretStorageKey)
    }
}
```

It simply checks whether an entry already exists for our `userSecretStorageKey`.

To load the user data we have implemented the method `getUserKeypair`:

```swift
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
```

First we try to read the encrypted secret key from the storage. If not found we throw a `.userNotFound` exception. Then we try to decrypt it with the given pin that has been requested from the user. If the pin is valid, we can decrypt it and create a `SigningKeyPair` from it by using the wallet sdk. If the pin is invalid, this will fail and we throw an `.invalidPin` exception.


### Contacts list

To save the user's contact list, the following storage key is defined:

```swift
static let userContactsStorageKey:String = "contacts"
```

The [`SecureStorage`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/services/SecureStorage.swift) class offers the following public static functions for manipulating the data:

```swift
static func saveContacts(contacts: [ContactInfo]) 
static func getContacts() -> [ContactInfo]
```

A contact is represented by the struct `ContactInfo`. It holds the contact's name (e.g. `John`) and the contact's Stellar address (account id). The data is stored in the secure storage as a json string.

## Next

Continue with [Authentication](authentication.md).
