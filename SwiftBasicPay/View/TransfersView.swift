//
//  TransfersView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI

struct TransfersView: View {
    
    /// Holds the current user data.
    @EnvironmentObject var dashboardData: DashboardData
    
    @State private var mode: Int = 1 // 1 = initiate new transfer, 2 = history
    @State private var isLoadingAssets = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                Label("Transfers", systemImage: "paperplane")
                Utils.divider
                if dashboardData.userAssets.isEmpty {
                    // user account not funded
                    BalancesBox().environmentObject(dashboardData)
                } else {
                    Picker(selection: $mode, label: Text("Select")) {
                        Text("New").tag(1)
                        Text("History").tag(2)
                    }.pickerStyle(.segmented)
   
                    if isLoadingAssets {
                        Utils.divider
                        HStack {
                            Utils.progressView
                            Text("Loading anchored assets")
                                .padding(.leading)
                        }
                    } else if dashboardData.anchoredAssets.isEmpty {
                        Text("No anchored assets found. Please trust an anchored asset first. You can use the Assets tab to do so. E.g. SRT")
                    } else if let error = dashboardData.userAnchoredAssetsLoadingError {
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                    } else if mode == 1 { // initiate new transfer
                        NewTransferView().environmentObject(dashboardData)
                    } else if mode == 2 { // history
                        TransferHistoryView().environmentObject(dashboardData)
                    }
                }
                
            }.padding()
        }.onAppear() {
            Task {
                isLoadingAssets = true
                await dashboardData.fetchAnchoredAssets()
                isLoadingAssets = false
            }
        }
    }
}

#Preview {
    TransfersView().environmentObject(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
}
