//
//  KycFieldInfo.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 02.08.25.
//

import Foundation
import stellar_wallet_sdk

public class KycFieldInfo: Hashable, Identifiable {
    let key:String
    let info:Field
    
    internal init(key: String, info: Field) {
        self.key = key
        self.info = info
    }
    
    public var optional : Bool {
        return info.optional ?? false
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
    
    public static func == (lhs: KycFieldInfo, rhs: KycFieldInfo) -> Bool {
        lhs.key == rhs.key
    }
}
