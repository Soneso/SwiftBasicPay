//
//  DashboardData.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 22.07.25.
//

import Foundation

class DashboardData: ObservableObject {
    
    /// The user's Stellar account id.
    let userAddress:String
    
    /// True if the user account exists on the Stellar Network (otherwise it needs to be funded)
    @Published var userAccountExists: Bool = false
    
    /// The assets currently hold by the user.
    @Published var userAssets: [AssetInfo] = []
    
    /// A list of recent payments that the user received or sent.
    @Published var recentPayments: [PaymentInfo] = []
    
    /// The list of contacts of the user stored locally.
    @Published var userContacts: [ContactInfo] = []
    
    /// The list of anchored assets currently hold by the user
    @Published var anchoredAssets: [AnchoredAssetInfo] = []
    

    @Published var isLoadingAssets: Bool = false
    @Published var isLoadingContacts: Bool = false
    @Published var isLoadingRecentPayments: Bool = false
    @Published var isLoadingAnchoredAssets: Bool = false
    @Published var userAssetsLoadingError: DashboardDataError? = nil
    @Published var recentPaymentsLoadingError: DashboardDataError? = nil
    @Published var userAnchoredAssetsLoadingError: DashboardDataError? = nil
    
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
            for payment in loadedPayments {
                if let contact = userContacts.filter({$0.accountId == payment.address}).first {
                    payment.contactName = contact.name
                }
            }
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
    
    func fetchAnchoredAssets() async  {
        Task { @MainActor in
            self.isLoadingAnchoredAssets = true
        }
        do {
            let accountExists = try await StellarService.accountExists(address: userAddress)
            if !accountExists {
                Task { @MainActor in
                    self.userAnchoredAssetsLoadingError = .accountNotFound(accountId: self.userAddress)
                    self.anchoredAssets = []
                    self.userAccountExists = false
                    self.isLoadingAnchoredAssets = false
                }
                return
            }
            let loadedAssets = try await StellarService.getAnchoredAssets(fromAssets: self.userAssets)
            Task { @MainActor in
                self.userAnchoredAssetsLoadingError = nil
                self.anchoredAssets = loadedAssets
                self.userAccountExists = true
                self.isLoadingAnchoredAssets = false
            }
        } catch {
            Task { @MainActor in
                self.userAnchoredAssetsLoadingError = .fetchingError(message: error.localizedDescription)
                self.anchoredAssets = []
                self.isLoadingAnchoredAssets = false
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
