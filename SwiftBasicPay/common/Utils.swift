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
}
