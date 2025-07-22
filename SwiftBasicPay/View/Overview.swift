//
//  Overview.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import AlertToast

struct Overview: View {
    
    @EnvironmentObject var dashboardData: DashboardData
    
    @State private var showToast = false
    @State private var toastMessage:String = ""
    @State private var isFundingAccount:Bool = false
    @State private var viewErrorMsg:String?
    @State private var pin:String = ""
    @State private var showSecret = false
    @State private var secretKey:String?
    @State private var isGettingSecret:Bool = false
    @State private var getSecretErrorMsg:String?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                Label("Overview", systemImage: "list.dash")
                if let error = viewErrorMsg {
                    Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
                balancesView
                myDataView
                RecentPaymentsView().environmentObject(dashboardData)
            }.padding().toast(isPresenting: $showToast){
                AlertToast(type: .regular, title: "\(toastMessage)")
            }
        }.onAppear() {
            Task {
                if (dashboardData.userAssets.isEmpty) {
                    await dashboardData.fetchUserAssets()
                    await dashboardData.loadUserContacts()
                    await dashboardData.fetchRecentPayments()
                }
            }
        }
    }
    
    private var myDataView: some View  {
        GroupBox ("My data"){
            Utils.divider
            Text("Address:").font(.subheadline).italic().foregroundColor(.black).frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(dashboardData.userAddress).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                Button("", systemImage: "doc.on.doc") {
                    copyToClipboard(text: dashboardData.userAddress)
                }
            }.padding(EdgeInsets(top: 5, leading: 0, bottom: 10, trailing: 0))
            Toggle("Show secret key", isOn: $showSecret).padding(.vertical, 10.0).onChange(of: showSecret) { oldValue, newValue in
                if oldValue && !newValue {
                    secretKey = nil
                }
            }
            if showSecret {
                
                if let secret = secretKey {
                    Text("Secret key:").bold().font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
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
        self.pin = ""
        isGettingSecret = false
    }
    
    var userAssets: [AssetInfo] {
        dashboardData.userAssets
    }
    
    private var balancesView: some View  {
        GroupBox ("Balances"){
            Utils.divider
            if dashboardData.isLoadingAssets {
                Utils.progressView
            } else if let error = dashboardData.error {
                switch error {
                case .accountNotFound(_):
                    fundAccountView
                case .fetchingError(let message):
                    Utils.divider
                    Text("\(message)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ForEach(userAssets, id: \.id) { asset in
                    Spacer()
                    Text("\(asset.formattedBalance) \(asset.code)").italic().foregroundColor(.black).frame(maxWidth: .infinity, alignment: .leading)
                }
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
            try await StellarService.fundTestnetAccount(address: dashboardData.userAddress)
            await dashboardData.fetchUserAssets()
        } catch {
            viewErrorMsg = error.localizedDescription
        }
        isFundingAccount = false
    }
    
    private func copyToClipboard(text:String) {
        let pasteboard = UIPasteboard.general
        pasteboard.string = text
        toastMessage = "Copied to clipboard"
        showToast = true
    }
}

#Preview {
    Overview().environmentObject(DashboardData(userAddress: "GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5"))
    // GBDKRTMVEL2PK7BHHDDEL6J2QPFGXQW37GTOK42I54TZY23URZTSETR5
}
