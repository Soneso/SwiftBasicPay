//
//  Sep12KycFormSheet.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 03.08.25.
//

import SwiftUI
import UIKit
import stellar_wallet_sdk
import Observation

// MARK: - View Model

@Observable
class Sep12KycFormViewModel {
    // Form state
    var collectedKycDetails: [String] = []
    var kycFieldsError: String?
    var isSubmitting = false
    
    // Data
    let customerId: String?
    let requiredFields: [String: Field]
    let savedKycData: [KycEntry]
    let txId: String
    let selectItem = "select"
    
    // Computed properties
    var kycFieldInfos: [KycFieldInfo] {
        requiredFields.keys.sorted().compactMap { key in
            guard let field = requiredFields[key] else { return nil }
            return KycFieldInfo(key: key, info: field)
        }
    }
    
    init(customerId: String?,
         requiredFields: [String: Field],
         savedKycData: [KycEntry],
         txId: String) {
        self.customerId = customerId
        self.requiredFields = requiredFields
        self.savedKycData = savedKycData
        self.txId = txId
        
        initializeKycDetails()
    }
    
    // MARK: - Methods
    
    func initializeKycDetails() {
        collectedKycDetails = kycFieldInfos.map { info in
            if let choices = info.info.choices, !choices.isEmpty {
                return selectItem
            } else {
                return savedKycData.first { $0.id == info.key }?.val ?? ""
            }
        }
    }
    
    func indexForKycFieldKey(_ key: String) -> Int {
        kycFieldInfos.firstIndex { $0.key == key } ?? -1
    }
    
    func validateKycFields() -> Bool {
        kycFieldsError = nil
        
        for (index, info) in kycFieldInfos.enumerated() {
            if !info.optional {
                let val = collectedKycDetails[index]
                if val.isEmpty || val == selectItem {
                    kycFieldsError = "\(info.key) is required"
                    
                    // Error haptic feedback
                    let notificationFeedback = UINotificationFeedbackGenerator()
                    notificationFeedback.notificationOccurred(.error)
                    
                    return false
                }
            }
        }
        
        return true
    }
    
    var preparedKycData: [String: String] {
        var result: [String: String] = [:]
        
        for (index, info) in kycFieldInfos.enumerated() {
            if collectedKycDetails.count > index {
                let val = collectedKycDetails[index]
                if !val.isEmpty && val != selectItem {
                    result[info.key] = val
                }
            }
        }
        
        return result
    }
}

// MARK: - Main View

struct Sep12KycFormSheet: View {
    @State private var viewModel: Sep12KycFormViewModel
    @Binding var isPresented: Bool
    let onSubmit: (String?, [String: String], String) async -> Void
    
    @FocusState private var focusedField: String?
    @State private var showValidationError = false
    
    init(customerId: String?,
         requiredFields: [String: Field],
         savedKycData: [KycEntry],
         txId: String,
         onSubmit: @escaping (String?, [String: String], String) async -> Void,
         isPresented: Binding<Bool>) {
        
        let viewModel = Sep12KycFormViewModel(
            customerId: customerId,
            requiredFields: requiredFields,
            savedKycData: savedKycData,
            txId: txId
        )
        self._viewModel = State(wrappedValue: viewModel)
        self.onSubmit = onSubmit
        self._isPresented = isPresented
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isSubmitting {
                    ProgressView {
                        Text("Submitting KYC data...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    formContent
                }
            }
            .navigationTitle("KYC Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismissKeyboard()
                        isPresented = false
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
    }
    
    // MARK: - Form Content
    
    @ViewBuilder
    private var formContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header card
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Required Information")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Please provide your KYC details")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(.systemGray))
                        }
                        
                        Spacer()
                    }
                    
                    if let customerId = viewModel.customerId {
                        HStack {
                            Label("Customer ID", systemImage: "person.crop.circle")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(.systemGray))
                            
                            Spacer()
                            
                            Text(customerId)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.systemGray6).opacity(0.5))
                        )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
                )
                
                // Form fields
                VStack(spacing: 20) {
                    ForEach(Array(viewModel.kycFieldInfos.enumerated()), id: \.element.key) { index, info in
                        KycFieldInput(
                            info: info,
                            value: $viewModel.collectedKycDetails[index],
                            selectItem: viewModel.selectItem,
                            focusedField: $focusedField
                        )
                    }
                }
                .padding(.horizontal)
                
                // Error message
                if showValidationError, let error = viewModel.kycFieldsError {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Submit button
                Button(action: handleSubmit) {
                    HStack {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Text("Submit")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.isSubmitting ? Color.gray : Color.blue)
                    )
                }
                .disabled(viewModel.isSubmitting)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
        .onTapGesture {
            dismissKeyboard()
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleSubmit() {
        dismissKeyboard()
        
        guard viewModel.validateKycFields() else {
            showValidationError = true
            
            // Auto-hide error after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showValidationError = false
                }
            }
            return
        }
        
        Task {
            viewModel.isSubmitting = true
            let kycData = viewModel.preparedKycData
            
            await onSubmit(viewModel.customerId, kycData, viewModel.txId)
            
            viewModel.isSubmitting = false
            isPresented = false
            
            // Success haptic feedback
            await MainActor.run {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            }
        }
    }
    
    private func dismissKeyboard() {
        focusedField = nil
    }
}

// MARK: - KYC Field Input Component

struct KycFieldInput: View {
    let info: KycFieldInfo
    @Binding var value: String
    let selectItem: String
    var focusedField: FocusState<String?>.Binding
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Label
            HStack(spacing: 4) {
                Text(formatFieldLabel(info.key))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                
                if !info.optional {
                    Text("*")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.orange)
                }
                
                Spacer()
            }
            
            // Input field
            if let choices = info.info.choices, !choices.isEmpty {
                // Dropdown menu for choices
                Menu {
                    ForEach(choices, id: \.self) { choice in
                        Button(choice) {
                            value = choice
                            
                            // Selection haptic feedback
                            let selectionFeedback = UISelectionFeedbackGenerator()
                            selectionFeedback.selectionChanged()
                        }
                    }
                } label: {
                    HStack {
                        Text(value == selectItem ? "Select \(formatFieldLabel(info.key))" : value)
                            .font(.system(size: 16))
                            .foregroundStyle(value == selectItem ? Color(.placeholderText) : .primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(.systemGray2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        focusedField.wrappedValue == info.key ? Color.blue.opacity(0.5) : Color(.systemGray4),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
            } else {
                // Text field for regular input
                TextField(formatFieldPlaceholder(info.key), text: $value)
                    .font(.system(size: 16))
                    .textFieldStyle(.plain)
                    .focused(focusedField, equals: info.key)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        focusedField.wrappedValue == info.key ? Color.blue.opacity(0.5) : Color(.systemGray4),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .autocorrectionDisabled()
                    .keyboardType(getKeyboardType(for: info.key))
                    .textInputAutocapitalization(getAutoCapitalization(for: info.key))
                    .animation(.easeInOut(duration: 0.2), value: focusedField.wrappedValue)
            }
            
            // Description
            if let description = info.info.description {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.systemGray))
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // Helper function to format field labels
    private func formatFieldLabel(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ")
           .split(separator: " ")
           .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
           .joined(separator: " ")
    }
    
    // Helper function to format field placeholders
    private func formatFieldPlaceholder(_ key: String) -> String {
        let label = formatFieldLabel(key).lowercased()
        return label
    }
    
    // Helper function to determine keyboard type
    private func getKeyboardType(for key: String) -> UIKeyboardType {
        let lowercasedKey = key.lowercased()
        if lowercasedKey.contains("email") || lowercasedKey.contains("e-mail") || lowercasedKey.contains("e_mail") {
            return .emailAddress
        } else if lowercasedKey.contains("phone") || lowercasedKey.contains("mobile") || lowercasedKey.contains("tel") {
            return .phonePad
        } else if lowercasedKey.contains("number") || lowercasedKey.contains("amount") || lowercasedKey.contains("zip") || lowercasedKey.contains("postal") {
            return .numberPad
        } else if lowercasedKey.contains("url") || lowercasedKey.contains("website") {
            return .URL
        }
        return .default
    }
    
    // Helper function to determine auto-capitalization
    private func getAutoCapitalization(for key: String) -> TextInputAutocapitalization {
        let lowercasedKey = key.lowercased()
        if lowercasedKey.contains("email") || lowercasedKey.contains("e-mail") || lowercasedKey.contains("e_mail") {
            return .never
        } else if lowercasedKey.contains("name") || lowercasedKey.contains("city") || lowercasedKey.contains("country") {
            return .words
        } else if lowercasedKey.contains("address") {
            return .words
        }
        return .sentences
    }
}