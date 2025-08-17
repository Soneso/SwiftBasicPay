//
//  String+BasicPay.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 01.08.25.
//

import Foundation

public extension String {

    var shortAddress: String {
        if self.count == 56 {
            return "\(self.prefix(3))...\(self.suffix(3))"
        }
        return self
    }
    
    var amountWithoutTrailingZeros:String {
        if let doubleAmount = Double(self) {
            let formatter = NumberFormatter()
            let number = NSNumber(value: Double(doubleAmount))
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 16
            return String(formatter.string(from: number) ?? self)
        }
        return self
    }
}
