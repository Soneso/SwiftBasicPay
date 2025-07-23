//
//  DashboardData.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 22.07.25.
//

import Foundation

class DashboardData: ObservableObject {
    
    let userAddress:String
    @Published var userAccountExists: Bool = false
    @Published var userAssets: [AssetInfo] = []
    @Published var userContacts: [ContactInfo] = []
    @Published var recentPayments: [PaymentInfo] = []
    @Published var isLoadingAssets: Bool = false
    @Published var isLoadingContacts: Bool = false
    @Published var isLoadingRecentPayments: Bool = false
    @Published var userAssetsLoadingError: DashboardDataError? = nil
    @Published var recentPaymentsLoadingError: DashboardDataError? = nil
    
    internal init(userAddress: String) {
        self.userAddress = userAddress
    }
    
    func fetchStellarData() async {
        await fetchUserAssets()
        await fetchRecentPayments()
    }
    
    func fetchUserAssets() async  {
        Task { @MainActor in
            self.isLoadingAssets = true
        }
        do {
            let accountExists = try await StellarService.accountExists(address: userAddress)
            if !accountExists {
                Task { @MainActor in
                    self.userAssetsLoadingError = .accountNotFound(accountId: self.userAddress)
                    self.userAssets = []
                    self.userAccountExists = false
                    self.isLoadingAssets = false
                }
                return
            }
            let loadedAssets = try await StellarService.loadAssetsForAddress(address: userAddress)
            Task { @MainActor in
                self.userAssetsLoadingError = nil
                self.userAssets = loadedAssets
                self.userAccountExists = true
                self.isLoadingAssets = false
            }
        } catch {
            Task { @MainActor in
                self.userAssetsLoadingError = .fetchingError(message: error.localizedDescription)
                self.userAssets = []
                self.isLoadingAssets = false
            }
        }
    }
    
    func loadUserContacts() async  {
        Task { @MainActor in
            self.isLoadingContacts = true
        }
        let contacts = SecureStorage.getContacts()
        Task { @MainActor in
            self.userContacts = contacts
            self.isLoadingContacts = false
        }
    }
    
    func fetchRecentPayments() async  {
        Task { @MainActor in
            self.isLoadingRecentPayments = true
        }
        do {
            let accountExists = try await StellarService.accountExists(address: userAddress)
            if !accountExists {
                Task { @MainActor in
                    self.recentPayments = []
                    self.recentPaymentsLoadingError = .accountNotFound(accountId: userAddress)
                    self.isLoadingRecentPayments = false
                }
                return
            }
            let loadedPayments = try await StellarService.loadRecentPayments(address: userAddress)
            // TODO: set contact names
            Task { @MainActor in
                self.recentPaymentsLoadingError = nil
                self.recentPayments = loadedPayments
                self.isLoadingRecentPayments = false
            }
        } catch {
            Task { @MainActor in
                self.recentPaymentsLoadingError = .fetchingError(message: error.localizedDescription)
                self.recentPayments = []
                self.isLoadingRecentPayments = false
            }
        }
    }
}

enum DashboardDataError: Error {
    case accountNotFound(accountId:String)
    case fetchingError(message:String)
}



extension DashboardDataError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .accountNotFound(let accountId):
            return NSLocalizedString("Account with id: \(accountId) not found on the Stellar Network.", comment: "The account is not funded.")
        case .fetchingError(let message):
            return NSLocalizedString("Error fetching data: \(message)", comment: "Could not fetch data")
        }
    }
}
