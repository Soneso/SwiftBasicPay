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

    @State private var errorMessage:String?
    @State private var showSep6DepositSheet = false
    
    var body: some View {
        VStack {
            
            if let error = errorMessage {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
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
                if sep6Info?.withdraw != nil {
                    Button("Withdraw", action:   {
                        Task {
                            
                        }
                    }).buttonStyle(.borderedProminent).tint(.red)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var sep24TransferButtonsView : some View {
        VStack {
            Utils.divider
            Text("SEP-24 Transfers").font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if sep24Info?.deposit != nil {
                    Button("Deposit", action:   {
                        Task {
                            
                        }
                    }).buttonStyle(.borderedProminent).tint(.green)
                }
                if sep24Info?.withdraw != nil {
                    Button("Withdraw", action:   {
                        Task {
                            
                        }
                    }).buttonStyle(.borderedProminent).tint(.red)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
