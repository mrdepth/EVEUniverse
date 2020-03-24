//
//  LoadoutsLoader.swift
//  Neocom
//
//  Created by Artem Shimanski on 3/20/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import Foundation
import Combine
import SwiftUI
import CoreData
import Expressible

class LoadoutsLoader: ObservableObject {
    
    struct Section: Identifiable  {
        var title: String?
        var id: Int32?
        struct Loadout: Identifiable {
            var typeID: Int32
            var name: String?
            var typeName: String
            var objectID: NSManagedObjectID
            
            var id: NSManagedObjectID {return objectID}
        }
        var loadouts: [Loadout]
    }
    
    @Published var loadouts: [Section]?
    
    private let results: FetchedResultsController<Loadout>
    private var subscription: AnyCancellable?
    
    init(_ category: SDECategoryID, managedObjectContext: NSManagedObjectContext) {
        let controller = managedObjectContext.from(Loadout.self).sort(by: \Loadout.typeID, ascending: true).fetchedResultsController()
        results = FetchedResultsController(controller)
        
        managedObjectContext.perform {
            self.subscription = self.results.publisher.compactMap{$0.first?.objects}.map { loadouts -> [Section] in
                var sections = [Int32?: Section]()
                for loadout in loadouts {
                    let type = try? managedObjectContext.from(SDEInvType.self).filter(/\SDEInvType.typeID == loadout.typeID).first()
                    let groupID = type?.group?.groupID
                    sections[groupID, default: Section(title: type?.group?.groupName, id: groupID, loadouts: [])].loadouts.append(Section.Loadout(typeID: loadout.typeID, name: loadout.name, typeName: type?.typeName ?? "", objectID: loadout.objectID))
                }
                return sections.values
                    .map{Section(title: $0.title, id: $0.id, loadouts: $0.loadouts.sorted{($0.typeName, $0.name ?? "") < ($1.typeName, $1.name ?? "")})}
                    .sorted{($0.title ?? "") < ($1.title ?? "")}
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] loadouts in
                self?.loadouts = loadouts
            }
        }
        
    }
}
