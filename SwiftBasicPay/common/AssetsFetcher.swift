//
//  AssetsFetcher.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 15.07.25.
//

import Foundation

class AssetsFetcher: ObservableObject {
    @Published var assets: [AssetInfo] = []
    @Published var error: AssetsFetcherError? = nil
    @Published var isLoading: Bool = false
    
    func fetchAssets(accountId:String) async {
        Task { @MainActor in
            self.isLoading = true
        }
        do {
            let accountExists = try await StellarService.accountExists(address: accountId)
            if !accountExists {
                Task { @MainActor in
                    self.error = .accountNotFound(accountId: accountId)
                    self.assets = []
                    self.isLoading = false
                }
                return
            }
            let loadedAssets = try await StellarService.loadAssetsForAddress(address: accountId)
            Task { @MainActor in
                self.error = nil
                self.assets = loadedAssets
                self.isLoading = false
            }
        } catch {
            Task { @MainActor in
                self.error = .fetchingError(accountId: accountId, message: error.localizedDescription)
                self.assets = []
                self.isLoading = false
            }
        }
    }
}

public enum AssetsFetcherError: Error {
    case accountNotFound(accountId:String)
    case fetchingError(accountId:String, message:String)
}

extension AssetsFetcherError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .accountNotFound(let accountId):
            return NSLocalizedString("Account with id: \(accountId) not found on the Stellar Network.", comment: "The account is not funded.")
        case .fetchingError(let accountId, let message):
            return NSLocalizedString("Error fetching assets for account \(accountId): \(message)", comment: "Could not fetch assets for the given account id")
        }
    }
}
