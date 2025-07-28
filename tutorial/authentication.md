# Authentication

The SwiftBasicPay app handles user authentication by using the [`AuthService`](https://github.com/Soneso/SwiftBasicPay/blob/main/SwiftBasicPay/services/AuthService.swift) class.
The class provides methods to sign up a user, sign in, sign out and also to retrieve their Stellar secret key from the [`secure storage`](secure_data_storage.md).
Furthermore, the class holds the current authentication state of the user (signed up, signed in or signed out).


# Code implementation

The user authentication state is covered by following variables:

```swift
/// True if a user is signed up.
public var userIsSignedUp:Bool {
    get throws {
        try SecureStorage.hasUser
    }
}

/// The user's Stellar address if the user is signed in. Otherwise null.
public private(set) var signedInUserAddress:String?

/// True if the user is signed in.
public var userIsSignedIn:Bool {
    get {
        signedInUserAddress != nil
    }
}
```

Now let's have a look how a user is signed up:

```swift
/// Sign up the user for the given Keypair and pincode.
/// Returns the user's Stellar address on success.
///
/// - Parameters:
///   - userKeyPair: The user's signing keypair containing the user's secret key
///   - pin: The user's pin code.
///
public func signUp(userKeyPair: SigningKeyPair, pin:String) throws -> String {
    try SecureStorage.storeUserKeyPair(userSigningKeyPair: userKeyPair, pin: pin)
    signedInUserAddress = userKeyPair.address
    return userKeyPair.address
}
```

To register the user, the service requires the user's signing keypair and pin. `SigningKeyPair` is a class provided by the wallet sdk, 
that holds the user's Stellar address and their secret key. By using this class, we can make sure that the secret key and user address are valid and match together.

The user data is stored in the secure storage, whereby the secret key is encrypted with the user's pin. See [`secure data storage`](secure_data_storage.md). 
By encrypting the secret key with the pin, we can ensure that only the user themselves have access to it by entering their pin code. The pin code is not saved by the app.

After the secret key has been securely stored, we assign the user's Stellar address to the `signedInUserAddress` variable. This means that the user is logged in immediately after registering and the status of our service is `signed in`.

**Sign out:**

```swift
/// Signs out the user.
public func signOut() {
    signedInUserAddress = nil
}
```

The member variable `signedInUserAddress` is set to nil. This means that the current status is now `signed out`.

**Sign in:**

The `signIn` method is provided to log in the user:

```swift
/// If the user is registered, this function is used to sign in the user by using their pin code.
/// Returns the user's Stellar address on success.
///
/// - Parameters:
///   - pin: The user's pin code.
///
public func signIn(pin:String) throws -> String {
    let userKeyPair = try SecureStorage.getUserKeyPair(pin: pin)
    signedInUserAddress = userKeyPair.address
    return userKeyPair.address
}
```

To log the user in, an attempt is made to load their signing keypair from the secure storage. The user's pin code is required for this. 
It must be requested from the user when logging in. On success, we assign the user's stellar address to the `signedInUserAddress` member variable. This means that the user is signed in and the status of our service is `signed in`. See also [`secure data storage`](secure_data_storage.md). 


**Retreive the users's signing key pair:**

Transactions that are sent to the Stellar Network, such as a payment transaction, must be signed with the user's signing key before sending them to the network. With the method `getUserKeypair` we can get the signing key of the user. To do this, however, we need the user's pin code and must ask the user to provide it.

```swift
/// If the user is signed up, this function is used to retrieve the user's signing keypair including the Stellar secret key.
/// The `pin` must be provided by the user so that the secret key can be decrypted.
/// Returns the user's Stellar signing key pair on success.
///
/// - Parameters:
///   - pin: The user's pin code.
///
public func userKeyPair(pin:String) throws -> SigningKeyPair {
    return try SecureStorage.getUserKeyPair(pin: pin)
}
```

The user's signing keypair is retrieved from the [`secure data storage`](secure_data_storage.md).


## Next

Continue with [`Sign up and login`](signup_and_sign_in.md).



