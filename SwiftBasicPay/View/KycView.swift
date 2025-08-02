//
//  KycView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI

// Basic kyc view for this demo. In your wallet you should implement a better one ;)
struct KycView: View {
    
    /// Holds the current user data.
    @EnvironmentObject var dashboardData: DashboardData
    
    @State private var selectedItem:KycEntry?
    @State private var errorMessage:String?
    @State private var newVal = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Label("My KYC data", systemImage: "shield.lefthalf.filled.badge.checkmark")
            Utils.divider
            if selectedItem != nil {
                VStack {
                    Text("\(selectedItem!.keyLabel)").bold().font(.subheadline).frame(maxWidth: .infinity, alignment: .center)
                    TextField("Value", text: $newVal).textFieldStyle(.roundedBorder)
                        .padding(.vertical, 10.0).onChange(of: newVal, { oldValue, value in
                            if value.count > 30 {
                                newVal = String(value.prefix(30))
                           }
                        })
                    HStack {
                        Button("Save", action:   {
                            Task {
                                await saveEditedValue()
                            }
                        }).buttonStyle(.borderedProminent).tint(.green).padding(.vertical, 20.0)
                        Button("Cancel", action:   {
                            selectedItem = nil
                        }).buttonStyle(.borderedProminent).tint(.red).padding(.vertical, 20.0)
                    }
                }.frame(maxWidth: .infinity, alignment: .topTrailing)
            }
            if let error = errorMessage {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
            }
            List {
                ForEach(userKycData) { item in
                    HStack {
                        VStack {
                            Text(item.keyLabel).foregroundColor(Color.blue).frame(maxWidth: .infinity, alignment: .leading)
                            Text(item.val.isEmpty ? "not yet provided" : item.val).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button("", systemImage: "square.and.pencil") {
                            editItem(item: item)
                        }
                    }
                }
            }
            
        }
    }
    
    private func editItem(item:KycEntry) {
        errorMessage = nil
        newVal = item.val
        selectedItem = item
    }
    
    var userKycData: [KycEntry] {
        dashboardData.userKycData
    }
    
    private func saveEditedValue() async {
        if let item = selectedItem {
            do {
                let _ = try SecureStorage.updateKycDataEntry(id: item.id, val: newVal)
                await dashboardData.loadUserKycData()
            } catch {
                errorMessage = "Error storing data: \(error.localizedDescription)"
            }
        }
        newVal = ""
        selectedItem = nil
    }
}
