//
//  BalancesBox.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 23.07.25.
//

import SwiftUI

struct BalancesBox: View {
    
    /// Holds the current user data.
    @EnvironmentObject var dashboardData: DashboardData
    
    /// State variable used to update the UI
    @State private var isFundingAccount:Bool = false
    @State private var errorMsg:String?
    
    var body: some View {
        GroupBox ("Balances"){
            Utils.divider
            if dashboardData.isLoadingAssets {
                Utils.progressView
            } else if let error = dashboardData.userAssetsLoadingError {
                switch error {
                case .accountNotFound(_):
                    fundAccountView
                case .fetchingError(let message):
                    Utils.divider
                    Text("\(message)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
            } else if let errorMsg = errorMsg {
                Utils.divider
                Text("\(errorMsg)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(userAssets, id: \.id) { asset in
                    Spacer()
                    Text("\(asset.formattedBalance) \(asset.code)").italic().foregroundColor(.black).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    var userAssets: [AssetInfo] {
        dashboardData.userAssets
    }
    
    private var fundAccountView: some View  {
        VStack {
            Text("Your account does not exist on the Stellar Test Network and needs to be funded!").italic().foregroundColor(.black)
            Utils.divider
            if isFundingAccount {
                Utils.progressView
            } else {
                Button("Fund on Testnet", action:   {
                    Task {
                        await fundAccount()
                    }
                }).buttonStyle(.borderedProminent).tint(.green).padding(.vertical, 20.0)
            }
        }
    }
    
    private func fundAccount() async {
        isFundingAccount = true
        do {
            try await StellarService.fundTestnetAccount(address: dashboardData.userAddress)
            await dashboardData.fetchStellarData()
        } catch {
            errorMsg = "Error funding account: \(error.localizedDescription)"
        }
        isFundingAccount = false
    }
}

#Preview {
    BalancesBox()
}
