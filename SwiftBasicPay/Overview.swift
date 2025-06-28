//
//  Overview.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import AlertToast

struct Overview: View {
    
    public let userAddress:String
    @State private var showToast = false
    @State private var toastMessage:String = ""
    @State private var isLoadingData:Bool = false
    @State private var isFundingAccount:Bool = false
    @State private var accountFunded:Bool = true
    @State private var viewErrorMsg:String?
    @State private var balancesErrorMsg:String?
    @State private var assets:[AssetInfo] = []
    
    internal init(userAddress: String) {
        self.userAddress = userAddress
    }
    
        
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                Text("Overview").foregroundColor(Color.blue).multilineTextAlignment(.leading).bold().font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                if let error = viewErrorMsg {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
                if isLoadingData {
                    Utils.progressView
                }else {
                    balancesView
                }
            }.padding().toast(isPresenting: $showToast){
                AlertToast(type: .regular, title: "\(toastMessage)")
            }
        }.onAppear() {
            Task {
                await loadData()
            }
        }
    }
    
    private var balancesView: some View  {
        GroupBox ("Balances"){
            Utils.divider
            if !accountFunded {
                fundAccountView
            } else {
                List(assets, id: \.id) { asset in
                    var name = asset.id == "native" ? "XLM" : asset.id
                    Text("\(asset.balance) \(name)").italic().foregroundColor(.black)
                }.listStyle(.automatic).frame(height: CGFloat((assets.count * 65) + (assets.count < 4 ? 40 : 0)), alignment: .top)
            }
            if let error = balancesErrorMsg {
                Utils.divider
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
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
            try await StellarService.fundTestnetAccount(address: userAddress)
            await loadData()
        } catch {
            balancesErrorMsg = error.localizedDescription
        }
        isFundingAccount = false
    }
    
    private func loadData() async {
        isLoadingData = true
        do {
            let accountExists = try await StellarService.accountExists(address: userAddress)
            if !accountExists {
                accountFunded = false
            } else {
                assets = try await StellarService.loadAssetsForAddress(address: userAddress)
                for asset in assets {
                    print ("asset: \(asset.id)")
                }
            }
        } catch {
            viewErrorMsg = error.localizedDescription
        }
        
        
        isLoadingData = false
    }
}

#Preview {
    Overview(userAddress: "GAG4MYEEIJZ7DGS2PGCEEY5PX3HMZC7L7KK62BFLJ3LSYQIS4TYC4ETJ")
}
