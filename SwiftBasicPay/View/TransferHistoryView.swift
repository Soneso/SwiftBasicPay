//
//  TransferHistoryView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 29.07.25.
//

import SwiftUI

struct TransferHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("History").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).italic().foregroundColor(.black)
            Utils.divider
            
        }.padding()
    }
}

#Preview {
    TransferHistoryView()
}
