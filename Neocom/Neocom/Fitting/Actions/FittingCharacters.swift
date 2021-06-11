//
//  FittingCharacters.swift
//  Neocom
//
//  Created by Artem Shimanski on 15.03.2020.
//  Copyright © 2020 Artem Shimanski. All rights reserved.
//

import SwiftUI

struct FittingCharacters: View {
    var onSelect: (URL, DGMSkillLevels) -> Void
    
    var body: some View {
		List {
			FittingCharactersAccounts(onSelect: onSelect)
			FittingCharactersPredefined(onSelect: onSelect)
		}.listStyle(GroupedListStyle())
		.navigationBarTitle(Text("Characters"))
    }
}

#if DEBUG
struct FittingCharacters_Previews: PreviewProvider {
    static var previews: some View {
		return NavigationView {
            FittingCharacters { _, _ in
                
            }
		}.modifier(ServicesViewModifier.testModifier())
    }
}
#endif
