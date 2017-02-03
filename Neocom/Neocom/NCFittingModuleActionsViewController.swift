//
//  NCFittingModuleActionsViewController.swift
//  Neocom
//
//  Created by Artem Shimanski on 31.01.17.
//  Copyright © 2017 Artem Shimanski. All rights reserved.
//

import UIKit

class NCFittingModuleStateRow: TreeRow {
	let module: NCFittingModule
	let states: [NCFittingModuleState]
	
	init(module: NCFittingModule) {
		self.module = module
		
		let states: [NCFittingModuleState] = [.offline, .online, .active, .overloaded]
		self.states = states.filter {module.canHaveState($0)}
		
		super.init(cellIdentifier: "NCFittingModuleStateTableViewCell")
		
	}
	
	override func configure(cell: UITableViewCell) {
		guard let cell = cell as? NCFittingModuleStateTableViewCell else {return}
		cell.segmentedControl?.removeAllSegments()
		cell.object = self
		var i = 0
		for state in states {
			cell.segmentedControl?.insertSegment(withTitle: state.title, at: i, animated: false)
			i += 1
		}
		
		module.engine?.perform {
			let state = self.module.state
			DispatchQueue.main.async {
				if let i = self.states.index(of: state) {
					cell.segmentedControl?.selectedSegmentIndex = i
				}
			}
		}
	}
	

	override func changed(from: TreeNode) -> Bool {
		return false
	}

	override var hashValue: Int {
		return module.hashValue
	}
	
	override func isEqual(_ object: Any?) -> Bool {
		return (object as? NCFittingModuleStateRow)?.hashValue == hashValue
	}
	
}

class NCFittingModuleInfoRow: TreeRow {
	let module: NCFittingModule
	let cpu: Double
	let powerGrid: Double
	let capacitor: Double
	
	lazy var type: NCDBInvType? = {
		return NCDatabase.sharedDatabase?.invTypes[self.module.typeID]
	}()
	
	init(module: NCFittingModule) {
		self.module = module
		let cpu = module.cpuUse
		let powerGrid = module.powerGridUse
		let capacitor = module.capUse
		self.cpu = cpu
		self.powerGrid = powerGrid
		self.capacitor = capacitor
		if cpu != 0 || powerGrid != 0 || capacitor != 0 {
			super.init(cellIdentifier: "NCFittingModuleInfoTableViewCell", segue: "NCDatabaseTypeInfoViewController")
		}
		else {
			super.init(cellIdentifier: "Cell", segue: "NCDatabaseTypeInfoViewController")
		}
	}
	
	override func configure(cell: UITableViewCell) {
		if let cell = cell as? NCFittingModuleInfoTableViewCell {
			cell.titleLabel?.text = type?.typeName
			cell.iconView?.image = type?.icon?.image?.image ?? NCDBEveIcon.defaultType.image?.image
			cell.object = type
			cell.powerGridLabel?.text = NCUnitFormatter.localizedString(from: powerGrid, unit: .megaWatts, style: .short)
			cell.cpuLabel?.text = NCUnitFormatter.localizedString(from: cpu, unit: .teraflops, style: .short)
			cell.capUseLabel?.text = (capacitor < 0 ? "+" : "") + NCUnitFormatter.localizedString(from: -capacitor, unit: .gigaJoule, style: .short)
		}
		else if let cell = cell as? NCDefaultTableViewCell {
			cell.titleLabel?.text = type?.typeName
			cell.iconView?.image = type?.icon?.image?.image ?? NCDBEveIcon.defaultType.image?.image
			cell.object = type
		}
	}

}

class NCFittingChargeRow: NCChargeRow {
	let charges: Int
	init(type: NCDBInvType, charges: Int) {
		self.charges = charges
		super.init(type: type, segue: "NCFittingAmmoViewController", accessoryButtonSegue: "NCDatabaseTypeInfoViewController")
	}
	
	override func configure(cell: UITableViewCell) {
		super.configure(cell: cell)
		if charges > 0 {
			let title = (type.typeName ?? "") + " x\(charges)" * [NSForegroundColorAttributeName: UIColor.caption]
			if let cell = cell as? NCChargeTableViewCell {
				cell.titleLabel?.attributedText = title
			}
			else if let cell = cell as? NCDefaultTableViewCell{
				cell.titleLabel?.attributedText = title
				cell.accessoryType = .detailButton
			}

		}
	}
}

class NCFittingModuleActionsViewController: UITableViewController, TreeControllerDelegate {
	var module: NCFittingModule?
	lazy var type: NCDBInvType? = {
		guard let module = self.module else {return nil}
		return NCDatabase.sharedDatabase?.invTypes[module.typeID]
	}()

	lazy var hullType: NCDBDgmppHullType? = {
		guard let ship = self.module?.owner as? NCFittingShip else {return nil}
		return NCDatabase.sharedDatabase?.invTypes[ship.typeID]?.hullType
	}()

	lazy var chargeCategory: NCDBDgmppItemCategory? = {
		return self.type?.dgmppItem?.charge
	}()
	
	var chargeSection: DefaultTreeSection?

	
	@IBOutlet var treeController: TreeController!
	
	private var observer: NSObjectProtocol?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		//navigationController?.preferredContentSize = CGSize(width: view.bounds.size.width, height: 320)

		tableView.estimatedRowHeight = tableView.rowHeight
		tableView.rowHeight = UITableViewAutomaticDimension
		treeController.delegate = self

		reload()
		tableView.layoutIfNeeded()
		var size = tableView.contentSize
		size.height += tableView.contentInset.top
		size.height += tableView.contentInset.bottom
		navigationController?.preferredContentSize = size

		if let module = module, observer == nil {
			observer = NotificationCenter.default.addObserver(forName: .NCFittingEngineDidUpdate, object: module.engine, queue: nil) { [weak self] (note) in
				self?.reload()
			}
		}

	}

	@IBAction func onDelete(_ sender: UIButton) {
		guard let module = self.module else {return}
		module.engine?.perform {
			guard let ship = module.owner as? NCFittingShip else {return}
			ship.removeModule(module)
		}
		self.dismiss(animated: true, completion: nil)
	}

	@IBAction func onChangeHullType(_ sender: UIStepper) {
		guard let cell = sender.ancestor(of: NCFittingModuleDamageChartTableViewCell.self) else {return}
		guard let node = cell.object as? NCFittingModuleDamageChartRow else {return}
		guard let hullType = node.hullTypes?[Int(sender.value)] else {return}
		self.hullType = hullType
		node.hullType = hullType
		node.configure(cell: cell)
		//treeController.reloadCells(for: [node])
	}
	
	@IBAction func onChangeState(_ sender: UISegmentedControl) {
		guard let cell = sender.ancestor(of: NCFittingModuleStateTableViewCell.self) else {return}
		guard let node = cell.object as? NCFittingModuleStateRow else {return}
		let state = node.states[sender.selectedSegmentIndex]
		module?.engine?.perform {
			self.module?.preferredState = state
		}
	}
	
	//MARK: - TreeControllerDelegate
	
	func treeController(_ treeController: TreeController, didSelectCellWithNode node: TreeNode) {
		guard let node = node as? TreeRow else {return}
		guard let segue = node.segue else {return}
		performSegue(withIdentifier: segue, sender: treeController.cell(for: node))
	}
	
	func treeController(_ treeController: TreeController, accessoryButtonTappedWithNode node: TreeNode) {
		guard let node = node as? TreeRow else {return}
		guard let segue = node.accessoryButtonSegue else {return}
		performSegue(withIdentifier: segue, sender: treeController.cell(for: node))
	}
	
	func treeController(_ treeController: TreeController, editActionsForNode node: TreeNode) -> [UITableViewRowAction]? {
		if node is NCFittingChargeRow {
			return [UITableViewRowAction(style: .destructive, title: NSLocalizedString("Unload", comment: "Unload ammo"), handler: { _ in
				self.module?.engine?.perform {
					self.module?.charge = nil
				}
				let row = DefaultTreeRow(cellIdentifier: "Cell", title: NSLocalizedString("Select Ammo", comment: ""),  segue: "NCFittingAmmoViewController")
				self.chargeSection?.children = [row]

			})]
		}
		return nil
	}
	
	//MARK: - Navigation
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
		case "NCDatabaseTypeInfoViewController"?:
			guard let controller = segue.destination as? NCDatabaseTypeInfoViewController,
				let cell = sender as? NCTableViewCell,
				let type = cell.object as? NCDBInvType else {
					return
			}
			controller.type = type
		case "NCFittingAmmoViewController"?:
			guard let controller = segue.destination as? NCFittingAmmoViewController else {return}
			controller.category = self.chargeCategory
			controller.completionHandler = { [weak self, weak controller] type in
				let typeID = Int(type.typeID)
				controller?.dismiss(animated: true) {
					self?.module?.engine?.perform {
						self?.module?.charge = NCFittingCharge(typeID: typeID)
					}
				}
			}
		default:
			break
		}
	}
	
	//MARK: Private
	
	private func reload() {
		guard let module = self.module else {return}
		
		var sections = [TreeNode]()
		
		var charge: NCFittingCharge?
		var chargeGroups: IndexSet?
		var charges: Int?
		var dpsSection: TreeSection?
		let hullType = self.hullType
		module.engine?.performBlockAndWait {
			
			sections.append(NCFittingModuleInfoRow(module: module))
			
			if module.canHaveState(.online) {
				let section = DefaultTreeSection(cellIdentifier: "NCHeaderTableViewCell", nodeIdentifier: "State", title: NSLocalizedString("State", comment: "").uppercased(), children: [NCFittingModuleStateRow(module: module)])
				sections.append(section)
			}
			chargeGroups = module.chargeGroups
			charges = module.charges
			charge = module.charge
			
			if module.dps.total > 0 {
				let row = NCFittingModuleDamageChartRow(module: module)
				row.hullType = hullType
				dpsSection = DefaultTreeSection(cellIdentifier: "NCHeaderTableViewCell", nodeIdentifier: "DPS", title: NSLocalizedString("DPS", comment: "").uppercased(), children: [row])
			}
		}
		if let chargeGroups = chargeGroups, chargeGroups.count > 0 {
			let row: TreeNode
			if let charge = charge, let type = NCDatabase.sharedDatabase?.invTypes[charge.typeID] {
				row = NCFittingChargeRow(type: type, charges: charges ?? 0)
			}
			else {
				row = DefaultTreeRow(cellIdentifier: "Cell", title: NSLocalizedString("Select Ammo", comment: ""),  segue: "NCFittingAmmoViewController")
			}
			let section = DefaultTreeSection(cellIdentifier: "NCHeaderTableViewCell", nodeIdentifier: "Charge", title: NSLocalizedString("Charge", comment: "").uppercased(), children: [row])
			sections.append(section)
			chargeSection = section
		}
		if let dpsSection = dpsSection {
			sections.append(dpsSection)
		}
		
		if treeController.rootNode == nil {
			let root = TreeNode()
			root.children = sections
			treeController.rootNode = root
		}
		else {
			treeController.rootNode?.children = sections
		}
	}
}
