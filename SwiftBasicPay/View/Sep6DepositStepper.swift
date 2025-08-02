//
//  Sep6DepositStepper.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 29.07.25.
//

import SwiftUI
import stellar_wallet_sdk

struct Sep6DepositStepper: View {
    
    @StateObject private var viewModel: Sep6DepositStepperViewModel
    @Environment(\.dismiss) private var dismiss
    
    internal init(anchoredAsset: AnchoredAssetInfo,
                  depositInfo: Sep6DepositInfo, 
                  authToken: AuthToken,
                  anchorHasEnabledFeeEndpoint: Bool,
                  savedKycData: [KycEntry] = []) {
        self._viewModel = StateObject(wrappedValue: Sep6DepositStepperViewModel(
            anchoredAsset: anchoredAsset,
            depositInfo: depositInfo,
            authToken: authToken,
            anchorHasEnabledFeeEndpoint: anchorHasEnabledFeeEndpoint,
            savedKycData: savedKycData
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                
                Text("Asset: \(viewModel.anchoredAsset.code)").font(.subheadline)
                Text("Step \(viewModel.currentStep) of 4 - \(viewModel.stepTitles[viewModel.currentStep - 1])")
                    .font(.subheadline).fontWeight(.bold)
                

                if viewModel.currentStep == 1 {
                    Text("The anchor requested following information about your transfer:").font(.subheadline)
                    Sep6AmountInputField(
                        transferAmount: $viewModel.transferAmount,
                        minAmount: viewModel.minAmount,
                        maxAmount: viewModel.maxAmount,
                        assetCode: viewModel.anchoredAsset.code
                    )
                    Sep6TransferFields(
                        transferFieldInfos: viewModel.transferFieldInfos,
                        collectedTransferDetails: $viewModel.collectedTransferDetails,
                        selectItem: viewModel.selectItem,
                        indexForTransferFieldKey: viewModel.indexForTransferFieldKey
                    )
                    if let error = viewModel.transferFieldsError {
                        Utils.divider
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                } else if viewModel.currentStep == 2 {
                    if viewModel.isLoadingKyc {
                        Utils.progressViewWithLabel(viewModel.kycLoadingText)
                    } else if let info = viewModel.kycInfo {
                        Sep6KycStatusView(kycInfo: info) {
                            Task {
                                await viewModel.deleteKYCData()
                            }
                        }
                        if info.sep12Status == Sep12Status.neesdInfo {
                            Sep6KycFields(
                                kycFieldInfos: viewModel.kycFieldInfos,
                                collectedKycDetails: $viewModel.collectedKycDetails,
                                selectItem: viewModel.selectItem,
                                indexForKycFieldKey: viewModel.indexForKycFieldKey
                            )
                        }
                        if let error = viewModel.kycFieldsError {
                            Utils.divider
                            Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else if viewModel.currentStep == 3 {
                    Sep6FeeView(
                        isLoadingFee: viewModel.isLoadingFee,
                        fee: viewModel.fee,
                        feeError: viewModel.feeError,
                        assetCode: viewModel.anchoredAsset.code
                    )
                } else if viewModel.currentStep == 4 {
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
                Utils.divider
                Sep6NavigationButtons(
                    currentStep: viewModel.currentStep,
                    submissionResponse: viewModel.submissionResponse,
                    onPrevious: {
                        if viewModel.currentStep > 1 {
                            viewModel.currentStep -= 1
                        }
                    },
                    onNext: {
                        if viewModel.currentStep == 1 && viewModel.validateTransferFields() {
                            viewModel.currentStep += 1
                            Task {
                                await viewModel.loadKYCData()
                            }
                        } else if viewModel.currentStep == 2 {
                            if (viewModel.kycInfo?.sep12Status == Sep12Status.neesdInfo && viewModel.validateKycFields()) {
                                Task {
                                    await viewModel.submitKYCData()
                                }
                            } else if (viewModel.kycInfo?.sep12Status == Sep12Status.accepted) {
                                viewModel.currentStep += 1
                                Task {
                                    await viewModel.loadFeeInfo()
                                }
                            }
                        } else {
                            viewModel.currentStep += 1
                        }
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("SEP-06 Deposit Stepper").font(.headline).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }.navigationBarTitleDisplayMode(.inline).navigationTitle("")
        }
    }
}
