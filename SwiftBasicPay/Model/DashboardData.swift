//
//  DashboardData.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 22.07.25.
//

import Foundation
import Combine

/// Unified state management for async data loading
enum DataState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
    
    /// Convenience computed properties for easier access
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var data: T? {
        if case .loaded(let data) = self { return data }
        return nil
    }
    
    var error: Error? {
        if case .error(let error) = self { return error }
        return nil
    }
}

/// Cache entry with TTL support
struct CacheEntry<T> {
    let data: T
    let timestamp: Date
    let ttl: TimeInterval
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

@MainActor
@Observable
class DashboardData {
    
    /// The user's Stellar account id.
    let userAddress: String
    
    /// Manager instances for different data domains
    private let assetManager: AssetManager
    private let paymentManager: PaymentManager
    private let contactManager: ContactManager
    private let kycManager: KycManager
    
    /// Performance tracking
    private var lastFullRefreshTime: Date?
    private let minimumRefreshInterval: TimeInterval = 2.0 // Minimum 2 seconds between full refreshes
    
    // MARK: - Data State Properties
    
    /// Data states for all async operations (delegated to managers)
    var userAssetsState: DataState<[AssetInfo]> {
        assetManager.userAssetsState
    }
    
    var recentPaymentsState: DataState<[PaymentInfo]> {
        paymentManager.recentPaymentsState
    }
    
    var userContactsState: DataState<[ContactInfo]> {
        contactManager.userContactsState
    }
    
    var userKycDataState: DataState<[KycEntry]> {
        kycManager.userKycDataState
    }
    
    // MARK: - Public API Properties
    
    /// True if the user account exists on the Stellar Network (otherwise it needs to be funded)
    var userAccountExists: Bool {
        assetManager.userAccountExists
    }
    
    /// The assets currently held by the user.
    var userAssets: [AssetInfo] {
        assetManager.userAssets
    }
    
    /// A list of recent payments that the user received or sent.
    var recentPayments: [PaymentInfo] {
        paymentManager.recentPayments
    }
    
    /// The list of contacts of the user stored locally.
    var userContacts: [ContactInfo] {
        contactManager.userContacts
    }
    
    /// The list of kyc entries of the user stored locally.
    var userKycData: [KycEntry] {
        kycManager.userKycData
    }
    
    // MARK: - Loading State Properties
    
    var isLoadingAssets: Bool {
        assetManager.isLoadingAssets
    }
    
    var isLoadingContacts: Bool {
        contactManager.isLoadingContacts
    }
    
    var isLoadingRecentPayments: Bool {
        paymentManager.isLoadingRecentPayments
    }
    
    var isLoadingKycData: Bool {
        kycManager.isLoadingKycData
    }
    
    var userAssetsLoadingError: DashboardDataError? {
        assetManager.userAssetsLoadingError
    }
    
    var recentPaymentsLoadingError: DashboardDataError? {
        paymentManager.recentPaymentsLoadingError
    }
    
    internal init(userAddress: String) {
        self.userAddress = userAddress
        
        // Initialize managers
        self.assetManager = AssetManager(userAddress: userAddress)
        self.paymentManager = PaymentManager(userAddress: userAddress)
        self.contactManager = ContactManager()
        self.kycManager = KycManager()
        
        // Set up manager dependencies
        self.paymentManager.setContactManager(self.contactManager)
    }
    
    // MARK: - Public Methods (delegated to managers)
    
    func fetchStellarData() async {
        // Performance optimization: Check minimum refresh interval
        if let lastRefresh = lastFullRefreshTime,
           Date().timeIntervalSince(lastRefresh) < minimumRefreshInterval {
            // Skip refresh if called too frequently
            return
        }
        
        lastFullRefreshTime = Date()
        
        // Performance optimization: Parallel data fetching with TaskGroup for better control
        await withTaskGroup(of: Void.self) { group in
            // Add all parallel tasks
            group.addTask { [weak self] in
                await self?.assetManager.fetchUserAssets()
            }
            
            group.addTask { [weak self] in
                await self?.paymentManager.fetchRecentPayments()
            }
            
            // Wait for all tasks to complete
            await group.waitForAll()
        }
    }
    
    /// Force refresh all data (bypasses cache and minimum refresh interval)
    func forceRefreshAll() async {
        // Clear all caches
        assetManager.clearCache()
        paymentManager.clearCache()
        
        // Reset the last refresh time to bypass minimum interval check
        lastFullRefreshTime = nil
        
        // Fetch fresh data
        await fetchStellarData()
    }
    
    func fetchUserAssets() async {
        await assetManager.fetchUserAssets()
    }
    
    func loadUserContacts() async {
        await contactManager.loadUserContacts()
        // Update payment contact names after loading contacts
        paymentManager.updatePaymentContactNames(contactManager: contactManager)
    }
    
    func loadUserKycData() async {
        await kycManager.loadUserKycData()
    }
    
    func fetchRecentPayments() async {
        await paymentManager.fetchRecentPayments()
    }
    
    // MARK: - Manager Access (for advanced usage)
    
    /// Direct access to asset manager for advanced operations
    var assetManagerDirect: AssetManager {
        assetManager
    }
    
    /// Direct access to payment manager for advanced operations
    var paymentManagerDirect: PaymentManager {
        paymentManager
    }
    
    /// Direct access to contact manager for advanced operations
    var contactManagerDirect: ContactManager {
        contactManager
    }
    
    /// Direct access to KYC manager for advanced operations
    var kycManagerDirect: KycManager {
        kycManager
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

// MARK: - Manager Classes

/// Manager responsible for user asset data and balances
@MainActor
@Observable
class AssetManager {
    
    /// Data state for user assets
    private(set) var userAssetsState: DataState<[AssetInfo]> = .idle
    
    /// Cached account existence state to avoid duplicate API calls
    private var cachedAccountExists: CacheEntry<Bool>?
    
    /// Cache for assets data with TTL
    private var assetsCache: CacheEntry<[AssetInfo]>?
    
    /// Cache TTL configurations
    private let accountExistenceTTL: TimeInterval = 60.0 // 1 minute
    private let assetsCacheTTL: TimeInterval = 30.0 // 30 seconds
    
    /// The user's Stellar account id
    private let userAddress: String
    
    /// Loading state to prevent duplicate concurrent requests
    private var isCurrentlyLoading = false
    
    init(userAddress: String) {
        self.userAddress = userAddress
    }
    
    // MARK: - Public API
    
    /// The assets currently held by the user
    var userAssets: [AssetInfo] {
        userAssetsState.data ?? []
    }
    
    /// Loading state for assets
    var isLoadingAssets: Bool {
        userAssetsState.isLoading
    }
    
    /// Error state for assets
    var userAssetsLoadingError: DashboardDataError? {
        userAssetsState.error as? DashboardDataError
    }
    
    /// True if the user account exists on the Stellar Network
    var userAccountExists: Bool {
        // Return cached value if still valid
        if let cached = cachedAccountExists, !cached.isExpired {
            return cached.data
        }
        return false
    }
    
    // MARK: - Data Fetching
    
    /// Fetch user assets from the Stellar Network
    func fetchUserAssets() async {
        // Prevent duplicate concurrent requests
        guard !isCurrentlyLoading else { return }
        
        // Check cache first
        if let cached = assetsCache, !cached.isExpired {
            userAssetsState = .loaded(cached.data)
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        userAssetsState = .loading
        
        do {
            // Ensure account existence is checked
            let accountExists = await checkAccountExists()
            
            guard accountExists else {
                userAssetsState = .error(DashboardDataError.accountNotFound(accountId: userAddress))
                return
            }
            
            let loadedAssets = try await StellarService.loadAssetsForAddress(address: userAddress)
            
            // Cache the results
            assetsCache = CacheEntry(data: loadedAssets, timestamp: Date(), ttl: assetsCacheTTL)
            userAssetsState = .loaded(loadedAssets)
            
        } catch {
            userAssetsState = .error(DashboardDataError.fetchingError(message: error.localizedDescription))
        }
    }
    
    /// Check if account exists and cache the result
    private func checkAccountExists() async -> Bool {
        // Check if cache is still valid
        if let cached = cachedAccountExists, !cached.isExpired {
            return cached.data
        }
        
        do {
            let exists = try await StellarService.accountExists(address: userAddress)
            cachedAccountExists = CacheEntry(data: exists, timestamp: Date(), ttl: accountExistenceTTL)
            return exists
        } catch {
            cachedAccountExists = CacheEntry(data: false, timestamp: Date(), ttl: accountExistenceTTL)
            return false
        }
    }
    
    /// Clear all caches
    func clearCache() {
        cachedAccountExists = nil
        assetsCache = nil
    }
    
    /// Check if refresh is needed based on cache expiration
    func shouldRefresh() -> Bool {
        if let cached = assetsCache {
            return cached.isExpired
        }
        return true // No cache, should refresh
    }
}

/// Manager responsible for payment history and recent transactions
@MainActor
@Observable
class PaymentManager {
    
    /// Data state for recent payments
    private(set) var recentPaymentsState: DataState<[PaymentInfo]> = .idle
    
    /// Cached account existence state to avoid duplicate API calls
    private var cachedAccountExists: CacheEntry<Bool>?
    
    /// Cache for payments data with TTL
    private var paymentsCache: CacheEntry<[PaymentInfo]>?
    
    /// Cache TTL configurations
    private let accountExistenceTTL: TimeInterval = 60.0 // 1 minute
    private let paymentsCacheTTL: TimeInterval = 20.0 // 20 seconds (more frequent updates for payments)
    
    /// The user's Stellar account id
    private let userAddress: String
    
    /// Reference to contact manager for payment contact name updates
    private weak var contactManager: ContactManager?
    
    /// Loading state to prevent duplicate concurrent requests
    private var isCurrentlyLoading = false
    
    /// Pagination support for lazy loading
    private var lastPagingToken: String?
    private let pageLimit = 20 // Load 20 payments at a time
    
    init(userAddress: String) {
        self.userAddress = userAddress
    }
    
    // MARK: - Public API
    
    /// A list of recent payments that the user received or sent
    var recentPayments: [PaymentInfo] {
        recentPaymentsState.data ?? []
    }
    
    /// Loading state for recent payments
    var isLoadingRecentPayments: Bool {
        recentPaymentsState.isLoading
    }
    
    /// Error state for recent payments
    var recentPaymentsLoadingError: DashboardDataError? {
        recentPaymentsState.error as? DashboardDataError
    }
    
    /// True if the user account exists on the Stellar Network
    var userAccountExists: Bool {
        // Return cached value if still valid
        if let cached = cachedAccountExists, !cached.isExpired {
            return cached.data
        }
        return false
    }
    
    // MARK: - Dependencies
    
    /// Set the contact manager reference for updating payment contact names
    func setContactManager(_ contactManager: ContactManager) {
        self.contactManager = contactManager
    }
    
    // MARK: - Data Fetching
    
    /// Fetch recent payments from the Stellar Network
    func fetchRecentPayments() async {
        // Prevent duplicate concurrent requests
        guard !isCurrentlyLoading else { return }
        
        // Check cache first
        if let cached = paymentsCache, !cached.isExpired {
            recentPaymentsState = .loaded(cached.data)
            return
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        recentPaymentsState = .loading
        
        do {
            // Ensure account existence is checked
            let _ = await checkAccountExists()
            
            guard userAccountExists else {
                recentPaymentsState = .error(DashboardDataError.accountNotFound(accountId: userAddress))
                return
            }
            
            let loadedPayments = try await StellarService.loadRecentPayments(address: userAddress)
            
            // Update payment contact names
            if let contactManager = contactManager {
                for payment in loadedPayments {
                    if let contact = contactManager.findContact(byAccountId: payment.address) {
                        payment.contactName = contact.name
                    }
                }
            }
            
            // Cache the results
            paymentsCache = CacheEntry(data: loadedPayments, timestamp: Date(), ttl: paymentsCacheTTL)
            recentPaymentsState = .loaded(loadedPayments)
            
        } catch {
            recentPaymentsState = .error(DashboardDataError.fetchingError(message: error.localizedDescription))
        }
    }
    
    /// Load more payments (pagination support)
    func loadMorePayments() async {
        // This is a placeholder for pagination implementation
        // Would require StellarService to support paging tokens
        // Example:
        // let morePayments = try await StellarService.loadMorePayments(address: userAddress, pagingToken: lastPagingToken)
    }
    
    /// Check if account exists and cache the result
    private func checkAccountExists() async -> Bool {
        // Check if cache is still valid
        if let cached = cachedAccountExists, !cached.isExpired {
            return cached.data
        }
        
        do {
            let exists = try await StellarService.accountExists(address: userAddress)
            cachedAccountExists = CacheEntry(data: exists, timestamp: Date(), ttl: accountExistenceTTL)
            return exists
        } catch {
            cachedAccountExists = CacheEntry(data: false, timestamp: Date(), ttl: accountExistenceTTL)
            return false
        }
    }
    
    /// Clear all caches
    func clearCache() {
        cachedAccountExists = nil
        paymentsCache = nil
        lastPagingToken = nil
    }
    
    /// Check if refresh is needed based on cache expiration
    func shouldRefresh() -> Bool {
        if let cached = paymentsCache {
            return cached.isExpired
        }
        return true // No cache, should refresh
    }
    
    /// Update contact names for existing payments
    func updatePaymentContactNames(contactManager: ContactManager) {
        if case .loaded(let payments) = recentPaymentsState {
            for payment in payments {
                if let contact = contactManager.findContact(byAccountId: payment.address) {
                    payment.contactName = contact.name
                }
            }
        }
    }
}

/// Manager responsible for contact CRUD operations with SecureStorage sync
@MainActor
@Observable
class ContactManager {
    
    /// Data state for user contacts
    private(set) var userContactsState: DataState<[ContactInfo]> = .idle
    
    /// Cache for contacts (memory optimization)
    private var contactsCache: CacheEntry<[ContactInfo]>?
    private let contactsCacheTTL: TimeInterval = 300.0 // 5 minutes (contacts change less frequently)
    
    /// Contact lookup index for O(1) access by accountId
    private var contactsByAccountId: [String: ContactInfo] = [:]
    
    init() {}
    
    // MARK: - Public API
    
    /// The list of contacts of the user stored locally
    var userContacts: [ContactInfo] {
        userContactsState.data ?? []
    }
    
    /// Loading state for contacts
    var isLoadingContacts: Bool {
        userContactsState.isLoading
    }
    
    /// Error state for contacts
    var userContactsLoadingError: DashboardDataError? {
        userContactsState.error as? DashboardDataError
    }
    
    // MARK: - Data Operations
    
    /// Load user contacts from SecureStorage
    func loadUserContacts() async {
        // Check cache first
        if let cached = contactsCache, !cached.isExpired {
            userContactsState = .loaded(cached.data)
            return
        }
        
        userContactsState = .loading
        
        let contacts = SecureStorage.getContacts()
        
        // Build lookup index for performance
        contactsByAccountId = Dictionary(uniqueKeysWithValues: contacts.map { ($0.accountId, $0) })
        
        // Cache the results
        contactsCache = CacheEntry(data: contacts, timestamp: Date(), ttl: contactsCacheTTL)
        userContactsState = .loaded(contacts)
    }
    
    /// Add a new contact
    func addContact(name: String, accountId: String) async throws {
        let newContact = ContactInfo(name: name, accountId: accountId)
        
        // Update SecureStorage
        var currentContacts = SecureStorage.getContacts()
        currentContacts.append(newContact)
        try SecureStorage.saveContacts(contacts: currentContacts)
        
        // Clear cache to force reload
        contactsCache = nil
        contactsByAccountId[accountId] = newContact
        
        // Update local state
        await loadUserContacts()
    }
    
    /// Update an existing contact
    func updateContact(_ contact: ContactInfo, name: String) async throws {
        var currentContacts = SecureStorage.getContacts()
        
        if let index = currentContacts.firstIndex(where: { $0.id == contact.id }) {
            // Create updated contact with new name
            let updatedContact = ContactInfo(name: name, accountId: contact.accountId)
            currentContacts[index] = updatedContact
            
            // Update SecureStorage
            try SecureStorage.saveContacts(contacts: currentContacts)
            
            // Clear cache and update index
            contactsCache = nil
            contactsByAccountId[contact.accountId] = updatedContact
            
            // Update local state
            await loadUserContacts()
        }
    }
    
    /// Delete a contact
    func deleteContact(_ contact: ContactInfo) async throws {
        var currentContacts = SecureStorage.getContacts()
        currentContacts.removeAll { $0.id == contact.id }
        
        // Update SecureStorage
        try SecureStorage.saveContacts(contacts: currentContacts)
        
        // Clear cache and remove from index
        contactsCache = nil
        contactsByAccountId.removeValue(forKey: contact.accountId)
        
        // Update local state
        await loadUserContacts()
    }
    
    /// Delete multiple contacts
    func deleteContacts(_ contacts: [ContactInfo]) async throws {
        let contactIds = Set(contacts.map { $0.id })
        var currentContacts = SecureStorage.getContacts()
        currentContacts.removeAll { contactIds.contains($0.id) }
        
        // Update SecureStorage
        try SecureStorage.saveContacts(contacts: currentContacts)
        
        // Clear cache and remove from index
        contactsCache = nil
        for contact in contacts {
            contactsByAccountId.removeValue(forKey: contact.accountId)
        }
        
        // Update local state
        await loadUserContacts()
    }
    
    /// Find contact by account ID (O(1) lookup)
    func findContact(byAccountId accountId: String) -> ContactInfo? {
        // Use indexed lookup for performance
        return contactsByAccountId[accountId]
    }
    
    /// Search contacts by name
    func searchContacts(query: String) -> [ContactInfo] {
        if query.isEmpty {
            return userContacts
        }
        return userContacts.filter { 
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.accountId.localizedCaseInsensitiveContains(query)
        }
    }
}

/// Manager responsible for KYC data management with SecureStorage sync
@MainActor
@Observable
class KycManager {
    
    /// Data state for user KYC data
    private(set) var userKycDataState: DataState<[KycEntry]> = .idle
    
    /// Cache for KYC data (memory optimization)
    private var kycCache: CacheEntry<[KycEntry]>?
    private let kycCacheTTL: TimeInterval = 180.0 // 3 minutes
    
    /// KYC lookup index for O(1) access by id
    private var kycEntriesById: [String: KycEntry] = [:]
    
    init() {}
    
    // MARK: - Public API
    
    /// The list of KYC entries of the user stored locally
    var userKycData: [KycEntry] {
        userKycDataState.data ?? []
    }
    
    /// Loading state for KYC data
    var isLoadingKycData: Bool {
        userKycDataState.isLoading
    }
    
    /// Error state for KYC data
    var userKycDataLoadingError: DashboardDataError? {
        userKycDataState.error as? DashboardDataError
    }
    
    // MARK: - Data Operations
    
    /// Load user KYC data from SecureStorage
    func loadUserKycData() async {
        // Check cache first
        if let cached = kycCache, !cached.isExpired {
            userKycDataState = .loaded(cached.data)
            return
        }
        
        userKycDataState = .loading
        
        let kycData = SecureStorage.getKycData()
        
        // Build lookup index for performance
        kycEntriesById = Dictionary(uniqueKeysWithValues: kycData.map { ($0.id, $0) })
        
        // Cache the results
        kycCache = CacheEntry(data: kycData, timestamp: Date(), ttl: kycCacheTTL)
        userKycDataState = .loaded(kycData)
    }
    
    /// Add a new KYC entry
    func addKycEntry(id: String, value: String) async throws {
        let newEntry = KycEntry(id: id, val: value)
        
        // Update SecureStorage
        var currentKycData = SecureStorage.getKycData()
        
        // Remove existing entry with same ID if it exists
        currentKycData.removeAll { $0.id == id }
        currentKycData.append(newEntry)
        
        try SecureStorage.saveKycData(data: currentKycData)
        
        // Clear cache and update index
        kycCache = nil
        kycEntriesById[id] = newEntry
        
        // Update local state
        await loadUserKycData()
    }
    
    /// Update an existing KYC entry
    func updateKycEntry(id: String, value: String) async throws {
        var currentKycData = SecureStorage.getKycData()
        let newEntry = KycEntry(id: id, val: value)
        
        if let index = currentKycData.firstIndex(where: { $0.id == id }) {
            // Update existing entry
            currentKycData[index] = newEntry
        } else {
            // Add new entry if it doesn't exist
            currentKycData.append(newEntry)
        }
        
        // Update SecureStorage
        try SecureStorage.saveKycData(data: currentKycData)
        
        // Clear cache and update index
        kycCache = nil
        kycEntriesById[id] = newEntry
        
        // Update local state
        await loadUserKycData()
    }
    
    /// Delete a KYC entry
    func deleteKycEntry(id: String) async throws {
        var currentKycData = SecureStorage.getKycData()
        currentKycData.removeAll { $0.id == id }
        
        // Update SecureStorage
        try SecureStorage.saveKycData(data: currentKycData)
        
        // Clear cache and remove from index
        kycCache = nil
        kycEntriesById.removeValue(forKey: id)
        
        // Update local state
        await loadUserKycData()
    }
    
    /// Get KYC entry by ID (O(1) lookup)
    func getKycEntry(id: String) -> KycEntry? {
        // Use indexed lookup for performance
        return kycEntriesById[id]
    }
    
    /// Get KYC entry value by ID
    func getKycValue(id: String) -> String? {
        return getKycEntry(id: id)?.val
    }
    
    /// Check if KYC entry exists
    func hasKycEntry(id: String) -> Bool {
        return getKycEntry(id: id) != nil
    }
    
    /// Bulk update KYC entries
    func updateKycEntries(_ entries: [String: String]) async throws {
        var currentKycData = SecureStorage.getKycData()
        
        for (id, value) in entries {
            let newEntry = KycEntry(id: id, val: value)
            // Remove existing entry with same ID if it exists
            currentKycData.removeAll { $0.id == id }
            // Add new entry
            currentKycData.append(newEntry)
            // Update index
            kycEntriesById[id] = newEntry
        }
        
        // Update SecureStorage
        try SecureStorage.saveKycData(data: currentKycData)
        
        // Clear cache
        kycCache = nil
        
        // Update local state
        await loadUserKycData()
    }
    
    /// Clear all KYC data
    func clearAllKycData() async throws {
        // Clear SecureStorage
        try SecureStorage.saveKycData(data: [])
        
        // Clear cache and index
        kycCache = nil
        kycEntriesById.removeAll()
        
        // Update local state
        await loadUserKycData()
    }
}
