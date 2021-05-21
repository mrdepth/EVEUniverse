//
//  TypePicker.swift
//  Neocom
//
//  Created by Artem Shimanski on 2/24/20.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI
import Expressible
import CoreData

class TypePickerManager {
    private let typePickerState = Cache<SDEDgmppItemGroup, TypePicker>()
    func get(_ parentGroup: SDEDgmppItemGroup, environment: EnvironmentValues, sharedState: SharedState, completion: @escaping (SDEInvType?) -> Void) -> some View {
        let services = ServicesViewModifier(environment: environment, sharedState: sharedState)
        let picker = typePickerState[parentGroup, default: TypePicker(content: TypePickerViewController(parentGroup: parentGroup, services: services, completion: {_ in}))]
        picker.content.completion = {
            completion($0)
        }
        return picker.modifier(services)
    }
}

class TypePickerViewController: UIViewController {
    var completion: (SDEInvType?) -> Void
    private var rootViewController: UINavigationController?
    init(parentGroup: SDEDgmppItemGroup, services: ServicesViewModifier, completion: @escaping (SDEInvType?) -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        
        let view = TypePickerPage(parentGroup: parentGroup) { [weak self] type in
            self?.completion(type)
        }
        .navigationBarItems(leading: BarButtonItems.close { [weak self] in
            self?.completion(nil)
        }).modifier(services)
        rootViewController = UINavigationController(rootViewController: UIHostingController(rootView: view))
        addChild(rootViewController!)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(rootViewController!.view)
        rootViewController?.view.frame = view.bounds
    }
    override func viewDidLayoutSubviews() {
        rootViewController?.view.frame = view.bounds
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}

struct TypePicker: UIViewRepresentable {
    var content: TypePickerViewController
    
    func makeUIView(context: Context) -> UIView {
        return content.view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
//
//    func makeUIViewController(context: Context) -> TypePickerViewController {
//        return content
//    }
//
//    func updateUIViewController(_ uiViewController: TypePickerViewController, context: Context) {
//    }
}

struct TypePickerWrapper: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    
    var parentGroup: SDEDgmppItemGroup
    var completion: (SDEInvType?) -> Void
    
    var page: TypePickerPage
    init(parentGroup: SDEDgmppItemGroup, completion: @escaping (SDEInvType?) -> Void) {
        self.parentGroup = parentGroup
        self.completion = completion
        
        page = TypePickerPage(parentGroup: parentGroup) {
            completion($0)
        }
    }

    var body: some View {
        page.navigationBarItems(leading: BarButtonItems.close {
            self.completion(nil)
        })
    }
}

struct TypePickerPage: View, Equatable {
    static func == (lhs: TypePickerPage, rhs: TypePickerPage) -> Bool {
        true
    }
    
    var parentGroup: SDEDgmppItemGroup
    var completion: (SDEInvType) -> Void

    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var selectedGroup: SDEDgmppItemGroup?
    @ObservedObject var searchHelper = TypePickerSearchHelper()

    var body: some View {
        Group {
            if (parentGroup.subGroups?.count ?? 0) > 0 {
                TypePickerGroups(parentGroup: parentGroup, searchHelper: searchHelper, completion: completion)
            }
            else {
                TypePickerTypes(parentGroup: parentGroup, searchHelper: searchHelper, completion: completion)
            }
        }
    }
}

struct TypePicker_Previews: PreviewProvider {
    static var previews: some View {
        let context = Storage.testStorage.persistentContainer.viewContext
        let group = try! context.fetch(SDEDgmppItemGroup.rootGroup(categoryID: .ship)).first!
        return TypePicker(content: TypePickerViewController(parentGroup: group, services: ServicesViewModifier.testModifier(), completion: {_ in})).edgesIgnoringSafeArea(.all)
    }
}
