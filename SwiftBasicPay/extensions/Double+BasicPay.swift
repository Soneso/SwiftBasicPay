//
//  Double+BasicPay.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 01.08.25.
//

import Foundation

public extension Double {
    
    var toStringWithoutTrailingZeros:String {
        return (String(self).amountWithoutTrailingZeros)
    }
}
