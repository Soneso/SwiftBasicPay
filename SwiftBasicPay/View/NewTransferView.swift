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
                    Text(loadingText)
                        .padding(.leading)
                }
            } else if state == .sep10AuthPinRequired {
                Text("Enter your pin to authenticate with the asset's anchor.").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).italic()
                pinInputField
                submitAndCanelButtons
            } else if state == .sep10Authenticated{
                Text("Successfully authenticated with anchor").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).italic()
            }
            
        }.padding()
    }
    
    
    enum NewTransferViewState : Int {
        typealias RawValue = Int
        
        case initial = 0
        case loading = 1
        case sep10AuthPinRequired = 3
        case sep10Authenticated = 4
    }
    
    
    var anchoredAssets: [AnchoredAssetInfo] {
        dashboardData.anchoredAssets
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
        guard let selectedAsset = selectedAssetInfo, let signingKeyPair = userKeyPair else {
            resetState()
            errorMessage = "Internal error, please try again"
            return
        }
        do {
            let sep10 = try await selectedAsset.anchor.sep10
            sep10AuthToken = try await sep10.authenticate(userKeyPair: signingKeyPair)
        } catch {
            pinErrorMessage = error.localizedDescription
            state = .sep10AuthPinRequired
            return
        }
        state = .sep10Authenticated
        
    }
    
    private func resetState() {
        errorMessage = nil
        selectedAssetItem = NewTransferView.selectAsset
        selectedAssetInfo = nil
        pinErrorMessage = nil
        sep10AuthToken = nil
        loadingText = "Loading"
        state = .initial
    }
}

#Preview {
    NewTransferView().environmentObject(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
}
