//
//  AssetsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import AlertToast

struct AssetsView: View {
    
    @State private var showToast = false
    @State private var toastMessage:String = ""
    @State private var isFundingAccount:Bool = false
    @State private var accountFunded:Bool = true
    @State private var isLoadingData:Bool = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 20) {
                Text("Assets").foregroundColor(Color.blue).multilineTextAlignment(.leading).bold().font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                Utils.divider
                Text("Here you can manage the Stellar assets your account carries trustlines to. Select from pre-suggested assets, or specify your own asset to trust using an asset code and issuer public key. You can also remove trustlines that already exist on your account.").italic().foregroundColor(.black)
            }.padding().toast(isPresenting: $showToast){
                AlertToast(type: .regular, title: "\(toastMessage)")
            }
        }
    }
}

#Preview {
    AssetsView()
}
