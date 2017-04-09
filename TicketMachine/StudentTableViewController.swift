//
//  StudentTableViewController.swift
//  TicketMachine
//
//  Created by Arvids Gargurnis on 06/04/2017.
//  Copyright © 2017 Arvids Gargurnis. All rights reserved.
//

import UIKit
import CloudKit
import UserNotifications

class StudentTableViewController: UITableViewController, UNUserNotificationCenterDelegate {

    var sessions = [CKRecord]()
    var refresh:UIRefreshControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Pull to load qustions")
        refresh.addTarget(self, action: #selector(StudentTableViewController.loadData), for: .valueChanged)
        self.tableView.addSubview(refresh)
        
        DispatchQueue.main.async { () -> Void in
            NotificationCenter.default.addObserver(self, selector: #selector(StudentTableViewController.loadData), name: NSNotification.Name(rawValue: "performReload"), object: nil)
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
    
//    @IBAction func sendRequest(_ sender: Any) {
//        
//        let alert = UIAlertController(title: "New Question", message: "Enter your question", preferredStyle: .alert)
//        alert.addTextField { (textField: UITextField) in
//            textField.placeholder = "Your question"
//        }
//        
//        alert.addAction(UIAlertAction(title: "Send", style: .default, handler: { (action: UIAlertAction) in
//            let textField = alert.textFields?.first!
//            
//            if textField?.text != "" {
//                let newQuestion = CKRecord(recordType: "Question")
//                newQuestion["content"] = textField?.text as CKRecordValue?
//                
//                let publicData = CKContainer.default().publicCloudDatabase
//                
//                publicData.save(newQuestion, completionHandler: { (record: CKRecord?, error: Error?) in
//                    if error == nil {
//                        DispatchQueue.main.async(execute: { () -> Void in
//                            self.tableView.beginUpdates()
//                            self.sessions.insert(newsession, at: 0)
//                            let indexPath = NSIndexPath(row: 0, section: 0)
//                            self.tableView.insertRows(at: [indexPath as IndexPath], with: UITableViewRowAnimation.top)
//                            self.tableView.endUpdates()
//                        })
//                    } else if let e = error {
//                        print(e.localizedDescription)
//                    }
//                })
//            }
//        }))
//        
//        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
//        self.present(alert, animated: true, completion: nil)
//        
//    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "sessionCell", for: indexPath)
        
        if sessions.count == 0 {
            return cell
        }
        
        let session = sessions[indexPath.row]
        
        if let sessionContent = session["content"] as? String {
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "yyyy/MM/dd HH:mm"
            let dateString = dateFormat.string(from: session.creationDate!)
            
            cell.textLabel?.text = sessionContent
            cell.detailTextLabel?.text = dateString
        }
        
        return cell
    }

}
