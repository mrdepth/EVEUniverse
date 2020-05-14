//
//  CertCertificateMasteryInfo.swift
//  Neocom
//
//  Created by Artem Shimanski on 9/28/18.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import Foundation
import Futures

enum CertCertificateMasteryInfo: Assembly {
	typealias View = CertCertificateMasteryInfoViewController
	case `default`
	
	func instantiate(_ input: View.Input) -> Future<View> {
		switch self {
		case .default:
			let controller = UIStoryboard.database.instantiateViewController(withIdentifier: "CertCertificateMasteryInfoViewController") as! View
			controller.input = input
			return .init(controller)
		}
	}
}
