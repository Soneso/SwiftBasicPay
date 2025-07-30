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
    
    private static let selectAsset = "Select Asset"
    
    @State private var state:NewTransferViewState = .initial
    
    @State private var selectedAssetItem = selectAsset
    @State private var errorMessage:String?
    @State private var pinErrorMessage:String?
    @State private var selectedAssetInfo:AnchoredAssetInfo?
    @State private var pin:String = ""
    @State private var sep10AuthToken:AuthToken?
    @State private var loadingText = "Loading"
    @State private var sep6Info:Sep6Info?
    @State private var sep24Info:Sep24Info?
    @State private var showSep6DepositSheet = false
    
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
            if let error = errorMessage {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
            if state == .loading {
                HStack {
                    Utils.progressView
                    Text(loadingText).padding(.leading).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if state == .sep10AuthPinRequired {
                Text("Enter your pin to authenticate with the asset's anchor.").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).italic()
                pinInputField
                submitAndCanelButtons
            } else if state == .transferInfoLoaded {
                if sep6Info != nil {
                    sep6TransferButtonsView
                }
                if sep24Info != nil {
                    sep24TransferButtonsView
                }
            }
            
        }.padding()
    }
    
    
    enum NewTransferViewState : Int {
        typealias RawValue = Int
        
        case initial = 0
        case loading = 1
        case sep10AuthPinRequired = 3
        case transferInfoLoaded = 4
    }
    
    
    var anchoredAssets: [AnchoredAssetInfo] {
        dashboardData.anchoredAssets
    }
    
    private var sep6TransferButtonsView : some View {
        VStack {
            Utils.divider
            Text("SEP-06 Transfers").font(.subheadline).fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if let depositInfo = sep6Info?.deposit, let anchoredAssset = selectedAssetInfo, let assetDepositInfo = depositInfo[anchoredAssset.code], assetDepositInfo.enabled, let authToken = sep10AuthToken {
                    Button("Deposit", action:   {
                        showSep6DepositSheet = true
                    }).buttonStyle(.borderedProminent).tint(.green).sheet(isPresented: $showSep6DepositSheet) {
                        Sep6DepositStepper(anchoredAsset: anchoredAssset, depositInfo: assetDepositInfo, authToken: authToken)
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
    
    private var assetSelectionPicker: some View {
        Picker("select asset", selection: $selectedAssetItem) {
            ForEach(anchoredAssets, id: \.self) { issuedAsset in
                Text("\(issuedAsset.code)").italic().foregroundColor(.black).tag(issuedAsset.id)
            }
            Text(NewTransferView.selectAsset).italic().foregroundColor(.black).tag(NewTransferView.selectAsset)
        }.frame(maxWidth: .infinity, alignment: .leading).onChange(of: selectedAssetItem, initial: true) { oldVal, newVal in Task {
            await selectedAssetChanged(oldValue:oldVal, newValue:newVal)
        }}
    }
    
    private func selectedAssetChanged(oldValue:String, newValue:String) async {
        selectedAssetInfo = nil
        errorMessage = nil
        state = .initial
        if newValue == NewTransferView.selectAsset {
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
        var tomlInfo:TomlInfo?
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
        var tomlInfo:TomlInfo?
        do {
            tomlInfo = try await anchor.sep1
        } catch {
            errorMessage = "Could not load toml data from anchor: \(error.localizedDescription)"
            state = .initial
            return
        }
        
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
        selectedAssetItem = NewTransferView.selectAsset
        selectedAssetInfo = nil
        pinErrorMessage = nil
        sep10AuthToken = nil
        loadingText = "Loading"
        sep6Info = nil
        sep24Info = nil
        state = .initial
    }
}

#Preview {
    NewTransferView().environmentObject(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
}
