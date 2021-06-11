//
//  NPCItem.swift
//  Neocom
//
//  Created by Artem Shimanski on 3/29/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI

struct NPCItem: View {
    @EnvironmentObject private var storage: Storage
    
    var body: some View {
        NavigationLink(destination: NPCGroup()) {
            Icon(Image("criminal"))
            Text("NPC")
        }.id(storage.currentLanguagID)
    }
}

struct NPCItem_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            List {
                NPCItem()
            }.listStyle(GroupedListStyle())
        }
    }
}
