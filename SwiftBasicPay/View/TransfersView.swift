//
//  TransfersView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import stellar_wallet_sdk

struct TransfersView: View {
    
    /// Holds the current user data.
    @EnvironmentObject var dashboardData: DashboardData
    
    private static let selectAsset = "Select Asset"
    
    @State private var mode: Int = 1 // 1 = initiate new transfer, 2 = history
    @State private var isLoadingAssets = false
    @State private var errorMessage:String?
    @State private var selectedAssetItem = selectAsset
    @State private var selectedAssetInfo:AnchoredAssetInfo?
    @State private var state:TransfersViewState = .initial
    @State private var loadingText = "Loading"
    @State private var pin:String = ""
    @State private var pinErrorMessage:String?
    @State private var sep10AuthToken:AuthToken?
    @State private var tomlInfo:TomlInfo?
    @State private var sep6Info:Sep6Info?
    @State private var sep24Info:Sep24Info?
    
    enum TransfersViewState : Int {
        typealias RawValue = Int
        
        case initial = 0
        case loading = 1
        case sep10AuthPinRequired = 3
        case transferInfoLoaded = 4
    }
    
    var body: some View {
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
                    Utils.progressViewWithLabel("Loading anchored assets")
                } else if anchoredAssets.isEmpty {
                    Text("No anchored assets found. Please trust an anchored asset first. You can use the Assets tab to do so. E.g. SRT")
                } else if let error = dashboardData.userAnchoredAssetsLoadingError {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                } else {
                    let info = mode == 1 ? "Here you can initiate a transfer with an anchor for your assets which have the needed infrastructure available." :
                    "Here you can see a history of your transactions with their details."
                    Text(info).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).italic().foregroundColor(.black)
                    Utils.divider
                    HStack {
                        Text("Asset:").font(.subheadline)
                        assetSelectionPicker
                    }
                    if let error = errorMessage {
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                    }
                    if state == .loading {
                        Utils.progressViewWithLabel(loadingText)
                    } else if state == .sep10AuthPinRequired {
                        Text("Enter your pin to authenticate with the asset's anchor.").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).italic()
                        pinInputField
                        submitAndCanelButtons
                    } else if state == .transferInfoLoaded {
                        if let assetInfo = selectedAssetInfo, let authToken = sep10AuthToken {
                            if mode == 1 {
                                NewTransferView(assetInfo: assetInfo,
                                                authToken: authToken,
                                                sep6Info: sep6Info,
                                                sep24Info: sep24Info,
                                                savedKycData: dashboardData.userKycData).frame(maxWidth: .infinity, alignment: .leading)
                            } else if (mode == 2) {
                                TransferHistoryView(assetInfo: assetInfo, authToken: authToken)
                            }
                        }
                        
                    }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear() {
            Task {
                isLoadingAssets = true
                await dashboardData.fetchAnchoredAssets()
                isLoadingAssets = false
            }
        }
    }
    
    var anchoredAssets: [AnchoredAssetInfo] {
        dashboardData.anchoredAssets
    }
    
    private var assetSelectionPicker: some View {
        Picker("select asset", selection: $selectedAssetItem) {
            ForEach(anchoredAssets, id: \.self) { issuedAsset in
                Text("\(issuedAsset.code)").italic().foregroundColor(.black).tag(issuedAsset.id)
            }
            Text(TransfersView.selectAsset).italic().foregroundColor(.black).tag(TransfersView.selectAsset)
        }.frame(maxWidth: .infinity, alignment: .leading).onChange(of: selectedAssetItem, initial: true) { oldVal, newVal in Task {
            await selectedAssetChanged(oldValue:oldVal, newValue:newVal)
        }}
    }
    
    private func selectedAssetChanged(oldValue:String, newValue:String) async {
        selectedAssetInfo = nil
        errorMessage = nil
        state = .initial
        if newValue == TransfersView.selectAsset {
            errorMessage = nil
            return
        }
        else {
            guard let asset = anchoredAssets.filter({$0.id == newValue}).first else {
                errorMessage = "Could not find selected asset"
                return
            }
            selectedAssetInfo = asset
            await checkWebAuth(anchor: selectedAssetInfo!.anchor)
        }
    }
    
    private func checkWebAuth(anchor:stellar_wallet_sdk.Anchor) async {
        state = .loading
        loadingText = "Loading toml file from anchor"
        tomlInfo = nil
        do {
            tomlInfo = try await anchor.sep1
        } catch {
            errorMessage = "Could not load toml data from anchor: \(error.localizedDescription)"
            state = .initial
            return
        }
        
        if tomlInfo?.webAuthEndpoint == nil {
            errorMessage = "The anchor does not provide an authentication service (SEP-10)"
            state = .initial
            return
        }
        state = .sep10AuthPinRequired
    }
    
    private var pinInputField: some View {
        VStack {
            SecureField("Enter your pin", text: $pin).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                .onChange(of: self.pin, { oldValue, value in
                    if value.count > 6 {
                        self.pin = String(value.prefix(6))
                   }
            })
            if let error = pinErrorMessage {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    private var submitAndCanelButtons : some View {
        HStack {
            Button("Submit", action:   {
                Task {
                    if state == .sep10AuthPinRequired {
                        await handlePinSetForSep10Auth()
                    }
                }
            }).buttonStyle(.borderedProminent).tint(.green)
            Button("Cancel", action:   {
                resetState()
            }).buttonStyle(.borderedProminent).tint(.red)
        }
    }
    
    private func handlePinSetForSep10Auth() async {
        state = .loading
        loadingText = "Authenticating with anchor"
        var userKeyPair:SigningKeyPair?
        do {
            let authService = AuthService()
            userKeyPair = try authService.userKeyPair(pin: self.pin)
        } catch {
            pinErrorMessage = error.localizedDescription
            state = .sep10AuthPinRequired
            return
        }
        
        self.pin = ""
        
        let signingKeyPair = userKeyPair!
        guard let selectedAsset = selectedAssetInfo else {
            resetState()
            errorMessage = "Please select an asset"
            return
        }
        
        let anchor = selectedAsset.anchor
        do {
            let sep10 = try await anchor.sep10
            sep10AuthToken = try await sep10.authenticate(userKeyPair: signingKeyPair)
        } catch {
            pinErrorMessage = error.localizedDescription
            state = .sep10AuthPinRequired
            return
        }
    
        // load sep-06 & sep-24 info
        sep6Info = nil
        sep24Info = nil
        loadingText = "Loading toml file from anchor"
        
        let sep6Supported = tomlInfo?.transferServer != nil
        let sep24Supported = tomlInfo?.transferServerSep24 != nil
        if (!sep6Supported && !sep24Supported) {
            errorMessage = "The anchor does not support SEP-06 & SEP-24 transfers."
            state = .initial
            return
        }
        
        loadingText = "Loading SEP-6 info"
        
        do {
            if sep6Supported {
                sep6Info = try await anchor.sep6.info(authToken: sep10AuthToken)
            }
        } catch {
            errorMessage = "Error loading SEP-06 info from anchor: \(error.localizedDescription)."
        }
        
        loadingText = "Loading SEP-24 info"
        do {
            if sep24Supported {
                sep24Info = try await anchor.sep24.info
            }
        } catch {
            let err:String = "Error loading SEP-24 info from anchor: \(error.localizedDescription)"
            if errorMessage != nil {
                errorMessage?.append("\n\(err)")
            } else{
                errorMessage = err
            }
        }
        state = .transferInfoLoaded
        
    }
    
    private func resetState() {
        errorMessage = nil
        selectedAssetItem = TransfersView.selectAsset
        selectedAssetInfo = nil
        pinErrorMessage = nil
        sep10AuthToken = nil
        loadingText = "Loading"
        tomlInfo = nil
        pin = ""
        state = .initial
    }
    
}

#Preview {
    TransfersView().environmentObject(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
}
