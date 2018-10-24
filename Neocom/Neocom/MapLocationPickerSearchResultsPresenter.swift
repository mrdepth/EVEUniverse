//
//  MapLocationPickerSearchResultsPresenter.swift
//  Neocom
//
//  Created by Artem Shimanski on 9/27/18.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import Foundation
import TreeController
import CloudData
import Futures
import Expressible
import CoreData

class MapLocationPickerSearchResultsPresenter: TreePresenter {
	typealias View = MapLocationPickerSearchResultsViewController
	typealias Interactor = MapLocationPickerSearchResultsInteractor
	typealias Presentation = [AnyTreeItem]
	
	weak var view: View?
	lazy var interactor: Interactor! = Interactor(presenter: self)
	
	var content: Interactor.Content?
	var presentation: Presentation?
	var loading: Future<Presentation>?
	
	required init(view: View) {
		self.view = view
	}
	
	func configure() {
		view?.tableView.register([Prototype.TreeHeaderCell.default,
								  Prototype.TreeDefaultCell.default])
		
		interactor.configure()
		applicationWillEnterForegroundObserver = NotificationCenter.default.addNotificationObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] (note) in
			self?.applicationWillEnterForeground()
		}
	}
	
	private var applicationWillEnterForegroundObserver: NotificationObserver?
	
	func presentation(for content: Interactor.Content) -> Future<Presentation> {
		guard let input = view?.input else { return .init(.failure(NCError.invalidInput(type: type(of: self))))}
		
		guard let searchString = searchString, !searchString.isEmpty else {
			self.searchString = nil
			return .init([])
		}
		self.searchString = nil
		
		return Services.sde.performBackgroundTask { [weak self] context -> Presentation in
			var sections = Presentation()
			
			if let region = input.region {
				let controller = context.managedObjectContext
					.from(SDEMapSolarSystem.self)
					.filter(\SDEMapSolarSystem.constellation?.region == region && (\SDEMapSolarSystem.solarSystemName).caseInsensitive.contains(searchString))
					.sort(by: \SDEMapSolarSystem.solarSystemName, ascending: true)
					.objectIDs
					.fetchedResultsController()
				try controller.performFetch()
				
				if controller.fetchedObjects?.isEmpty == false {
					let section: Tree.Item.NamedFetchedResultsController<Tree.Item.FetchedResultsSection<Tree.Item.MapSolarSystemSearchResultsRow>> =
						Tree.Item.NamedFetchedResultsController(Tree.Content.Section(title: NSLocalizedString("Solar Systems", comment: "")),
																fetchedResultsController: controller,
																treeController: self?.view?.treeController)
					sections.append(section.asAnyItem)
				}
			}
			else {
				if input.mode.contains(.regions) {
					let controller = context.managedObjectContext
						.from(SDEMapRegion.self)
						.filter((\SDEMapRegion.regionName).caseInsensitive.contains(searchString))
						.sort(by: \SDEMapRegion.regionName, ascending: true)
						.objectIDs
						.fetchedResultsController()
					
					try controller.performFetch()
					
					if controller.fetchedObjects?.isEmpty == false {
						let section = Tree.Item.FetchedResultsController<Tree.Item.FetchedResultsSection<Tree.Item.MapRegionSearchResultsRow>>(controller, treeController: self?.view?.treeController)
						sections.append(section.asAnyItem)
					}
					
					if !input.mode.contains(.solarSystems) {
						let controller = context.managedObjectContext
							.from(SDEMapSolarSystem.self)
							.filter(\SDEMapSolarSystem.constellation?.region?.regionID < SDERegionID.whSpace.rawValue &&
								(\SDEMapSolarSystem.solarSystemName).caseInsensitive.contains(searchString))
							.sort(by: \SDEMapSolarSystem.constellation?.region?.regionName, ascending: true)
							.objectIDs
							.fetchedResultsController()
						
						try controller.performFetch()
						
						if controller.fetchedObjects?.isEmpty == false {
							let section = Tree.Item.FetchedResultsController<Tree.Item.FetchedResultsSection<Tree.Item.MapRegionBySolarSystemSearchResultsRow>>(controller, treeController: self?.view?.treeController)
							sections.append(section.asAnyItem)
						}
					}
				}
				
				if input.mode.contains(.solarSystems) {
					let controller = context.managedObjectContext
						.from(SDEMapSolarSystem.self)
						.filter((\SDEMapSolarSystem.solarSystemName).caseInsensitive.contains(searchString))
						.sort(by: \SDEMapSolarSystem.solarSystemName, ascending: true)
						.objectIDs
						.fetchedResultsController()
					try controller.performFetch()
					
					if controller.fetchedObjects?.isEmpty == false {
						let section: Tree.Item.NamedFetchedResultsController<Tree.Item.FetchedResultsSection<Tree.Item.MapSolarSystemSearchResultsRow>> =
							Tree.Item.NamedFetchedResultsController(Tree.Content.Section(title: NSLocalizedString("Solar Systems", comment: "")),
																	fetchedResultsController: controller,
																	treeController: self?.view?.treeController)
						sections.append(section.asAnyItem)
					}
				}
				
			}
			
			return sections
		}
	}
	
	private var searchString: String?
	
	func updateSearchResults(with string: String) {
		if searchString == nil {
			searchString = string
			if let loading = loading {
				loading.then(on: .main) { [weak self] _ in
					DispatchQueue.main.async {
						self?.reload(cachePolicy: .useProtocolCachePolicy).then(on: .main) {
							self?.view?.present($0, animated: false)
						}
					}
				}
			}
			else {
				reload(cachePolicy: .useProtocolCachePolicy).then(on: .main) { [weak self] in
					self?.view?.present($0, animated: false)
				}
			}
		}
		else {
			searchString = string
		}
	}
	
	func didSelect(_ region: SDEMapRegion) {
		guard let controller = view?.presentingViewController?.navigationController as? MapLocationPickerViewController else {return}
		controller.input?.completion(controller, .region(region))
	}

	func didSelect(_ solarSystem: SDEMapSolarSystem) {
		guard let controller = view?.presentingViewController?.navigationController as? MapLocationPickerViewController else {return}
		controller.input?.completion(controller, .solarSystem(solarSystem))
	}

}

extension Tree.Item {
	class MapSolarSystemSearchResultsRow: FetchedResultsRow<NSManagedObjectID> {
		lazy var solarSytem: SDEMapSolarSystem = try! Services.sde.viewContext.existingObject(with: self.result)!
		
		override var prototype: Prototype? {
			return solarSytem.prototype
		}
		
		override func configure(cell: UITableViewCell) {
			solarSytem.configure(cell: cell)
		}
	}

	class MapRegionSearchResultsRow: FetchedResultsRow<NSManagedObjectID> {
		lazy var region: SDEMapRegion = try! Services.sde.viewContext.existingObject(with: self.result)!
		
		override var prototype: Prototype? {
			return region.prototype
		}
		
		override func configure(cell: UITableViewCell) {
			region.configure(cell: cell)
		}
	}
	
	class MapRegionBySolarSystemSearchResultsRow: FetchedResultsRow<NSManagedObjectID> {
		lazy var solarSytem: SDEMapSolarSystem = try! Services.sde.viewContext.existingObject(with: self.result)!
		
		override var prototype: Prototype? {
			return Prototype.TreeDefaultCell.default
		}
		
		override func configure(cell: UITableViewCell) {
			guard let cell = cell as? TreeDefaultCell else {return}
			cell.titleLabel?.text = solarSytem.constellation?.region?.regionName
			cell.subtitleLabel?.text = solarSytem.solarSystemName
			cell.subtitleLabel?.isHidden = false
			cell.iconView?.isHidden = true
		}
	}

}