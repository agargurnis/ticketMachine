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
    
    typealias DONE = ()->Void
    
    let publicData = CKContainer.default().publicCloudDatabase

    var sessionNextID = Int()
    var sessions = [CKRecord]()
    var refresh:UIRefreshControl!
    var status = "open"
    let limit = 4
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Pull to load sessions")
        refresh.addTarget(self, action: #selector(TutorTableViewController.loadData), for: .valueChanged)
        self.tableView.addSubview(refresh)
        
        DispatchQueue.main.async { () -> Void in
            NotificationCenter.default.addObserver(self, selector: #selector(TutorTableViewController.loadData), name: NSNotification.Name(rawValue: "performReload"), object: nil)
        }
        
        loadData()
    }
    
    func loadData() {
        sessions = [CKRecord]()
        
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
    
    func getLastId( done : @escaping DONE ) {
        let query = CKQuery(recordType: "Session", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let accounts = results {
                let lastID = accounts.last?.object(forKey: "ID") as! Int
                self.sessionNextID = lastID + 1
                done()
            }
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let characterSet = NSCharacterSet.decimalDigits
        return (string.rangeOfCharacter(from: characterSet) != nil)
    }
    
    @IBAction func createSession(_ sender: Any) {
        getLastId() {
            self.newSession()
        }
    }
    
    func newSession() {
        let sessionAlert = UIAlertController(title: "New Session", message: "Enter Session Details", preferredStyle: .alert)
        sessionAlert.addTextField { (nameField: UITextField) in
            nameField.placeholder = "Session Name"
        }
        sessionAlert.addTextField { (passcodeField: UITextField) in
            passcodeField.placeholder = "4 Digit Session Passcode"
        }
        
        sessionAlert.addAction(UIAlertAction(title: "Create Session", style: .default, handler: { (action: UIAlertAction) in
            let nameField = sessionAlert.textFields?[0]
            let passcodeField = sessionAlert.textFields?[1]
            
            if nameField?.text != "" && passcodeField?.text != "" {
                let newSession = CKRecord(recordType: "Session")
                newSession["ID"] = self.sessionNextID as CKRecordValue?
                newSession["Name"] = nameField?.text as CKRecordValue?
                newSession["Passcode"] = Int((passcodeField?.text!)!) as CKRecordValue?
                newSession["Status"] = self.status as CKRecordValue?
                
                self.publicData.save(newSession, completionHandler: { (record:CKRecord?, error:Error?) in
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var indexPath: IndexPath = self.tableView.indexPathForSelectedRow!
        let destination = segue.destination as! SessionManagementViewController
        
        let selectRecord = sessions[indexPath.row]
        
        let sessionName = selectRecord.object(forKey: "Name") as? String
        let sessionID = selectRecord.object(forKey: "ID") as? Int
        let sessionRecordID = selectRecord.object(forKey: "recordID") as! CKRecordID
        let recordName = sessionRecordID.recordName
        
        destination.sessionID = sessionID!
        destination.sessionRecordName = recordName
        destination.sessionName = sessionName!
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

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
        
        if let sessionName = session["Name"] as? String {
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "MM/dd/yyyy HH:mm"
            let dateString = dateFormat.string(from: session.creationDate!)
            
            cell.textLabel?.text = sessionName
            cell.detailTextLabel?.text = dateString
        }
        
        return cell

    }

}
