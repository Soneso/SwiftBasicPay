//
//  AuthService.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import Foundation
import stellar_wallet_sdk

public class AuthService {
    
    public private(set) var signedInUserAddress:String?
    
    public var userIsSignedUp:Bool {
        get throws {
            try SecureStorage.hasUser
        }
    }
    
    public var userIsSignedIn:Bool {
        get {
            signedInUserAddress != nil
        }
    }
    
    public func signUp(userKeyPair: SigningKeyPair, pin:String) throws -> String {
        try SecureStorage.storeUserKeyPair(userSigningKeyPair: userKeyPair, pin: pin)
        signedInUserAddress = userKeyPair.address
        return userKeyPair.address
    }
    
    public func signIn(pin:String) throws -> String {
        let userKeyPair = try SecureStorage.getUserKeyPair(pin: pin)
        signedInUserAddress = userKeyPair.address
        return userKeyPair.address
    }
    
    public func userKeyPair(pin:String) throws -> SigningKeyPair {
        return try SecureStorage.getUserKeyPair(pin: pin)
    }
    
    public func signOut() {
        signedInUserAddress = nil
    }
}
