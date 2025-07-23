//
//  ContactsView.swift
//  SwiftBasicPay
//
//  Created by Christian Rogobete on 27.06.25.
//

import SwiftUI
import stellar_wallet_sdk
import AlertToast

// Very basic contacts view for this demo. In your wallet you should implement a better one ;)
struct ContactsView: View {
    
    @EnvironmentObject var dashboardData: DashboardData
    
    @State private var addMode = false
    @State private var isAddingContact = false
    @State private var newContactName:String = ""
    @State private var newContactAccountId:String = ""
    @State private var addContactError:String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Label("Contacts", systemImage: "person")
            Utils.divider
            List {
                ForEach(userContacts) { item in
                    VStack(spacing: 5) {
                        Text(item.name).foregroundColor(Color.blue).frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.accountId).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            if addMode {
                addContactView
            } else {
                Button("Add", action:   {
                    addMode.toggle()
                }).buttonStyle(.borderedProminent).tint(.blue)
            }
        }
    }
    
    var userContacts: [ContactInfo] {
        dashboardData.userContacts
    }
    
    private var addContactView: some View { 
        GroupBox ("Add new contact"){
            TextField("Name", text: $newContactName).textFieldStyle(.roundedBorder)
                .padding(.vertical, 10.0).onChange(of: self.newContactName, { oldValue, value in
                    if value.count > 30 {
                        self.newContactName = String(value.prefix(30))
                   }
                })
            TextField("Account id", text: $newContactAccountId).textFieldStyle(.roundedBorder)
                .padding(.vertical, 10.0).onChange(of: self.newContactAccountId, { oldValue, value in
                    if value.count > 56 {
                        self.newContactAccountId = String(value.prefix(56))
                   }
                })
            Utils.divider
            if let error = addContactError {
                Text("\(error)").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .center)
                Utils.divider
            }
            HStack {
                if isAddingContact {
                    Utils.progressView
                } else {
                    Button("Save", action:   {
                        Task {
                            await addContact(name: self.newContactName, accountId: self.newContactAccountId)
                        }
                    }).buttonStyle(.borderedProminent).tint(.green)
                    Button("Cancel", action:   {
                        addMode.toggle()
                    }).buttonStyle(.borderedProminent).tint(.red)
                }
            }
        }
    }
    private func addContact(name: String, accountId:String) async {
        if name.isEmpty || accountId.isEmpty {
            addContactError = "Please name and account id."
            return
        }
        if userContacts.filter({$0.name == name}).count > 0 {
            addContactError = "Name already exists."
            return
        }
        
        // TODO: add to sdk + check muxed account id also
        if !accountId.isValidEd25519PublicKey() {
            addContactError = "Invalid account id"
            return
        }
        
        do {
            isAddingContact.toggle()
            let extists = try await StellarService.accountExists(address: accountId)
            if !extists {
                addContactError = "Account does not exist on the Stellar Network"
                isAddingContact.toggle()
                return
            }
            var contactListData = userContacts
            contactListData.append(ContactInfo(name: name, accountId: accountId))
            try SecureStorage.saveContacts(contacts: contactListData)
            await dashboardData.loadUserContacts()
            addMode.toggle()
            isAddingContact.toggle()
            newContactName = ""
            newContactAccountId = ""
        } catch {
            addContactError = error.localizedDescription
            isAddingContact.toggle()
        }
    }
    
    func deleteItems(at offsets: IndexSet) {
        var contactListData = userContacts
        contactListData.remove(atOffsets: offsets)
        try? SecureStorage.saveContacts(contacts: contactListData)
        Task {
            await dashboardData.loadUserContacts()
        }
    }

}

#Preview {
    ContactsView()
}
