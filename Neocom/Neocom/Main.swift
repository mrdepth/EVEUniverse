//
//  Main.swift
//  Neocom
//
//  Created by Artem Shimanski on 19.11.2019.
//  Copyright © 2019 Artem Shimanski. All rights reserved.
//

import SwiftUI
import EVEAPI
import Expressible

struct FinishedViewWrapper: View {
    @State private var isFinished = false
    
    var body: some View {
        Group {
            if isFinished {
                FinishedView(isPresented: $isFinished)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didFinishJob)) { _ in
            withAnimation {
                self.isFinished = true
            }
        }

    }
}

struct FittingRestore: View {
    @State var restoredFitting: FittingProject? = nil
    
    var body: some View {
        restoredFitting.map{
            NavigationLink(destination: FittingEditor(project: $0),
            tag: $0,
            selection: $restoredFitting, label: {EmptyView()})}
    }
}

struct Main: View {
    @State var restoredFitting: FittingProject?
    @EnvironmentObject private var sharedState: SharedState
    @Environment(\.self) private var environment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private let home = Home()

    var body: some View {
        let navigationView = NavigationView {
            if horizontalSizeClass == .regular {
                #if targetEnvironment(macCatalyst) || targetEnvironment(simulator)
                home
                #else
                AdsContainerView {
                    home
                }
                #endif
                restoredFitting.map{FittingEditor(project: $0)}
            }
            else {
                home.overlay(restoredFitting.map {
                    NavigationLink(destination: FittingEditor(project: $0), tag: $0, selection: $restoredFitting) {EmptyView()}
                })
            }
        }
        
        return ZStack {
            if horizontalSizeClass == .regular {
                navigationView.navigationViewStyle(DoubleColumnNavigationViewStyle())
            }
            else {
                #if targetEnvironment(macCatalyst) || targetEnvironment(simulator)
                navigationView.navigationViewStyle(StackNavigationViewStyle())
                #else
                AdsContainerView {
                    navigationView.navigationViewStyle(StackNavigationViewStyle())
                }
                #endif
            }
            FinishedViewWrapper()
        }
    }
}

#if DEBUG
struct Main_Previews: PreviewProvider {
    static var previews: some View {
        return Main()
            .modifier(ServicesViewModifier.testModifier())

    }
}
#endif

