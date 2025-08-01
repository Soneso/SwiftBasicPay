//
//  AssetsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import stellar_wallet_sdk

struct AssetsView: View {
    
    /// Holds the current user data.
    @EnvironmentObject var dashboardData: DashboardData
    
    // static menu item
    private static let customAssetItem = "Custom asset"
    
    /// State variables for updating the UI
    @State private var viewErrorMsg:String?
    @State private var selectedAsset = customAssetItem
    @State private var pin:String = ""
    @State private var isAddingAsset:Bool = false
    @State private var addAssetErrorMsg:String?
    @State private var assetCode:String = ""
    @State private var assetIssuer:String = ""
    @State private var isEnteringPinForRemoval = false
    @State private var removeAssetErrorMsg:String?
    @State private var showSheet = false
    @State private var selectedAssetToRemove:IssuedAssetId?
    @State private var isRemovingAsset:Bool = false
    
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                Label("Assets", systemImage: "bitcoinsign.arrow.circlepath")
                Utils.divider
                Text("Here you can manage the Stellar assets your account carries trustlines to. Select from pre-suggested assets, or specify your own asset to trust using an asset code and issuer public key. You can also remove trustlines that already exist on your account.").font(.subheadline).multilineTextAlignment(.leading).italic().foregroundColor(.black)
                Utils.divider
                if let error = viewErrorMsg {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
                if dashboardData.userAssets.isEmpty {
                    BalancesBox().environmentObject(dashboardData)
                } else {
                    addAssetView
                    balancesView
                }
            }.padding()
        }
    }
    
    private var addAssetView: some View {
        GroupBox ("Add trusted asset"){
            Utils.divider
            Text("Add a trustline on your account, allowing you to hold the specified asset:").font(.subheadline).multilineTextAlignment(.leading).italic().foregroundColor(.black)
            Picker("select asset", selection: $selectedAsset) {
                ForEach(assetsToAdd, id: \.self) { asset in
                    Text("\(asset.id)").italic().foregroundColor(.black).tag(asset.id)
                }
                Text(AssetsView.customAssetItem).italic().foregroundColor(.black).tag(AssetsView.customAssetItem)
            }.padding(.vertical, 20)
            
            if isAddingAsset {
                Utils.progressViewWithLabel("Adding asset")
            } else if dashboardData.isLoadingAssets {
                Utils.progressViewWithLabel("Loading assets")
            }
            else {
                if selectedAsset == AssetsView.customAssetItem {
                    TextField("Asset code", text: $assetCode).textFieldStyle(.roundedBorder)
                        .onChange(of: self.assetCode, { oldValue, value in
                            if value.count > 12 {
                                self.assetCode = String(value.prefix(12))
                           }
                        })
                    TextField("Issuer account id", text: $assetIssuer).textFieldStyle(.roundedBorder)
                        .onChange(of: self.assetIssuer, { oldValue, value in
                            if value.count > 56 {
                                self.assetIssuer = String(value.prefix(56))
                           }
                        })
                }
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
                }).buttonStyle(.borderedProminent).tint(.green).padding(.top, 10.0)
            }
            
        }
    }
    
    /// the assets with their balances hold by the user
    var userAssets: [AssetInfo] {
        dashboardData.userAssets
    }
    
    /// assets to add, that can be listed in the picker
    var assetsToAdd:[IssuedAssetId] {
        var result = StellarService.testAnchorAssets
        for asset in userAssets {
            result = result.filter {$0.id != asset.id}
        }
        return result
    }
    
    private var balancesView: some View  {
        GroupBox ("Balances"){
            Utils.divider
            if let error = removeAssetErrorMsg {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                Utils.divider
            }
            if isRemovingAsset || dashboardData.isLoadingAssets {
                Utils.progressView
            } else {
                ForEach(userAssets, id: \.id) { asset in
                    Spacer()
                    if let issuedAsset = asset.asset as? IssuedAssetId, Double(asset.balance) == 0 {
                        HStack {
                            Text("\(asset.formattedBalance) \(asset.code)").italic().foregroundColor(.black).frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                Task {
                                    await startRemovingAsset(asset:issuedAsset)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }.buttonStyle(.borderless).frame(maxWidth: .infinity, alignment: .trailing).tint(.green)
                        }
                    } else {
                        Text("\(asset.formattedBalance) \(asset.code)").italic().foregroundColor(.black).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }.sheet(isPresented: $showSheet) {
            pinSheet
        }
    }
    
    
    private func addAsset() async {

        addAssetErrorMsg = nil
        if pin.isEmpty {
            addAssetErrorMsg = "please enter your pin"
            return
        }
        
        Task { @MainActor in
            isAddingAsset = true
        }

            
        let authService = AuthService()
        do {
            let assetToAdd = try await getSelectedAsset()
            let userKeyPair = try authService.userKeyPair(pin: self.pin)
            let success = try await StellarService.addAssetSupport(asset: assetToAdd, userKeyPair: userKeyPair)
            if !success {
                addAssetErrorMsg = "Error submitting transaction. Please try again."
                isAddingAsset = false
                return
            }
            assetCode = ""
            assetIssuer = ""
            pin = ""
            selectedAsset = AssetsView.customAssetItem
            await loadData()
        } catch {
            addAssetErrorMsg = error.localizedDescription
        }
        
        Task { @MainActor in
            isAddingAsset = false
        }
    }
    
    private func getSelectedAsset() async throws -> IssuedAssetId {
        if selectedAsset != AssetsView.customAssetItem {
            guard let selectedIssuedAsset = assetsToAdd.filter({$0.id == selectedAsset}).first else {
                throw DemoError.runtimeError("Error finding selected asset")
            }
            return selectedIssuedAsset
        } else {
            do {
                // validate format
                let selectedIssuedAsset = try IssuedAssetId(code: assetCode, issuer: assetIssuer)
                // check if issuer exists
                let issuerExists = try await StellarService.accountExists(address: assetIssuer)
                if (!issuerExists) {
                    throw DemoError.runtimeError("Asset issuer not found on the Stellar Network")
                }
                return selectedIssuedAsset
            } catch {
                throw DemoError.runtimeError(error.localizedDescription)
            }
        }
    }
    
    private func startRemovingAsset(asset:IssuedAssetId) async {
        selectedAssetToRemove = asset
        showSheet = true
    }
    
    internal func onSuccessPinToRemoveAsset(_ signingKey:SigningKeyPair) -> Void {
        showSheet = false
        guard let assetToRemove = selectedAssetToRemove else {
            return
        }
        removeAssetErrorMsg = nil
        Task {
            isRemovingAsset = true
            do {
                let success = try await StellarService.removeAssetSupport(asset: assetToRemove, userKeyPair: signingKey)
                if !success {
                    removeAssetErrorMsg = "Error submitting transaction. Please try again."
                    isRemovingAsset = false
                    return
                }
            
                selectedAsset = AssetsView.customAssetItem
                await loadData()
            } catch {
                removeAssetErrorMsg = error.localizedDescription
            }
            isRemovingAsset = false
            selectedAssetToRemove = nil
        }
    }
    
    internal func onCancelPinToRemoveAsset() -> Void {
        showSheet = false
        selectedAssetToRemove = nil
    }
    
    private var pinSheet: PinSheet {
        PinSheet(onSuccess: onSuccessPinToRemoveAsset, onCancel: onCancelPinToRemoveAsset)
    }
    
    private func loadData() async {
        await dashboardData.fetchUserAssets()
        if let error = dashboardData.userAssetsLoadingError {
            switch error {
            case .accountNotFound(_):
                break
            case .fetchingError(let message):
                viewErrorMsg = message
            }
        }
    }
}

#Preview {
    AssetsView().environmentObject(DashboardData(userAddress: "GAG4MYEEIJZ7DGS2PGCEEY5PX3HMZC7L7KK62BFLJ3LSYQIS4TYC4ETJ"))
    // not funded: GADABN2XLZ2EYWOQJJVGKCIHJ2PJERSQGLX6TQTGOYPODPNI4OYXGN36
}
