//
//  FoundersViewController.swift
//  Founders Directory
//
//  Created by Steve Liddle on 9/21/16.
//  Copyright © 2016 Steve Liddle. All rights reserved.
//

import UIKit
import GRDB

class FoundersViewController : UITableViewController {
    
    // MARK: - Constants
    
    private struct Storyboard {
        static let CellIdentifier = "FounderCell"
        static let CornerRadius: CGFloat = 30
        static let ViewSegueIdentifier = "ViewProfile"
    }

    private struct Request {
        static let foundersByName = Founder.order(Column(Founder.Field.preferredFullName))
    }

    // MARK: - Properties

    var foundersController: FetchedRecordsController<Founder>!

    // MARK: - View controller lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        //TODO: Check to see if there is a session key
//        UserDefaults.standard.set("",
//                                  forKey: SyncHelper.Constants.sessionTokenKey)
        if let _ = UserDefaults.standard.string(forKey: SyncHelper.Constants.sessionTokenKey) {
            _ = SyncHelper.shared.synchronizeFounders()
        } else {
            performSegue(withIdentifier: "toLogin", sender: nil)
        }

        foundersController = FetchedRecordsController(FounderDatabase.shared.dbQueue,
                                                      request: Request.foundersByName,
                                                      compareRecordsByPrimaryKey: true)
        foundersController.trackChanges(
            recordsWillChange: { [unowned self] _ in
                self.tableView.beginUpdates()
            },
            tableViewEvent: { [unowned self] (controller, record, event) in
                switch event {
                case .insertion(let indexPath):
                    self.tableView.insertRows(at: [indexPath], with: .fade)
                    
                case .deletion(let indexPath):
                    self.tableView.deleteRows(at: [indexPath], with: .fade)
                    
                case .update(let indexPath, _):
                    if let cell = self.tableView.cellForRow(at: indexPath) {
                        self.configure(cell, at: indexPath)
                    }

                case .move(let indexPath, let newIndexPath, _):
                    let cell = self.tableView.cellForRow(at: indexPath)
                    self.tableView.moveRow(at: indexPath, to: newIndexPath)

                    if let cell = cell {
                        self.configure(cell, at: newIndexPath)
                    }
                }
            },
            recordsDidChange: { [unowned self] _ in
                self.tableView.endUpdates()
        })

        foundersController.performFetch()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.resetBarTransparency()
    }

    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destVC = segue.destination as? ProfileViewController {
            destVC.founder = foundersController.record(at: tableView.indexPathForSelectedRow!)
        }
    }

    // MARK: - Table view data source
    
    func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let founder = foundersController.record(at: indexPath)

        if let founderCell = cell as? FounderCell {
            founderCell.founderNameLabel?.text = founder.preferredFullName
            founderCell.founderCompanyLabel?.text = founder.organizationName
            
            if let imageView = founderCell.founderImageView {
                // Note that when we use one of the default tableview cell types, we get the
                // imageview property for free.  Here we load it from one of the pre-loaded
                // image assets and then make it circular by setting the corner radius.
                imageView.image = UIImage(named: "defaultPhoto-60")

                DispatchQueue.global().async {
                    if let photoImage = PhotoManager.shared.getPhotoFor(founderId: founder.id) {
                        DispatchQueue.main.async {
                            imageView.image = photoImage
                            //TODO: THIS ISN'T WORKING
                            //self.tableView.reloadRows(at: [indexPath], with: .automatic)
                        }
                    }
                }

                imageView.layer.cornerRadius = Storyboard.CornerRadius
                imageView.layer.masksToBounds = true
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Storyboard.CellIdentifier, for: indexPath)

        configure(cell, at: indexPath)

        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return foundersController.sections[section].numberOfRecords
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return foundersController.sections.count
    }

    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: Storyboard.ViewSegueIdentifier, sender: indexPath)
    }
}
