//
//  Sep6DepositStepper.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 29.07.25.
//

import SwiftUI
import stellar_wallet_sdk
import AlertToast

struct Sep6DepositStepper: View {
    
    @State private var viewModel: Sep6DepositStepperViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var errorMessage = ""
    
    internal init(anchoredAsset: AnchoredAssetInfo,
                  depositInfo: Sep6DepositInfo,
                  authToken: AuthToken,
                  anchorHasEnabledFeeEndpoint: Bool,
                  savedKycData: [KycEntry] = []) {
        self._viewModel = State(wrappedValue: Sep6DepositStepperViewModel(
            anchoredAsset: anchoredAsset,
            depositInfo: depositInfo,
            authToken: authToken,
            anchorHasEnabledFeeEndpoint: anchorHasEnabledFeeEndpoint,
            savedKycData: savedKycData
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Progress indicator
                    Sep6StepProgressBar(currentStep: viewModel.currentStep)
                        .padding(.horizontal)
                    
                    // Asset info card
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Deposit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(viewModel.anchoredAsset.code)
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        Text("Step \(viewModel.currentStep.rawValue) of 4")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    )
                    .padding(.horizontal)
                    
                    // Step content
                    VStack(spacing: 20) {
                        switch viewModel.currentStep {
                        case .transferDetails:
                            transferDetailsStep
                        case .kycData:
                            kycDataStep
                        case .fee:
                            feeStep
                        case .summary:
                            summaryStep
                        }
                    }
                    .padding(.horizontal)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
                    
                    // Navigation buttons
                    Sep6NavigationButtons(
                        currentStep: viewModel.currentStep,
                        submissionResponse: viewModel.submissionResponse,
                        onPrevious: {
                            viewModel.goToPreviousStep()
                        },
                        onNext: {
                            handleNextStep()
                        },
                        onSubmit: {
                            Task {
                                await viewModel.submitTransfer()
                            }
                        },
                        onClose: {
                            dismiss()
                        }
                    )
                    .padding()
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.blue)
                }
                ToolbarItem(placement: .principal) {
                    Text("SEP-6 Deposit")
                        .font(.headline)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .toast(isPresenting: $showError) {
            AlertToast(
                displayMode: .banner(.pop),
                type: .error(.red),
                title: errorMessage
            )
        }
    }
    
    // MARK: - Step Views
    
    @ViewBuilder
    private var transferDetailsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Enter deposit details")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Please provide the required information for your deposit")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Sep6AmountInputField(
                transferAmount: $viewModel.transferAmount,
                minAmount: viewModel.minAmount,
                maxAmount: viewModel.maxAmount,
                assetCode: viewModel.anchoredAsset.code
            )
            
            if !viewModel.transferFieldInfos.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Additional Information")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Sep6TransferFields(
                        transferFieldInfos: viewModel.transferFieldInfos,
                        collectedTransferDetails: $viewModel.collectedTransferDetails,
                        selectItem: viewModel.selectItem,
                        indexForTransferFieldKey: viewModel.indexForTransferFieldKey
                    )
                }
            }
            
            if let error = viewModel.transferFieldsError {
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
    
    @ViewBuilder
    private var kycDataStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("KYC Information")
                .font(.title3)
                .fontWeight(.semibold)
            
            if viewModel.isLoadingKyc {
                TransferProgressIndicator(message: viewModel.kycLoadingText, progress: nil)
            } else if let info = viewModel.kycInfo {
                Sep6KycStatusView(kycInfo: info) {
                    Task {
                        await viewModel.deleteKYCData()
                    }
                }
                
                if info.sep12Status == Sep12Status.neesdInfo {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Required KYC Fields")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(.top, 8)
                        
                        Sep6KycFields(
                            kycFieldInfos: viewModel.kycFieldInfos,
                            collectedKycDetails: $viewModel.collectedKycDetails,
                            selectItem: viewModel.selectItem,
                            indexForKycFieldKey: viewModel.indexForKycFieldKey
                        )
                    }
                }
                
                if let error = viewModel.kycFieldsError {
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
        .onAppear {
            if viewModel.kycInfo == nil {
                Task {
                    await viewModel.loadKYCData()
                }
            }
        }
    }
    
    @ViewBuilder
    private var feeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Transfer Fee")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Review the fee for this deposit")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Sep6FeeView(
                isLoadingFee: viewModel.isLoadingFee,
                fee: viewModel.fee,
                feeError: viewModel.feeError,
                assetCode: viewModel.anchoredAsset.code
            )
        }
        .onAppear {
            if viewModel.fee == nil && !viewModel.isLoadingFee {
                Task {
                    await viewModel.loadFeeInfo()
                }
            }
        }
    }
    
    @ViewBuilder
    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Show different header based on submission state
            if viewModel.submissionResponse != nil {
                // After submission - no need for header as Sep6TransferResponseView shows its own
                EmptyView()
            } else {
                // Before submission - show review header
                Text("Review & Confirm")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Please review your deposit details before submitting")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Sep6SummaryView(
                isSubmitting: viewModel.isSubmitting,
                submissionResponse: viewModel.submissionResponse,
                transferAmount: viewModel.transferAmount,
                fee: viewModel.fee,
                submissionError: viewModel.submissionError,
                assetCode: viewModel.anchoredAsset.code,
                operationName: viewModel.operationName
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleNextStep() {
        switch viewModel.currentStep {
        case .transferDetails:
            if viewModel.validateTransferFields() {
                viewModel.goToNextStep()
            }
        case .kycData:
            if viewModel.kycInfo?.sep12Status == Sep12Status.neesdInfo {
                if viewModel.validateKycFields() {
                    Task {
                        await viewModel.submitKYCData()
                        // Don't auto-advance - let user see the acceptance status
                        // User must click Continue again to proceed
                    }
                }
            } else if viewModel.kycInfo?.sep12Status == Sep12Status.accepted {
                viewModel.goToNextStep()
            } else {
                errorMessage = "KYC status must be accepted to continue"
                showError = true
            }
        case .fee:
            viewModel.goToNextStep()
        case .summary:
            // Handled by submit button
            break
        }
    }
}