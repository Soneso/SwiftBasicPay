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
    @State private var pin:String = ""
    @State private var showSecret = false
    @State private var secretKey:String?
    @State private var isGettingSecret:Bool = false
    @State private var getSecretErrorMsg:String?
    
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
                } else {
                    balancesView
                    Spacer()
                    myDataView
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
    
    private var myDataView: some View  {
        GroupBox ("My data"){
            Utils.divider
            Text("Address").italic().foregroundColor(.black).frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(userAddress).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                Button("", systemImage: "doc.on.doc") {
                    copyToClipboard(text: userAddress)
                }
            }.padding(EdgeInsets(top: 5, leading: 0, bottom: 10, trailing: 0))
            Toggle("Show secret key", isOn: $showSecret).padding(.vertical, 10.0)
            if showSecret {
                
                if let secret = secretKey {
                    Text("Secret key:").bold().font(.body).frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        Text(secret).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).foregroundColor(.red)
                        Button("", systemImage: "doc.on.doc") {
                            copyToClipboard(text: secret)
                        }
                    }.padding(.vertical, 10.0)
                } else {
                    SecureField("Enter your pin to show secret key", text: $pin).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        .padding(.vertical, 10.0).onChange(of: self.pin, { oldValue, value in
                            if value.count > 6 {
                                self.pin = String(value.prefix(6))
                           }
                       })
                    if let error = getSecretErrorMsg {
                        Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                    }
                    if isGettingSecret {
                        Utils.progressView
                    } else {
                        HStack {
                            Button("Submit", action:   {
                                Task {
                                    getSecretErrorMsg = nil
                                    await getSecretKey()
                                }
                            }).buttonStyle(.borderedProminent).tint(.green).padding(.vertical, 20.0)
                            Button("Cancel", action:   {
                                getSecretErrorMsg = nil
                                showSecret = false
                            }).buttonStyle(.borderedProminent).tint(.red).padding(.vertical, 20.0)
                        }
                    }
                }
            }
        }
    }
    
    private func getSecretKey() async {
        isGettingSecret = true
        let authService = AuthService()
        do {
            secretKey = try authService.userKeyPair(pin: self.pin).secretKey
        } catch {
            getSecretErrorMsg = error.localizedDescription
        }
        isGettingSecret = false
    }
    
    private var balancesView: some View  {
        GroupBox ("Balances"){
            Utils.divider
            if !accountFunded {
                fundAccountView
            } else {
                List(assets, id: \.id) { asset in
                    let formattedBalance = Utils.removeTrailingZerosFormAmount(amount: asset.balance)
                    Text("\(formattedBalance) \(asset.code)").italic().foregroundColor(.black)
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
                accountFunded = true
                assets = try await StellarService.loadAssetsForAddress(address: userAddress)
            }
        } catch {
            viewErrorMsg = error.localizedDescription
        }
        
        
        isLoadingData = false
    }
    
    private func copyToClipboard(text:String) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = text
        toastMessage = "Copied to clipboard"
        showToast = true
    }
}

#Preview {
    Overview(userAddress: "GAG4MYEEIJZ7DGS2PGCEEY5PX3HMZC7L7KK62BFLJ3LSYQIS4TYC4ETJ")
}
