//
//  TransferFieldInfo.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 02.08.25.
//

import Foundation
import stellar_wallet_sdk

public class TransferFieldInfo: Hashable, Identifiable {
    let key:String
    let info:Sep6FieldInfo
    
    internal init(key: String, info: Sep6FieldInfo) {
        self.key = key
        self.info = info
    }
    
    public var optional : Bool {
        return info.optional ?? false
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
    
    public static func == (lhs: TransferFieldInfo, rhs: TransferFieldInfo) -> Bool {
        lhs.key == rhs.key
    }
}
