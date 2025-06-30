//
//  AssetsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import stellar_wallet_sdk
import AlertToast

struct AssetsView: View {
    
    public let userAddress:String
    private static let customAssetItem = "Custom asset"
    @State private var showToast = false
    @State private var toastMessage:String = ""
    @State private var isFundingAccount:Bool = false
    @State private var accountFunded:Bool = true
    @State private var isLoadingData:Bool = false
    @State private var viewErrorMsg:String?
    @State private var assets:[AssetInfo] = []
    @State private var assetsToAdd:[IssuedAssetId] = StellarService.testnetAssets()
    @State private var selectedAsset = customAssetItem
    @State private var pin:String = ""
    @State private var isAddingAsset:Bool = false
    @State private var addAssetErrorMsg:String?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                Text("Assets").foregroundColor(Color.blue).multilineTextAlignment(.leading).bold().font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                Utils.divider
                Text("Here you can manage the Stellar assets your account carries trustlines to. Select from pre-suggested assets, or specify your own asset to trust using an asset code and issuer public key. You can also remove trustlines that already exist on your account.").italic().foregroundColor(.black)
                Utils.divider
                if let error = viewErrorMsg {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
                if isLoadingData {
                    Utils.progressView
                } else if !accountFunded {
                    Text("Your account is not yet funded. Switch to the 'Overview' Tab to fund your account first.").italic().foregroundColor(.orange)
                } else {
                    addAssetView
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
    
    private var addAssetView: some View {
        GroupBox ("Add trusted asset"){
            Utils.divider
            Text("Add a trustline on your account, allowing you to hold the specified asset:").italic().foregroundColor(.black)
            Picker("select asset", selection: $selectedAsset) {
                ForEach(assetsToAdd, id: \.self) { asset in
                    Text("\(asset.id)").italic().foregroundColor(.black).tag(asset.id as String)
                }
                Text(AssetsView.customAssetItem).italic().foregroundColor(.black).tag(AssetsView.customAssetItem as String)
            }.padding(.vertical, 20)
            
            if isAddingAsset {
                HStack {
                    Utils.progressView
                    Spacer()
                    Text("Adding asset").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            else {
                SecureField("Enter pin to add asset", text: $pin).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    .padding(.vertical, 10.0).onChange(of: self.pin, { oldValue, value in
                        if value.count > 6 {
                            self.pin = String(value.prefix(6))
                       }
                    })
                if let error = addAssetErrorMsg {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
                Button("Submit", action:   {
                    Task {
                        await addAsset()
                    }
                }).buttonStyle(.borderedProminent).tint(.green).padding(.vertical, 20.0)
            }
            
        }
    }
    
    private var balancesView: some View  {
        GroupBox ("Exsiting Balances"){
            Utils.divider
            List(assets, id: \.id) { asset in
                let formattedBalance = Utils.removeTrailingZerosFormAmount(amount: asset.balance)
                Text("\(formattedBalance) \(asset.code)").italic().foregroundColor(.black)
            }.listStyle(.automatic).frame(height: CGFloat((assets.count * 65) + (assets.count < 4 ? 40 : 0)), alignment: .top)
        }
    }
    
    private func addAsset() async {

        addAssetErrorMsg = nil
        if pin.isEmpty {
            addAssetErrorMsg = "please enter your pin"
            isAddingAsset = false
            return
        }
        
        let authService = AuthService()
        isAddingAsset = true
        do {
            
            let userKeyPair = try authService.userKeyPair(pin: self.pin)
            if selectedAsset != AssetsView.customAssetItem {
                guard let selectedIssuedAsset = assetsToAdd.filter({$0.id == selectedAsset}).first else {
                    addAssetErrorMsg = "Error finding selected asset"
                    isAddingAsset = false
                    return
                }
                let success = try await StellarService.addAssetSupport(asset: selectedIssuedAsset, userKeyPair: userKeyPair)
                if !success {
                    addAssetErrorMsg = "Error submitting transaction. Please try again."
                    isAddingAsset = false
                    return
                }
                showToast = true
                toastMessage = "Asset support added"
                await loadData()
            }
        } catch {
            addAssetErrorMsg = error.localizedDescription
        }
        
        isAddingAsset = false
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
                    assetsToAdd = assetsToAdd.filter {$0.id != asset.id}
                    if (!assetsToAdd.isEmpty) {
                        selectedAsset = assetsToAdd.first!.id
                    }
                }
                
            }
        } catch {
            viewErrorMsg = error.localizedDescription
        }
        
        
        isLoadingData = false
    }
}

#Preview {
    AssetsView(userAddress: "GAG4MYEEIJZ7DGS2PGCEEY5PX3HMZC7L7KK62BFLJ3LSYQIS4TYC4ETJ")
    // not funded: GADABN2XLZ2EYWOQJJVGKCIHJ2PJERSQGLX6TQTGOYPODPNI4OYXGN36
}
