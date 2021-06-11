//
//  FleetBarCell.swift
//  Neocom
//
//  Created by Artem Shimanski on 4/30/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI
import Dgmpp
import Expressible

struct FleetBarCell: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.self) private var environment
    @ObservedObject var currentShip: DGMShip
    @EnvironmentObject private var gang: DGMGang
    var pilot: DGMCharacter
    var onClose: () -> Void
    
    private var closeButton: some View {
        Group {
            if gang.pilots.count > 1 {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }.accentColor(.primary)
            }
        }
    }
    
    var body: some View {
        let type = pilot.ship?.type(from: managedObjectContext)
        let name = pilot.ship?.name
        let isSelected = currentShip == pilot.ship
        
        return HStack {
            Spacer()
            if type != nil {
                Icon(type!.image).cornerRadius(4)
            }
            VStack(alignment: .leading) {
                type?.typeName.map {Text($0)} ?? Text("Unknown")
                if name?.isEmpty == false {
                    Text(name!).modifier(SecondaryLabelModifier())
                }
            }.lineLimit(1)
            Spacer()
            closeButton.layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(minHeight: 50)
        .padding(8)
        .background(isSelected ? RoundedRectangle(cornerRadius: 8).foregroundColor(Color(.systemBackground)).edgesIgnoringSafeArea(.all) : nil)
        .opacity(isSelected ? 1.0 : 0.5)
    }
}

#if DEBUG
struct FleetBarCell_Previews: PreviewProvider {
    static var previews: some View {
        let gang = DGMGang.testGang()
        
        return HStack {
            FleetBarCell(currentShip: gang.pilots[0].ship!, pilot: gang.pilots[0]) {}
            FleetBarCell(currentShip: gang.pilots[0].ship!, pilot: gang.pilots[1]) {}
        }.padding()
        .environmentObject(gang)
        .modifier(ServicesViewModifier.testModifier())

    }
}
#endif
