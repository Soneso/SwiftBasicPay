//
//  NewTransferView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 29.07.25.
//

import SwiftUI
import stellar_wallet_sdk

struct NewTransferView: View {
    
    private var assetInfo: AnchoredAssetInfo
    private var authToken: AuthToken
    private var sep6Info: Sep6Info?
    private var sep24Info: Sep24Info?
    private var savedKycData: [KycEntry]
    
    internal init(assetInfo: AnchoredAssetInfo,
                  authToken: AuthToken,
                  sep6Info: Sep6Info? = nil,
                  sep24Info: Sep24Info? = nil,
                  savedKycData: [KycEntry] = []) {
        self.assetInfo = assetInfo
        self.authToken = authToken
        self.sep6Info = sep6Info
        self.sep24Info = sep24Info
        self.savedKycData = savedKycData
    }
    
    @State private var showSep6DepositSheet = false
    @State private var showSep6WithdrawalSheet = false
    @State private var showSep24InteractiveUrlSheet = false
    @State private var isLoadingSep24InteractiveUrl = false
    @State private var loadingSep24InteractiveUrlErrorMessage: String?
    @State private var sep24InteractiveUrl: String?
    @State private var sep24OperationMode: String?
    @State private var hoveredButton: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Transfer options
                if sep24Info != nil {
                    sep24TransferCard
                }
                
                if sep6Info != nil {
                    sep6TransferCard
                }
                
                if sep6Info == nil && sep24Info == nil {
                    emptyStateView
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - SEP-6 Transfer Card
    
    private var sep6TransferCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "6.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("SEP-6 Transfers")
                        .font(.headline)
                    Text("Traditional transfer protocol")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Transfer buttons
            VStack(spacing: 12) {
                if let depositInfo = sep6Info?.deposit,
                   let assetDepositInfo = depositInfo[assetInfo.code],
                   assetDepositInfo.enabled {
                    
                    Button(action: {
                        showSep6DepositSheet = true
                    }) {
                        transferButton(
                            title: "Deposit",
                            icon: "arrow.down.circle.fill",
                            color: .green,
                            isHovered: hoveredButton == "sep6-deposit"
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        hoveredButton = hovering ? "sep6-deposit" : nil
                    }
                    .sheet(isPresented: $showSep6DepositSheet) {
                        Sep6DepositStepper(
                            anchoredAsset: assetInfo,
                            depositInfo: assetDepositInfo,
                            authToken: authToken,
                            anchorHasEnabledFeeEndpoint: sep6Info?.fee?.enabled ?? false,
                            savedKycData: savedKycData
                        )
                    }
                }
                
                if let withdrawInfo = sep6Info?.withdraw,
                   let assetWithdrawInfo = withdrawInfo[assetInfo.code],
                   assetWithdrawInfo.enabled {
                    
                    Button(action: {
                        showSep6WithdrawalSheet = true
                    }) {
                        transferButton(
                            title: "Withdraw",
                            icon: "arrow.up.circle.fill",
                            color: .orange,
                            isHovered: hoveredButton == "sep6-withdraw"
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { hovering in
                        hoveredButton = hovering ? "sep6-withdraw" : nil
                    }
                    .sheet(isPresented: $showSep6WithdrawalSheet) {
                        Sep6WithdrawalStepper(
                            anchoredAsset: assetInfo,
                            withdrawInfo: assetWithdrawInfo,
                            authToken: authToken,
                            anchorHasEnabledFeeEndpoint: sep6Info?.fee?.enabled ?? false,
                            savedKycData: savedKycData
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
    
    // MARK: - SEP-24 Transfer Card
    
    private var sep24TransferCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "24.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("SEP-24 Transfers")
                        .font(.headline)
                    Text("Interactive web-based transfers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if isLoadingSep24InteractiveUrl {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Requesting interactive URL...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            } else {
                if let error = loadingSep24InteractiveUrlErrorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                    )
                }
                
                // Transfer buttons
                VStack(spacing: 12) {
                    if let depositInfo = sep24Info?.deposit[assetInfo.code],
                       depositInfo.enabled {
                        
                        Button(action: {
                            Task {
                                await initiateSep24Transfer(mode: "deposit")
                            }
                        }) {
                            transferButton(
                                title: "Deposit",
                                icon: "arrow.down.circle.fill",
                                color: .green,
                                isHovered: hoveredButton == "sep24-deposit"
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            hoveredButton = hovering ? "sep24-deposit" : nil
                        }
                    }
                    
                    if let withdrawInfo = sep24Info?.withdraw[assetInfo.code],
                       withdrawInfo.enabled {
                        
                        Button(action: {
                            Task {
                                await initiateSep24Transfer(mode: "withdraw")
                            }
                        }) {
                            transferButton(
                                title: "Withdraw",
                                icon: "arrow.up.circle.fill",
                                color: .orange,
                                isHovered: hoveredButton == "sep24-withdraw"
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            hoveredButton = hovering ? "sep24-withdraw" : nil
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .sheet(isPresented: $showSep24InteractiveUrlSheet) {
            if let url = sep24InteractiveUrl, let mode = sep24OperationMode {
                let title = "SEP-24 \(mode.capitalized)"
                InteractiveWebViewSheet(url: url, title: title, isPresented: $showSep24InteractiveUrlSheet)
            }
        }
    }
    
    // MARK: - Transfer Button Component
    
    private func transferButton(title: String, icon: String, color: Color, isHovered: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
            
            Text(title)
                .fontWeight(.medium)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: isHovered ? [color.opacity(0.9), color.opacity(0.7)] : [color, color.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: color.opacity(0.3), radius: isHovered ? 8 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("No transfer options available")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("This asset doesn't support SEP-6 or SEP-24 transfers")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
    }
    
    // MARK: - Helper Methods
    
    private func initiateSep24Transfer(mode: String) async {
        await MainActor.run {
            isLoadingSep24InteractiveUrl = true
            loadingSep24InteractiveUrlErrorMessage = nil
        }
        
        do {
            let sep24 = assetInfo.anchor.sep24
            let interactiveUrl: String?
            
            if mode == "deposit" {
                let response = try await sep24.deposit(assetId: assetInfo.asset, authToken: authToken)
                interactiveUrl = response.url
            } else if mode == "withdraw" {
                let response = try await sep24.withdraw(assetId: assetInfo.asset, authToken: authToken)
                interactiveUrl = response.url
            } else {
                interactiveUrl = nil
            }
            
            await MainActor.run {
                if let url = interactiveUrl {
                    sep24InteractiveUrl = url
                    sep24OperationMode = mode
                    showSep24InteractiveUrlSheet = true
                }
                isLoadingSep24InteractiveUrl = false
            }
            
        } catch {
            await MainActor.run {
                loadingSep24InteractiveUrlErrorMessage = "Error requesting SEP-24 interactive url: \(error.localizedDescription)"
                isLoadingSep24InteractiveUrl = false
            }
        }
    }
}
