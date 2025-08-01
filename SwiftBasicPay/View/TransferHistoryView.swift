//
//  TransferHistoryView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 29.07.25.
//

import SwiftUI
import stellar_wallet_sdk

struct TransferHistoryView: View {
    
    private var assetInfo:AnchoredAssetInfo
    private var authToken:AuthToken
    
    internal init(assetInfo: AnchoredAssetInfo, authToken: AuthToken) {
        self.assetInfo = assetInfo
        self.authToken = authToken
    }
    
    @State private var mode: Int = 1 // 1 = sep6, 2 = sep24
    @State private var isLoadingTransfers = false
    @State private var sep6ErrorMessage:String?
    @State private var sep24ErrorMessage:String?
    @State private var rawSep6Transactions:[Sep6Transaction] = []
    @State private var rawSep24Transactions:[InteractiveFlowTransaction] = []
    
    var body: some View {
        VStack() {
            if isLoadingTransfers {
                Utils.progressViewWithLabel("Loading transfers")
            } else {
                Picker(selection: $mode, label: Text("Select")) {
                    Text("SEP-06 Transfers").tag(1)
                    Text("SEP-24 Transfers").tag(2)
                }.pickerStyle(.segmented)
                
                if mode == 1 {
                    if let error = sep6ErrorMessage {
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                    }
                    ScrollView {
                        ForEach(sep6History, id: \.id) { info in
                            Text("\(info.id)").font(.subheadline).font(.caption)
                                .fontWeight(.light).italic().frame(maxWidth: .infinity, alignment: .leading)
                            Spacer(minLength: 10)
                        }
                    }.padding(.top)
                    
                } else if mode == 2 {
                    if let error = sep24ErrorMessage {
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                    }
                    ScrollView {
                        ForEach(sep24History, id: \.id) { info in
                            Text("\(info.id)").font(.subheadline).font(.caption)
                                .fontWeight(.light).italic().frame(maxWidth: .infinity, alignment: .leading)
                            Spacer(minLength: 10)
                        }
                    }.padding(.top)
                    
                }
            }
            
        }.onAppear() {
            Task {
                isLoadingTransfers = true
                await loadSep6Transfers()
                await loadSep24Transfers()
                isLoadingTransfers = false
            }
        }
    }
    
    private func loadSep6Transfers() async {
        do {
            let sep6 = assetInfo.anchor.sep6
            rawSep6Transactions = try await sep6.getTransactionsForAsset(authToken: authToken, assetCode: assetInfo.code)
        } catch {
            sep6ErrorMessage = "Error loading SEP-06 transfer history: \(error.localizedDescription)"
        }
    }
    
    private func loadSep24Transfers() async {
        do {
            let sep24 = assetInfo.anchor.sep24
            rawSep24Transactions = try await sep24.getTransactionsForAsset(authToken: authToken, asset: assetInfo.asset)
        } catch {
            sep6ErrorMessage = "Error loading SEP-24 transfer history: \(error.localizedDescription)"
        }
    }
    
    var sep6History: [Sep6TxInfo] {
        var result:[Sep6TxInfo] = []
        for rawSep6Transaction in rawSep6Transactions {
            result.append(Sep6TxInfo(raw: rawSep6Transaction))
        }
        return result
    }
    
    var sep24History: [Sep24TxInfo] {
        var result:[Sep24TxInfo] = []
        for rawSep24Transaction in rawSep24Transactions {
            result.append(Sep24TxInfo(raw: rawSep24Transaction))
        }
        return result
    }
}

public class Sep6TxInfo: Hashable, Identifiable {

    public let raw:Sep6Transaction
    
    internal init(raw: Sep6Transaction) {
        self.raw = raw
    }
    
    public var id:String {
        return raw.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw.id)
    }
    
    public static func == (lhs: Sep6TxInfo, rhs: Sep6TxInfo) -> Bool {
        lhs.raw.id == rhs.raw.id
    }
}

public class Sep24TxInfo: Hashable, Identifiable {

    public let raw:InteractiveFlowTransaction
    
    internal init(raw: InteractiveFlowTransaction) {
        self.raw = raw
    }
    
    public var id:String {
        return raw.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(raw.id)
    }
    
    public static func == (lhs: Sep24TxInfo, rhs: Sep24TxInfo) -> Bool {
        lhs.raw.id == rhs.raw.id
    }
}


