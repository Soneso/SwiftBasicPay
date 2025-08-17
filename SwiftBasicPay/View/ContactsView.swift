//
//  ContactsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import stellar_wallet_sdk
import AlertToast
import Observation

// MARK: - View Model

@Observable
final class ContactsViewModel {
    // UI State
    var searchText = ""
    var showAddForm = false
    var showDeleteConfirmation = false
    var contactToDelete: ContactInfo?
    var showToast = false
    var toastMessage = ""
    
    // Add Contact Form
    var newContactName = ""
    var newContactAccountId = ""
    var isAddingContact = false
    var addContactError: String?
    
    // Edit Mode
    var editMode: EditMode = .inactive
    var selectedContacts = Set<String>()
    
    @MainActor
    func addContact(dashboardData: DashboardData) async {
        addContactError = nil
        
        // Validation
        guard !newContactName.isEmpty else {
            addContactError = "Please enter a name"
            return
        }
        
        guard !newContactAccountId.isEmpty else {
            addContactError = "Please enter an account ID"
            return
        }
        
        // Check for duplicate names
        if dashboardData.userContacts.contains(where: { $0.name.lowercased() == newContactName.lowercased() }) {
            addContactError = "A contact with this name already exists"
            return
        }
        
        // Check for duplicate account IDs
        if dashboardData.userContacts.contains(where: { $0.accountId == newContactAccountId }) {
            addContactError = "This account is already in your contacts"
            return
        }
        
        // Validate account ID format
        // TODO: Add support for muxed accounts
        guard newContactAccountId.isValidEd25519PublicKey() else {
            addContactError = "Invalid account ID format"
            return
        }
        
        isAddingContact = true
        
        do {
            // Check if account exists on network
            let accountExists = try await StellarService.accountExists(address: newContactAccountId)
            guard accountExists else {
                addContactError = "Account does not exist on the Stellar Network"
                isAddingContact = false
                return
            }
            
            // Add contact
            var updatedContacts = dashboardData.userContacts
            let newContact = ContactInfo(name: newContactName, accountId: newContactAccountId)
            updatedContacts.append(newContact)
            
            // Save to secure storage
            try SecureStorage.saveContacts(contacts: updatedContacts)
            
            // Reload contacts
            await dashboardData.loadUserContacts()
            
            // Success feedback
            toastMessage = "Contact added successfully"
            showToast = true
            
            // Reset form
            clearForm()
            showAddForm = false
            
            // Haptic feedback
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
        } catch {
            addContactError = error.localizedDescription
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
        
        isAddingContact = false
    }
    
    @MainActor
    func deleteContact(_ contact: ContactInfo, dashboardData: DashboardData) async {
        var updatedContacts = dashboardData.userContacts
        updatedContacts.removeAll { $0.id == contact.id }
        
        do {
            try SecureStorage.saveContacts(contacts: updatedContacts)
            await dashboardData.loadUserContacts()
            
            toastMessage = "Contact deleted"
            showToast = true
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        } catch {
            toastMessage = "Failed to delete contact"
            showToast = true
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
    }
    
    @MainActor
    func deleteSelectedContacts(dashboardData: DashboardData) async {
        var updatedContacts = dashboardData.userContacts
        updatedContacts.removeAll { selectedContacts.contains($0.id) }
        
        do {
            try SecureStorage.saveContacts(contacts: updatedContacts)
            await dashboardData.loadUserContacts()
            
            toastMessage = "\(selectedContacts.count) contact(s) deleted"
            showToast = true
            
            selectedContacts.removeAll()
            editMode = .inactive
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        } catch {
            toastMessage = "Failed to delete contacts"
            showToast = true
            
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        }
    }
    
    func clearForm() {
        newContactName = ""
        newContactAccountId = ""
        addContactError = nil
    }
    
    func prepareToDelete(_ contact: ContactInfo) {
        contactToDelete = contact
        showDeleteConfirmation = true
    }
    
    func filteredContacts(_ contacts: [ContactInfo]) -> [ContactInfo] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText) ||
            contact.accountId.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Contact Card Component

struct ContactCard: View {
    let contact: ContactInfo
    let isSelected: Bool
    var onTap: (() -> Void)?
    var onDelete: (() -> Void)?
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Text(contact.name.prefix(2).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Contact Info
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(contact.accountId.shortAddress)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Selection indicator or chevron
            if let onTap = onTap {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(0.6)
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }
                onTap?()
            }
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            Button {
                UIPasteboard.general.string = contact.accountId
                let successFeedback = UINotificationFeedbackGenerator()
                successFeedback.notificationOccurred(.success)
            } label: {
                Label("Copy Account ID", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Add Contact Form

struct AddContactForm: View {
    @Binding var name: String
    @Binding var accountId: String
    var error: String?
    var isLoading: Bool
    var onSave: () -> Void
    var onCancel: () -> Void
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, accountId
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add New Contact")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Save a Stellar account to your contacts")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                }
            }
            
            // Form Fields
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., Alice", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .name)
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 30 {
                                name = String(newValue.prefix(30))
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stellar Account ID")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("G...", text: $accountId)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .padding(14)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .accountId)
                        .onChange(of: accountId) { _, newValue in
                            if newValue.count > 56 {
                                accountId = String(newValue.prefix(56))
                            }
                        }
                }
            }
            
            // Error Message
            if let error = error {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                    Text(error)
                        .font(.system(size: 14))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button(action: onSave) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.9)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Save Contact")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .disabled(isLoading || name.isEmpty || accountId.isEmpty)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .onAppear {
            focusedField = .name
        }
    }
}

// MARK: - Main Contacts View

@MainActor
struct ContactsView: View {
    @Environment(DashboardData.self) var dashboardData
    @State private var viewModel: ContactsViewModel
    @State private var isRefreshing = false
    
    init() {
        self._viewModel = State(wrappedValue: ContactsViewModel())
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if dashboardData.userContacts.isEmpty && !dashboardData.isLoadingContacts {
                    // Empty State
                    emptyStateView
                } else {
                    // Contacts List
                    contactsListView
                }
                
                // Floating Add Button
                if !viewModel.showAddForm && viewModel.editMode == .inactive {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.showAddForm = true
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        LinearGradient(
                                            colors: [.blue, .blue.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !dashboardData.userContacts.isEmpty {
                        EditButton()
                            .environment(\.editMode, $viewModel.editMode)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.editMode == .active && !viewModel.selectedContacts.isEmpty {
                        Button("Delete") {
                            Task {
                                await viewModel.deleteSelectedContacts(dashboardData: dashboardData)
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search contacts")
            .refreshable {
                await refreshData()
            }
        }
        .sheet(isPresented: $viewModel.showAddForm) {
            AddContactForm(
                name: $viewModel.newContactName,
                accountId: $viewModel.newContactAccountId,
                error: viewModel.addContactError,
                isLoading: viewModel.isAddingContact,
                onSave: {
                    Task {
                        await viewModel.addContact(dashboardData: dashboardData)
                    }
                },
                onCancel: {
                    viewModel.clearForm()
                    viewModel.showAddForm = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete Contact", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.contactToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let contact = viewModel.contactToDelete {
                    Task {
                        await viewModel.deleteContact(contact, dashboardData: dashboardData)
                    }
                }
            }
        } message: {
            if let contact = viewModel.contactToDelete {
                Text("Are you sure you want to delete \(contact.name)?")
            }
        }
        .toast(isPresenting: $viewModel.showToast) {
            AlertToast(type: .regular, title: viewModel.toastMessage)
        }
        .onAppear {
            Task {
                await refreshData()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("No Contacts Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Add your first contact to send payments quickly")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.showAddForm = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Contact")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding(40)
    }
    
    private var contactsListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if dashboardData.isLoadingContacts {
                    ForEach(0..<3) { _ in
                        ContactCardSkeleton()
                    }
                } else {
                    ForEach(viewModel.filteredContacts(dashboardData.userContacts)) { contact in
                        ContactCard(
                            contact: contact,
                            isSelected: viewModel.selectedContacts.contains(contact.id),
                            onTap: viewModel.editMode == .active ? {
                                if viewModel.selectedContacts.contains(contact.id) {
                                    viewModel.selectedContacts.remove(contact.id)
                                } else {
                                    viewModel.selectedContacts.insert(contact.id)
                                }
                            } : nil,
                            onDelete: {
                                viewModel.prepareToDelete(contact)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
    
    private func refreshData() async {
        withAnimation {
            isRefreshing = true
        }
        
        await dashboardData.loadUserContacts()
        
        withAnimation {
            isRefreshing = false
        }
        
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
}

// MARK: - Skeleton Loading

struct ContactCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 120, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 180, height: 12)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: isAnimating
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    ContactsView()
        .environment(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
}