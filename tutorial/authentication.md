# Authentication

The SwiftBasicPay app manages user authentication through the [`AuthService`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/services/AuthService.swift) class. This service provides methods to sign up users, sign in/out, and retrieve signing keys from [`secure storage`](secure_data_storage.md). It maintains the current authentication state (signed up, signed in, or signed out).

## Code Implementation

### Authentication State

The `AuthService` tracks user state with these properties:

```swift
/// True if a user is signed up (has stored credentials)
public var userIsSignedUp:Bool {
    get throws {
        try SecureStorage.hasUser
    }
}

/// The user's Stellar address if signed in, nil otherwise
public private(set) var signedInUserAddress:String?

/// True if the user is currently signed in
public var userIsSignedIn:Bool {
    get {
        signedInUserAddress != nil
    }
}
```

### Sign Up Flow

When a new user registers, their keypair is securely stored:

```swift
/// Sign up the user with keypair and PIN
/// Returns the user's Stellar address on success
public func signUp(userKeyPair: SigningKeyPair, pin:String) throws -> String {
    // Store encrypted keypair in secure storage
    try SecureStorage.storeUserKeyPair(userSigningKeyPair: userKeyPair, pin: pin)
    
    // Automatically sign in after signup
    signedInUserAddress = userKeyPair.address
    return userKeyPair.address
}
```

Key points:
- `SigningKeyPair` from the wallet SDK validates the keypair
- The secret key is encrypted with the user's PIN before storage
- The PIN is never stored - only used for encryption/decryption
- Users are automatically signed in after successful signup

### Sign Out

```swift
/// Signs out the current user
public func signOut() {
    signedInUserAddress = nil
}
```

Simply clears the signed-in address, changing the authentication state to signed out.

### Sign In Flow

Returning users authenticate with their PIN:

```swift
/// Sign in with PIN verification
/// Returns the user's Stellar address on success
public func signIn(pin:String) throws -> String {
    // Attempt to decrypt keypair with provided PIN
    let userKeyPair = try SecureStorage.getUserKeyPair(pin: pin)
    
    // Update authentication state
    signedInUserAddress = userKeyPair.address
    return userKeyPair.address
}
```

The process:
1. Attempts to decrypt the stored keypair using the PIN
2. If successful, updates the signed-in state
3. Throws `SecureStorageError.invalidPin` if PIN is incorrect
4. Throws `SecureStorageError.userNotFound` if no user data exists

### Retrieving Signing Keys for Transactions

Every Stellar transaction requires signing with the user's secret key. The `userKeyPair` method retrieves it:

```swift
/// Get the user's signing keypair for transaction signing
/// Requires PIN to decrypt the secret key
public func userKeyPair(pin:String) throws -> SigningKeyPair {
    return try SecureStorage.getUserKeyPair(pin: pin)
}
```

This method is called whenever the app needs to:
- Sign payment transactions
- Add or remove trustlines
- Interact with anchors

## Integration with Stellar SDK

The `AuthService` uses the wallet SDK's `SigningKeyPair` class which provides:
- Keypair validation
- Address derivation from secret key
- Transaction signing capabilities

Example usage in a payment flow:

```swift
// User enters PIN in UI
let pin = "1234"

// Retrieve keypair for signing
let userKeyPair = try authService.userKeyPair(pin: pin)

// Use with Stellar SDK to sign transaction
let stellar = wallet.stellar
let txBuilder = try await stellar.transaction(sourceAddress: userKeyPair)
let tx = try txBuilder.transfer(
    destinationAddress: recipientAddress,
    assetId: asset,
    amount: amount
).build()

// Sign with retrieved keypair
stellar.sign(tx: tx, keyPair: userKeyPair)

// Submit to network
try await stellar.submitTransaction(signedTransaction: tx)
```

## Security Model

1. **PIN Required**: Every transaction requires PIN entry
2. **No PIN Storage**: The PIN is never persisted
3. **Encrypted Storage**: Secret keys are always encrypted at rest
4. **Session-based**: Signed-in state is memory-only (lost on app restart)
5. **Non-custodial**: Full user control of keys

## Error Handling

The service throws specific errors:
- `SecureStorageError.userNotFound`: No user registered
- `SecureStorageError.invalidPin`: Incorrect PIN provided
- Standard Swift errors for other failures

## Next

Continue with [`Sign up and sign in`](signup_and_sign_in.md).