//
//  TutorTableViewController.swift
//  TicketMachine
//
//  Created by Arvids Gargurnis on 06/04/2017.
//  Copyright © 2017 Arvids Gargurnis. All rights reserved.
//

import UIKit
import CloudKit
import UserNotifications

class TutorTableViewController: UITableViewController, UNUserNotificationCenterDelegate {

    var sessions = [CKRecord]()
    var refresh:UIRefreshControl!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Pull to load sessions")
        refresh.addTarget(self, action: #selector(TutorTableViewController.loadData), for: .valueChanged)
        self.tableView.addSubview(refresh)
        
        DispatchQueue.main.async { () -> Void in
            NotificationCenter.default.addObserver(self, selector: #selector(TutorTableViewController.loadData), name: NSNotification.Name(rawValue: "performReload"), object: nil)
        }
        
        setupCloudKitSubscription()
        loadData()

    }
    
    func setupCloudKitSubscription() {
        let userDefaults = UserDefaults.standard
        
        if userDefaults.bool(forKey: "subscribed") == false {
            let predicate = NSPredicate(format: "TRUEPREDICATE", argumentArray: nil)
            let subscription = CKQuerySubscription(recordType: "Session", predicate: predicate, options: CKQuerySubscriptionOptions.firesOnRecordCreation)
            let notificationInfo = CKNotificationInfo()
            notificationInfo.alertLocalizationKey = "New Session"
            notificationInfo.shouldBadge = true
            
            subscription.notificationInfo = notificationInfo
            
            let publicData = CKContainer.default().publicCloudDatabase
            
            publicData.save(subscription) { (subscription:CKSubscription?, error:Error?) in
                if let e = error {
                    print(e.localizedDescription)
                } else {
                    userDefaults.set(true, forKey: "subscribed")
                    userDefaults.synchronize()
                }
            }
        }
        
    }
    
    func loadData() {
        sessions = [CKRecord]()
        
        let publicData = CKContainer.default().publicCloudDatabase
        let query = CKQuery(recordType: "Session", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let sessions = results {
                self.sessions = sessions
                DispatchQueue.main.async(execute: { () -> Void in
                    self.tableView.reloadData()
                    self.refresh.endRefreshing()
                    self.view.layoutSubviews()
                })
            }
        }
    }
    
    @IBAction func createSession(_ sender: Any) {
        let sessionAlert = UIAlertController(title: "New Session", message: "Enter Session Details", preferredStyle: .alert)
        sessionAlert.addTextField { (idField: UITextField) in
            idField.placeholder = "Session ID"
        }
        sessionAlert.addTextField { (nameField: UITextField) in
            nameField.placeholder = "Session Name"
        }
        sessionAlert.addTextField { (passcodeField: UITextField) in
            passcodeField.placeholder = "Session Passcode"
        }
        
        sessionAlert.addAction(UIAlertAction(title: "Create Session", style: .default, handler: { (action: UIAlertAction) in
            let idField = sessionAlert.textFields?[0]
            let nameField = sessionAlert.textFields?[1]
            let passcodeField = sessionAlert.textFields?[2]
            
            if idField?.text != "" && nameField?.text != "" && passcodeField?.text != "" {
                let newSession = CKRecord(recordType: "Session")
                newSession["ID"] = Int((idField?.text!)!) as CKRecordValue?
                newSession["Name"] = nameField?.text as CKRecordValue?
                newSession["Passcode"] = Int((passcodeField?.text!)!) as CKRecordValue?
                
                let publicData = CKContainer.default().publicCloudDatabase
                
                publicData.save(newSession, completionHandler: { (record:CKRecord?, error:Error?) in
                    if error == nil {
                        DispatchQueue.main.async(execute: { () -> Void in
                            self.tableView.beginUpdates()
                            self.sessions.insert(newSession, at: 0)
                            let indexPath = NSIndexPath(row: 0, section: 0)
                            self.tableView.insertRows(at: [indexPath as IndexPath], with: UITableViewRowAnimation.top)
                            self.tableView.endUpdates()
                        })
                    } else if let e = error {
                        print(e.localizedDescription)
                    }
                })
            }
        }))
        
        sessionAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(sessionAlert, animated: true, completion: nil)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return sessions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "sessionCell", for: indexPath)
        
        if sessions.count == 0 {
            return cell
        }
        
        let session = sessions[indexPath.row]
        
        if let sessionName = session["Name"] as? String {
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "MM/dd/yyyy HH:mm"
            let dateString = dateFormat.string(from: session.creationDate!)
            
            cell.textLabel?.text = sessionName
            cell.detailTextLabel?.text = dateString
        }
        
        return cell

    }
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        var indexPath: IndexPath = self.tableView.indexPathForSelectedRow!
//        let desti = segue.destination as! SessionTableViewController
//        
//        let selectRecord = sessions[indexPath.row]
//        
//        let name = selectRecord.object(forKey: <#T##String#>)
//        
//        
//    }

}
