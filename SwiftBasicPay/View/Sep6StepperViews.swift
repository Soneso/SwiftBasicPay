//
//  Sep6StepperViews.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 02.08.25.
//

import SwiftUI
import UIKit
import stellar_wallet_sdk

// MARK: - Step Progress Indicator

struct Sep6StepProgressBar: View {
    let currentStep: Sep6StepState
    let totalSteps: Int = Sep6StepState.allCases.count
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * CGFloat(currentStep.rawValue) / CGFloat(totalSteps),
                            height: 8
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentStep)
                }
            }
            .frame(height: 8)
            
            // Step indicators
            HStack(spacing: 0) {
                ForEach(Sep6StepState.allCases, id: \.self) { step in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(currentStep.rawValue >= step.rawValue ? Color.blue : Color(.systemGray4))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .scaleEffect(currentStep == step ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentStep)
                        
                        Text(step.title)
                            .font(.caption2)
                            .foregroundStyle(currentStep == step ? .primary : .secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if step != Sep6StepState.allCases.last {
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Amount Input Field

struct Sep6AmountInputField: View {
    @Binding var transferAmount: String
    let minAmount: Double
    let maxAmount: Double?
    let assetCode: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                HStack {
                    TextField("0.00", text: $transferAmount)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .onChange(of: transferAmount) { oldValue, newValue in
                            // Only allow valid decimal input
                            if newValue != "" && Double(newValue) == nil {
                                transferAmount = oldValue
                            }
                        }
                    
                    Text(assetCode)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            }
            
            // Min/Max indicators
            HStack {
                Label {
                    Text("Min: \(minAmount.toStringWithoutTrailingZeros)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                
                if let max = maxAmount {
                    Label {
                        Text("Max: \(max.toStringWithoutTrailingZeros)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - KYC Status View

struct Sep6KycStatusView: View {
    let kycInfo: GetCustomerResponse
    let onDelete: () -> Void
    
    var statusColor: Color {
        switch kycInfo.sep12Status {
        case .accepted: return .green
        case .processing: return .orange
        case .rejected: return .red
        case .neesdInfo: return .blue
        default: return .gray
        }
    }
    
    var statusIcon: String {
        switch kycInfo.sep12Status {
        case .accepted: return "checkmark.circle.fill"
        case .processing: return "clock.fill"
        case .rejected: return "xmark.circle.fill"
        case .neesdInfo: return "info.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    var statusMessage: String {
        switch kycInfo.sep12Status {
        case .accepted: return "Your KYC data has been accepted"
        case .processing: return "Your KYC data is being processed"
        case .rejected: return "Your KYC data has been rejected"
        case .neesdInfo: return "Additional KYC information required"
        default: return "Unknown KYC status"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("KYC Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(statusMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if kycInfo.sep12Status == .accepted {
                    Button(action: onDelete) {
                        Label("Delete", systemImage: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(statusColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - KYC Fields Input

struct Sep6KycFields: View {
    let kycFieldInfos: [KycFieldInfo]
    @Binding var collectedKycDetails: [String]
    let selectItem: String
    let indexForKycFieldKey: (String) -> Int
    
    var body: some View {
        VStack(spacing: 16) {
            if !collectedKycDetails.isEmpty {
                ForEach(kycFieldInfos, id: \.key) { info in
                    VStack(alignment: .leading, spacing: 8) {
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
                        
                        if let choices = info.info.choices, !choices.isEmpty {
                            Menu {
                                ForEach(choices, id: \.self) { choice in
                                    Button(choice) {
                                        collectedKycDetails[indexForKycFieldKey(info.key)] = choice
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(collectedKycDetails[indexForKycFieldKey(info.key)] == selectItem ? 
                                         "Select \(info.key)" : collectedKycDetails[indexForKycFieldKey(info.key)])
                                        .foregroundStyle(collectedKycDetails[indexForKycFieldKey(info.key)] == selectItem ? 
                                                       .secondary : .primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray6))
                                )
                            }
                        } else {
                            TextField(info.key, text: $collectedKycDetails[indexForKycFieldKey(info.key)])
                                .textFieldStyle(.plain)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray6))
                                )
                        }
                        
                        if let description = info.info.description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Transfer Fields Input

struct Sep6TransferFields: View {
    let transferFieldInfos: [TransferFieldInfo]
    @Binding var collectedTransferDetails: [String]
    let selectItem: String
    let indexForTransferFieldKey: (String) -> Int
    
    var body: some View {
        VStack(spacing: 16) {
            if !collectedTransferDetails.isEmpty {
                ForEach(transferFieldInfos, id: \.key) { info in
                    VStack(alignment: .leading, spacing: 8) {
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
                        
                        if let choices = info.info.choices, !choices.isEmpty {
                            Menu {
                                ForEach(choices, id: \.self) { choice in
                                    Button(choice) {
                                        collectedTransferDetails[indexForTransferFieldKey(info.key)] = choice
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(collectedTransferDetails[indexForTransferFieldKey(info.key)] == selectItem ? 
                                         "Select \(info.key)" : collectedTransferDetails[indexForTransferFieldKey(info.key)])
                                        .foregroundStyle(collectedTransferDetails[indexForTransferFieldKey(info.key)] == selectItem ? 
                                                       .secondary : .primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray6))
                                )
                            }
                        } else {
                            TextField(info.key, text: $collectedTransferDetails[indexForTransferFieldKey(info.key)])
                                .textFieldStyle(.plain)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(.systemGray6))
                                )
                        }
                        
                        if let description = info.info.description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Fee View

struct Sep6FeeView: View {
    let isLoadingFee: Bool
    let fee: Double?
    let feeError: String?
    let assetCode: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingFee {
                TransferProgressIndicator(message: "Loading fee information", progress: nil)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "banknote")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transfer Fee")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let anchorFee = fee {
                                Text("\(anchorFee.toStringWithoutTrailingZeros) \(assetCode)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            } else {
                                Text("No fee information available")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    if let error = feeError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Summary View

struct Sep6SummaryView: View {
    let isSubmitting: Bool
    let submissionResponse: Sep6TransferResponse?
    let transferAmount: String
    let fee: Double?
    let submissionError: String?
    let assetCode: String
    let operationName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isSubmitting {
                TransferProgressIndicator(message: "Submitting transfer to anchor", progress: nil)
            } else if let response = submissionResponse {
                Sep6TransferResponseView(response: response)
            } else {
                // Summary card
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: operationName == "Deposit" ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(operationName == "Deposit" ? .green : .blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(operationName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Transfer Summary")
                                .font(.headline)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    
                    Divider()
                    
                    // Amount row
                    HStack {
                        Text("Amount")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("\(transferAmount.amountWithoutTrailingZeros) \(assetCode)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Fee row
                    HStack {
                        Text("Fee")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if let anchorFee = fee {
                            Text("\(anchorFee.toStringWithoutTrailingZeros) \(assetCode)")
                                .font(.subheadline)
                        } else {
                            Text("Unknown")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    
                    if let totalAmount = Double(transferAmount), let feeAmount = fee {
                        Divider()
                            .padding(.horizontal)
                        
                        // Total row
                        HStack {
                            Text("Total")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\((totalAmount + feeAmount).toStringWithoutTrailingZeros) \(assetCode)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                
                if let error = submissionError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                    )
                }
            }
        }
    }
}

// MARK: - Navigation Buttons

struct Sep6NavigationButtons: View {
    let currentStep: Sep6StepState
    let submissionResponse: Sep6TransferResponse?
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onSubmit: () -> Void
    let onClose: () -> Void
    @State private var showConfirmation = false
    
    var body: some View {
        HStack(spacing: 16) {
            if submissionResponse == nil && currentStep.canGoBack {
                Button(action: onPrevious) {
                    Label("Back", systemImage: "chevron.left")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Spacer()
            
            if currentStep == .summary {
                if submissionResponse == nil {
                    Button(action: {
                        showConfirmation = true
                    }) {
                        Label("Submit Transfer", systemImage: "paperplane.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .confirmationDialog(
                        "Confirm Transfer",
                        isPresented: $showConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Submit Transfer", role: .none) {
                            onSubmit()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to submit this transfer?")
                    }
                } else {
                    Button(action: onClose) {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                Button(action: onNext) {
                    Label("Continue", systemImage: "chevron.right")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}