//
//  CertCertificates.swift
//  Neocom
//
//  Created by Artem Shimanski on 9/28/18.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import Foundation
import Futures

enum CertCertificates: Assembly {
	typealias View = CertCertificatesViewController
	case `default`
	
	func instantiate(_ input: View.Input) -> Future<View> {
		switch self {
		case .default:
			let controller = UIStoryboard.database.instantiateViewController(withIdentifier: "CertCertificatesViewController") as! View
			controller.input = input
			return .init(controller)
		}
	}
}
