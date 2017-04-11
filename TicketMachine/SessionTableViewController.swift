//
//  SessionTableViewController.swift
//  TicketMachine
//
//  Created by Arvids Gargurnis on 07/04/2017.
//  Copyright © 2017 Arvids Gargurnis. All rights reserved.
//

import UIKit
import CloudKit

class SessionTableViewController: UITableViewController {
    
    let publicData = CKContainer.default().publicCloudDatabase
    var userName = String()
    var sessionID = Int()
    var userRole = "Student"
    var questionStatus = "Unasked"
    var userID = String()
    
    var participants = [CKRecord]()
    var refresh: UIRefreshControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        addParticipant()
        
        refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Pull to load qustions")
        refresh.addTarget(self, action: #selector(SessionTableViewController.loadData), for: .valueChanged)
        self.tableView.addSubview(refresh)
        
        DispatchQueue.main.async { () -> Void in
            NotificationCenter.default.addObserver(self, selector: #selector(SessionTableViewController.loadData), name: NSNotification.Name(rawValue: "performReload"), object: nil)
        }
        
        loadData()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadData() {
        
        let query = CKQuery(recordType: "Participant", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let participants = results {
                for participant in participants {
                    let joiningID = participant.object(forKey: "SessionID") as! Int
                    if joiningID == self.sessionID {
                        self.participants.append(participant)
                        DispatchQueue.main.async(execute: { () -> Void in
                            self.tableView.reloadData()
                            self.refresh.endRefreshing()
                            self.view.layoutSubviews()
                        })
                    }
                }
            }
        }
    }

    func addParticipant() {
        let newParticipant = CKRecord(recordType: "Participant")
        newParticipant["Username"] = userName as CKRecordValue?
        newParticipant["UserRole"] = userRole as CKRecordValue?
        newParticipant["QuestionStatus"] = questionStatus as CKRecordValue?
        newParticipant["SessionID"] = sessionID as CKRecordValue?
        
        publicData.save(newParticipant, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.tableView.beginUpdates()
                    self.participants.insert(newParticipant, at: 0)
                    let indexPath = NSIndexPath(row: 0, section: 0)
                    self.tableView.insertRows(at: [indexPath as IndexPath], with: UITableViewRowAnimation.top)
                    self.tableView.endUpdates()
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })

    }

//    @IBAction func requestTicket(_ sender: Any) {
//        let predicate = yourPredicate // better be accurate to get only the record you need
//        var query = CKQuery(recordType: YourRecordType, predicate: predicate)
//        database.performQuery(query, inZoneWithID: nil, completionHandler: { (records, error) in
//            if error != nil {
//                println("Error querying records: \(error.localizedDescription)")
//            } else {
//                if records.count > 0 {
//                    let record = records.first as! CKRecord
//                    // Now you have grabbed your existing record from iCloud
//                    // Apply whatever changes you want
//                    record.setObject(aValue, forKey: attributeToChange)
//                    
//                    // Save this record again
//                    database.saveRecord(record, completionHandler: { (savedRecord, saveError in
//                        if saveError != nil {
//                        println("Error saving record: \(saveError.localizedDescription)")
//                        } else {
//                        println("Successfully updated record!")
//                        }
//                    })
//                }
//            }
//        })
//    }
    
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return participants.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "participantCell", for: indexPath)
        
        if participants.count == 0 {
            return cell
        }
        
        let participant = participants[indexPath.row]
        
        if let sessionName = participant["Username"] as? String {
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "MM/dd/yyyy HH:mm"
            let dateString = dateFormat.string(from: participant.creationDate!)
            
            cell.textLabel?.text = sessionName
            cell.detailTextLabel?.text = dateString
        }
        
        return cell
        
    }


}
