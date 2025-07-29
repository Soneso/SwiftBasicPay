//
//  NewTransferView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 29.07.25.
//

import SwiftUI
import stellar_wallet_sdk

struct NewTransferView: View {
    
    /// Holds the current user data.
    @EnvironmentObject var dashboardData: DashboardData
    
    private static let selectAsset = "Select"
    
    @State private var selectedAsset = selectAsset
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Here you can initiate a transfer with an anchor for your assets which have the needed infrastructure available.").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).italic().foregroundColor(.black)
            Utils.divider
            HStack {
                Text("Asset:").font(.subheadline)
                if anchoredAssets.isEmpty {
                    Text("no anchored assets found").font(.subheadline)
                } else {
                    assetSelectionPicker
                }
            }
        }.padding()
    }
    
    
    var anchoredAssets: [AnchoredAssetInfo] {
        dashboardData.anchoredAssets
    }
    
    private var assetSelectionPicker: some View {
        Picker("select asset", selection: $selectedAsset) {
            ForEach(anchoredAssets, id: \.self) { issuedAsset in
                Text("\(issuedAsset.code)").italic().foregroundColor(.black).tag(issuedAsset.id)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NewTransferView().environmentObject(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
}
