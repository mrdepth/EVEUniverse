//
//  CertificateRequirementsInfo.swift
//  Neocom
//
//  Created by Artem Shimanski on 12/24/19.
//  Copyright © 2019 Artem Shimanski. All rights reserved.
//

import SwiftUI
import Expressible

struct CertificateRequirementsInfo: View {
    var types: FetchedResultsController<SDEInvType>
    @Environment(\.managedObjectContext) var managedObjectContext

    
    var body: some View {
        ForEach(types.sections, id: \.name) { section in
            Section(header: Text(section.name.uppercased())) {
                ForEach(section.objects, id: \.objectID) { type in
                    NavigationLink(destination: TypeInfo(type: type)) {
                        TypeCell(type: type)
                    }
                }
            }
        }
    }
}

#if DEBUG
struct CertificateRequirementsInfo_Previews: PreviewProvider {
    static var previews: some View {
        let certificate = try! Storage.testStorage.persistentContainer.viewContext
            .from(SDECertCertificate.self)
            .filter((/\SDECertCertificate.certificateName).contains("Armor"))
            .first()!

        func types() -> FetchedResultsController<SDEInvType> {
            let controller = Storage.testStorage.persistentContainer.viewContext.from(SDEInvType.self)
                .filter(/\SDEInvType.published == true && (/\SDEInvType.certificates).contains(certificate))
                .sort(by: \SDEInvType.group?.groupName, ascending: true)
                .fetchedResultsController(sectionName: (/\SDEInvType.group?.groupName), cacheName: nil)
            return FetchedResultsController(controller)
        }
        
        return List {
            CertificateRequirementsInfo(types: types())
        }.listStyle(GroupedListStyle())
        .modifier(ServicesViewModifier.testModifier())
    }
}
#endif
