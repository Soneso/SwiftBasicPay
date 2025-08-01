//
//  Utils.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 28.06.25.
//

import Foundation
import SwiftUI

public class Utils {
    
    public static var divider: some View {
        return Divider()
    }
    
    public static var progressView: some View {
        return ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .blue))
    }
    
    public static func progressViewWithLabel(_ label:String) -> some View {
        return HStack {
            Utils.progressView
            Text(label).padding(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    public static func removeTrailingZerosFormAmount(amount:String) -> String {
        if let doubleAmount = Double(amount) {
            let formatter = NumberFormatter()
            let number = NSNumber(value: Double(doubleAmount))
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 16
            return String(formatter.string(from: number) ?? amount)
        }
        return amount
    }
    
    public static func shortAddress(address:String) -> String {
        if address.count == 56 {
            return "\(address.prefix(4))...\(address.suffix(4))"
        }
        return address
    }
}
