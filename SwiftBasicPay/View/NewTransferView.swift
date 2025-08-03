//
//  NewTransferView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 29.07.25.
//

import SwiftUI
import stellar_wallet_sdk

struct NewTransferView: View {
    
    private var assetInfo:AnchoredAssetInfo
    private var authToken:AuthToken
    private var sep6Info:Sep6Info?
    private var sep24Info:Sep24Info?
    private var savedKycData:[KycEntry]
    
    internal init(assetInfo: AnchoredAssetInfo, 
                  authToken: AuthToken,
                  sep6Info: Sep6Info? = nil,
                  sep24Info: Sep24Info? = nil,
                  savedKycData:[KycEntry] = []) {
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
    
    var body: some View {
        VStack {
            
           
            if sep6Info != nil {
                sep6TransferButtonsView
            }
            if sep24Info != nil {
                sep24TransferButtonsView
            }
            
        }.padding()
    }
    
    
    private var sep6TransferButtonsView : some View {
        VStack {
            Utils.divider
            Text("SEP-06 Transfers").font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if let depositInfo = sep6Info?.deposit, let assetDepositInfo = depositInfo[assetInfo.code], assetDepositInfo.enabled {
                    Button("Deposit", action:   {
                        showSep6DepositSheet = true
                    }).buttonStyle(.borderedProminent).tint(.green).sheet(isPresented: $showSep6DepositSheet) {
                        Sep6DepositStepper(anchoredAsset: assetInfo,
                                           depositInfo: assetDepositInfo,
                                           authToken: authToken,
                                           anchorHasEnabledFeeEndpoint: sep6Info?.fee?.enabled ?? false,
                                           savedKycData: savedKycData)
                    }
                }
                if let withdrawInfo = sep6Info?.withdraw, let assetWithdrawInfo = withdrawInfo[assetInfo.code], assetWithdrawInfo.enabled {
                    Button("Withdraw", action:   {
                        showSep6WithdrawalSheet = true
                    }).buttonStyle(.borderedProminent).tint(.red).sheet(isPresented: $showSep6WithdrawalSheet) {
                        Sep6WithdrawalStepper(anchoredAsset: assetInfo,
                                              withdrawInfo: assetWithdrawInfo,
                                              authToken: authToken,
                                              anchorHasEnabledFeeEndpoint: sep6Info?.fee?.enabled ?? false,
                                              savedKycData: savedKycData)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var sep24TransferButtonsView : some View {
        VStack {
            Utils.divider
            Text("SEP-24 Transfers").font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
            if isLoadingSep24InteractiveUrl {
                Utils.progressViewWithLabel("Requesting interactive URL")
            } else {
                if let error = loadingSep24InteractiveUrlErrorMessage {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
                
                HStack {
                    if let depositInfo = sep24Info?.deposit[assetInfo.code], depositInfo.enabled {
                        Button("Deposit", action: {
                            Task {
                                await initiateSep24Transfer(mode: "deposit")
                            }
                        }).buttonStyle(.borderedProminent).tint(.green)
                    }
                    if let withdrawInfo = sep24Info?.withdraw[assetInfo.code], withdrawInfo.enabled {
                        Button("Withdraw", action: {
                            Task {
                                await initiateSep24Transfer(mode: "withdraw")
                            }
                        }).buttonStyle(.borderedProminent).tint(.red)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).sheet(isPresented: $showSep24InteractiveUrlSheet) {
                    if let url = sep24InteractiveUrl, let mode = sep24OperationMode {
                        let title = "SEP-24 \(mode.capitalized)"
                        InteractiveWebViewSheet(url: url, title: title, isPresented: $showSep24InteractiveUrlSheet)
                    }
                }
            }
        }
    }
    
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
