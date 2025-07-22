//
//  DemoError.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 26.06.25.
//

import Foundation

public enum DemoError: Error {
    case runtimeError(String)
}

extension DemoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .runtimeError(let val):
            return NSLocalizedString(val, comment: "Demo error")
        }
    }
}
