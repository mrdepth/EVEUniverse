//
//  FittingEditor.swift
//  Neocom
//
//  Created by Artem Shimanski on 2/24/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI
import Dgmpp
import EVEAPI
import Combine
import CoreData

fileprivate class FittingAutosaver: ObservableObject {
    let project: FittingProject
    
    init(project: FittingProject) {
        self.project = project
    }
    
    deinit {
        let project = self.project
        if project.hasUnsavedChanges {
            project.managedObjectContext.perform {
                project.save()
            }
        }
    }
}

//struct FittingEditor2<P>: View where P : Publisher, P.Output == FittingProject, P.Failure == Never {
//    
//    private let publisher: P
//    @State private var project: FittingProject?
//    
//    init(_ publisher: P) {
//        self.publisher = publisher
//    }
//    
//    var body: some View {
//        Group {
//            if project == nil {
//                ActivityIndicator().onReceive(publisher) {
//                    self.project = $0
//                }
//            }
//            else {
//                FittingEditor(project: project!)
//            }
//        }
//    }
//}

struct FittingEditor: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @EnvironmentObject private var sharedState: SharedState
    var project: FittingProject
    var completion: (() -> Void)? = nil
    
    private var autosaver: FittingAutosaver
    
    init(project: FittingProject, completion: (() -> Void)? = nil) {
        self.project = project
        self.completion = completion
        self.autosaver = FittingAutosaver(project: project)
    }
    
    private let priceData = Lazy<PricesData, Never>()

    var body: some View {
        let gang = project.gang
        let ship = project.structure ?? gang?.pilots.first?.ship
        
        return Group {
            if ship != nil {
                if ship is DGMStructure {
                    FittingStructureEditor(structure: ship as! DGMStructure, completion: completion)
                        .environmentObject(project)
                }
                else if gang != nil {
                    FittingShipEditor(gang: gang!, ship: ship!, completion: completion)
                        .environmentObject(project)
                }
            }
            else {
                Text(RuntimeError.invalidGang)
            }
        }
        .environmentObject(project)
        .environmentObject(priceData.get(initial: PricesData(esi: sharedState.esi)))
        .preference(key: AppendPreferenceKey<AnyUserActivityProvider, AnyUserActivityProvider>.self, value: [AnyUserActivityProvider(project)])
        .onAppear {
            self.sharedState.userActivity = self.project.userActivity
            UIApplication.shared.userActivity = self.project.userActivity
            self.sharedState.userActivity?.becomeCurrent()
        }
        .onDisappear {
            self.sharedState.userActivity?.resignCurrent()
            UIApplication.shared.userActivity = nil
            self.sharedState.userActivity = nil
            if self.project.hasUnsavedChanges {
                self.project.save()
            }
        }
    }
}

fileprivate enum Page: CaseIterable {
    case modules
    case drones
    case implants
    case fleet
    case stats
    case cargo
}


struct FittingShipEditor: View {
    @State private var currentPage = Page.modules
    @State private var isActionsPresented = false
    @State private var currentShip: DGMShip
    @ObservedObject private var gang: DGMGang
    @Environment(\.self) private var environment
    @Environment(\.managedObjectContext) private var managedObjectContext
    @EnvironmentObject private var project: FittingProject
    @EnvironmentObject private var sharedState: SharedState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var completion: (() -> Void)?
    
    init(gang: DGMGang, ship: DGMShip, completion: (() -> Void)?) {
        _gang = ObservedObject(initialValue: gang)
        _currentShip = State(initialValue: ship)
        self.completion = completion
    }
    
    private var title: String {
        let typeName = currentShip.type(from: self.managedObjectContext)?.typeName ?? "Unknown"
        let name = currentShip.name
        if name.isEmpty {
            return typeName
        }
        else {
            return "\(typeName) / \(name)"
        }
    }
    
    private var actionsButton: some View {
        BarButtonItems.actions {
            self.isActionsPresented = true
        }
        .adaptivePopover(isPresented: $isActionsPresented) {
            NavigationView {
                FittingEditorShipActions(ship: self.currentShip) {
                    self.isActionsPresented = false
                }
            }
            .modifier(ServicesViewModifier(environment: self.environment, sharedState: self.sharedState))
            .environmentObject(self.gang)
            .environmentObject(self.project)
            .navigationViewStyle(StackNavigationViewStyle())
            .frame(idealWidth: 375, idealHeight: 375 * 2)
        }
    }

    var body: some View {
        let body = VStack(spacing: 0) {
            Divider().edgesIgnoringSafeArea(.horizontal)
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Picker("Page", selection: $currentPage) {
                        Text("Modules").tag(Page.modules)
                        Text("Drones").tag(Page.drones)
                        Text("Implants").tag(Page.implants)
                        if horizontalSizeClass != .regular {
                            Text("Fleet").tag(Page.fleet)
                        }
                        Text("Cargo").tag(Page.cargo)
                        if horizontalSizeClass != .regular {
                            Text("Stats").tag(Page.stats)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    Divider()
                    if currentPage == .modules {
                        FittingEditorShipModules(ship: currentShip)
                    }
                    else if currentPage == .drones {
                        FittingEditorShipDrones(ship: currentShip)
                    }
                    else if currentPage == .implants {
                        FittingEditorImplants(ship: currentShip)
                    }
                    else if currentPage == .fleet {
                        FittingEditorFleet(ship: $currentShip)
                    }
                    else if currentPage == .stats {
                        FittingEditorStats(ship: currentShip)
                    }
                    else if currentPage == .cargo {
                        FittingCargo(ship: currentShip)
                    }
                }
                if horizontalSizeClass == .regular {
                    Divider().edgesIgnoringSafeArea(.bottom)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 1)
                        FittingEditorStats(ship: currentShip)
                    }
                }
            }
            if horizontalSizeClass == .regular {
                Divider().edgesIgnoringSafeArea(.horizontal)
                FittingEditorFleetBar(ship: $currentShip)
            }
        }
        .environmentObject(gang)
        
        return Group {
            if completion != nil {
                body.navigationBarItems(leading: BarButtonItems.close(completion!), trailing: actionsButton)
            }
            else {
                body.navigationBarItems(trailing: actionsButton)
            }
        }
        .navigationBarTitle(Text(title), displayMode: .inline)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}

struct FittingStructureEditor: View {
    @ObservedObject var structure: DGMStructure
    var completion: (() -> Void)?

    @State private var currentPage = Page.modules
    @State private var isActionsPresented = false
    
    @Environment(\.self) private var environment
    @Environment(\.managedObjectContext) private var managedObjectContext
    @EnvironmentObject private var project: FittingProject
    @EnvironmentObject private var sharedState: SharedState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var title: String {
        let typeName = structure.type(from: self.managedObjectContext)?.typeName ?? "Unknown"
        let name = structure.name
        if name.isEmpty {
            return typeName
        }
        else {
            return "\(typeName) / \(name)"
        }
    }
        
    private var actionsButton: some View {
        BarButtonItems.actions {
            self.isActionsPresented = true
        }
        .adaptivePopover(isPresented: $isActionsPresented) {
            NavigationView {
                FittingEditorStructureActions(structure: self.structure) {
                    self.isActionsPresented = false
                }
            }
            .modifier(ServicesViewModifier(environment: self.environment, sharedState: self.sharedState))
            .environmentObject(self.project)
            .navigationViewStyle(StackNavigationViewStyle())
            .frame(idealWidth: 375, idealHeight: 375 * 2)
        }
    }

    
    var body: some View {
        let body = HStack(spacing: 1) {
            VStack(spacing: 0) {
                Picker("Page", selection: $currentPage) {
                    Text("Modules").tag(Page.modules)
                    Text("Fighters").tag(Page.drones)
                    if horizontalSizeClass != .regular {
                        Text("Stats").tag(Page.stats)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                Divider()
                if currentPage == .modules {
                    FittingEditorShipModules(ship: structure)
                }
                else if currentPage == .drones {
                    FittingEditorShipDrones(ship: structure)
                }
                else if currentPage == .stats {
                    FittingEditorStats(ship: structure)
                }
            }
            if horizontalSizeClass == .regular {
                FittingEditorStats(ship: structure)
            }
        }
        
        return Group {
            if completion != nil {
                body.navigationBarItems(leading: BarButtonItems.close(completion!), trailing: actionsButton)
            }
            else {
                body.navigationBarItems(trailing: actionsButton)
            }
        }
        .navigationBarTitle(Text(title), displayMode: .inline)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}

#if DEBUG
struct FittingEditor_Previews: PreviewProvider {
    static var previews: some View {
        let gang = DGMGang.testGang()
        return NavigationView {
            FittingEditor(project: FittingProject(gang: gang, managedObjectContext: Storage.testStorage.persistentContainer.viewContext))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(gang)
        .modifier(ServicesViewModifier.testModifier())
    }
}
#endif
