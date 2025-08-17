//
//  Sep6TransferResponseView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 31.07.25.
//

import SwiftUI
import UIKit
import stellar_wallet_sdk
import AlertToast

// MARK: - Deposit Instruction Model

struct DepositInstruction: Identifiable, Hashable {
    let id = UUID()
    let key: String
    let value: String
    let description: String
    
    internal init(key: String, value: String, description: String?) {
        self.key = key
        self.value = value
        self.description = description ?? ""
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Transfer Response View

struct Sep6TransferResponseView: View {
    
    private let response: Sep6TransferResponse
    @State private var depositInstructions: [DepositInstruction] = []
    @State private var showToast = false
    @State private var toastMessage: String = ""
    @State private var copiedText: String = ""
    
    internal init(response: Sep6TransferResponse) {
        self.response = response
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch response {
            case .missingKYC(let fields):
                MissingKYCView(fields: fields)
                
            case .pending(let status, let moreInfoUrl, let eta):
                PendingStatusView(status: status, moreInfoUrl: moreInfoUrl, eta: eta)
                
            case .withdrawSuccess(let accountId, let memoType, let memo, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo):
                WithdrawalSuccessView(
                    accountId: accountId,
                    memoType: memoType,
                    memo: memo,
                    id: id,
                    eta: eta,
                    minAmount: minAmount,
                    maxAmount: maxAmount,
                    feeFixed: feeFixed,
                    feePercent: feePercent,
                    extraInfo: extraInfo,
                    onCopy: copyToClipboard
                )
                
            case .depositSuccess(let how, let id, let eta, let minAmount, let maxAmount, let feeFixed, let feePercent, let extraInfo, let instructions):
                DepositSuccessView(
                    how: how,
                    id: id,
                    eta: eta,
                    minAmount: minAmount,
                    maxAmount: maxAmount,
                    feeFixed: feeFixed,
                    feePercent: feePercent,
                    extraInfo: extraInfo,
                    instructions: instructions,
                    depositInstructions: $depositInstructions,
                    onCopy: copyToClipboard
                )
                .onAppear {
                    prepareDepositInstructions(instructions)
                }
            }
        }
        .toast(isPresenting: $showToast) {
            AlertToast(
                displayMode: .banner(.pop),
                type: .complete(.green),
                title: toastMessage,
                subTitle: copiedText,
                style: .style(
                    backgroundColor: Color(.systemBackground),
                    titleColor: .primary,
                    subTitleColor: .secondary
                )
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func copyToClipboard(text: String) {
        UIPasteboard.general.string = text
        copiedText = text
        toastMessage = "Copied to clipboard"
        showToast = true
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func prepareDepositInstructions(_ instructions: [String: Sep6DepositInstruction]?) {
        guard let instructions = instructions else { return }
        
        depositInstructions = instructions.map { key, instruction in
            DepositInstruction(
                key: key,
                value: instruction.value,
                description: instruction.description
            )
        }.sorted { $0.key < $1.key }
    }
}

// MARK: - Missing KYC View

struct MissingKYCView: View {
    let fields: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("KYC Required")
                        .font(.headline)
                    Text("Additional information needed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Text("Your transfer has been submitted, but the anchor requires additional KYC information.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !fields.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Required fields:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(fields, id: \.self) { field in
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(.orange)
                            Text(field)
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}

// MARK: - Pending Status View

struct PendingStatusView: View {
    let status: String
    let moreInfoUrl: String?
    let eta: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transfer Pending")
                        .font(.headline)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Text("Your transfer has been submitted and is currently being processed by the anchor.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                if let eta = eta {
                    HStack {
                        Label("ETA", systemImage: "timer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(eta) seconds")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                if let url = moreInfoUrl {
                    HStack {
                        Label("More Info", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Link(destination: URL(string: url)!) {
                            HStack(spacing: 4) {
                                Text("View Details")
                                    .font(.caption)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}

// MARK: - Withdrawal Success View

struct WithdrawalSuccessView: View {
    let accountId: String?
    let memoType: String?
    let memo: String?
    let id: String?
    let eta: Int?
    let minAmount: Double?
    let maxAmount: Double?
    let feeFixed: Double?
    let feePercent: Double?
    let extraInfo: Sep6ExtraInfo?
    let onCopy: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Withdrawal Submitted")
                        .font(.headline)
                    if let id = id {
                        Text("ID: \(id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Text("Your withdrawal request has been submitted. You may need to provide additional information. Check the transaction history for current status.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 0) {
                if let accountId = accountId {
                    InfoRow(
                        label: "Account ID",
                        value: accountId,
                        showCopy: true,
                        onCopy: { onCopy(accountId) }
                    )
                    Divider().padding(.horizontal)
                }
                
                if let memo = memo {
                    InfoRow(
                        label: "Memo",
                        value: memo,
                        showCopy: true,
                        onCopy: { onCopy(memo) }
                    )
                    if memoType != nil {
                        Divider().padding(.horizontal)
                    }
                }
                
                if let memoType = memoType {
                    InfoRow(label: "Memo Type", value: memoType)
                    if eta != nil {
                        Divider().padding(.horizontal)
                    }
                }
                
                if let eta = eta {
                    InfoRow(label: "ETA", value: "\(eta) seconds")
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            
            if let message = extraInfo?.message {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}

// MARK: - Deposit Success View

struct DepositSuccessView: View {
    let how: String?
    let id: String?
    let eta: Int?
    let minAmount: Double?
    let maxAmount: Double?
    let feeFixed: Double?
    let feePercent: Double?
    let extraInfo: Sep6ExtraInfo?
    let instructions: [String: Sep6DepositInstruction]?
    @Binding var depositInstructions: [DepositInstruction]
    let onCopy: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deposit Submitted")
                        .font(.headline)
                    if let id = id {
                        Text("ID: \(id)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            Text("Your deposit request has been submitted. You may need to provide additional information. Check the transaction history for current status.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if id != nil || how != nil || eta != nil {
                VStack(spacing: 0) {
                    if let id = id {
                        InfoRow(label: "Transfer ID", value: id)
                        if how != nil || eta != nil {
                            Divider().padding(.horizontal)
                        }
                    }
                    
                    if let how = how {
                        InfoRow(label: "Method", value: how)
                        if eta != nil {
                            Divider().padding(.horizontal)
                        }
                    }
                    
                    if let eta = eta {
                        InfoRow(label: "ETA", value: "\(eta) seconds")
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
            }
            
            if !depositInstructions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Deposit Instructions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ForEach(depositInstructions) { instruction in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(instruction.key)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.blue)
                            
                            HStack {
                                Text(instruction.value)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Button(action: { onCopy(instruction.value) }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            
                            if !instruction.description.isEmpty {
                                Text(instruction.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.05))
                        )
                    }
                }
            }
            
            if let message = extraInfo?.message {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let label: String
    let value: String
    var showCopy: Bool = false
    var onCopy: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
            
            if showCopy, let onCopy = onCopy {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
    }
}