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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        handleSubmit()
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isSubmitting)
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Required Information")
                                .font(.headline)
                            Text("Please provide your KYC details")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if let customerId = viewModel.customerId {
                        HStack {
                            Label("Customer ID", systemImage: "person.crop.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text(customerId)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
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
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
                    .padding(.horizontal)
                    .transition(.scale.combined(with: .opacity))
                }
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
        VStack(alignment: .leading, spacing: 8) {
            // Label
            HStack {
                Text(info.key)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !info.optional {
                    Text("*")
                        .foregroundStyle(.orange)
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
                        Text(value == selectItem ? "Select \(info.key)" : value)
                            .foregroundStyle(value == selectItem ? .secondary : .primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        focusedField.wrappedValue == info.key ? Color.blue : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    )
                }
            } else {
                // Text field for regular input
                TextField(info.key, text: $value)
                    .textFieldStyle(.plain)
                    .focused(focusedField, equals: info.key)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        focusedField.wrappedValue == info.key ? Color.blue : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: focusedField.wrappedValue)
            }
            
            // Description
            if let description = info.info.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}