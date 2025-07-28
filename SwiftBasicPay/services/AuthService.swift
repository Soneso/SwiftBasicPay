//
//  AuthService.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import Foundation
import stellar_wallet_sdk

public class AuthService {
    
    /// True if a user is signed up.
    public var userIsSignedUp:Bool {
        get throws {
            try SecureStorage.hasUser
        }
    }
    
    /// True if the user is signed in.
    public var userIsSignedIn:Bool {
        get {
            signedInUserAddress != nil
        }
    }
    
    /// The user's Stellar address if the user is signed in. Otherwise null.
    public private(set) var signedInUserAddress:String?
    
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
    
    /// Signs out the user.
    public func signOut() {
        signedInUserAddress = nil
    }
}
