//
//  SessionManagementViewController.swift
//  TicketMachine
//
//  Created by Arvids Gargurnis on 14/04/2017.
//  Copyright © 2017 Arvids Gargurnis. All rights reserved.
//

import UIKit
import CloudKit

class SessionManagementViewController: UITableViewController {
    
    let publicData = CKContainer.default().publicCloudDatabase
    var sessionID = Int()
    var myRecordName = String()
    
    var participants = [CKRecord]()
    var participantsWaiting = [CKRecord]()
    var participantsNotWaiting = [CKRecord]()
    
    var refresh: UIRefreshControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        loadData()
        
        refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Pull to load qustions")
        refresh.addTarget(self, action: #selector(SessionTableViewController.loadData), for: .valueChanged)
        self.tableView.addSubview(refresh)
        
        DispatchQueue.main.async { () -> Void in
            NotificationCenter.default.addObserver(self, selector: #selector(SessionTableViewController.loadData), name: NSNotification.Name(rawValue: "performReload"), object: nil)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func loadData() {
        let query = CKQuery(recordType: "Participant", predicate: NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID]))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let participants = results {
                self.participants = participants
                self.sortParticipants()
                DispatchQueue.main.async(execute: { () -> Void in
                    self.tableView.reloadData()
                    self.refresh.endRefreshing()
                    self.view.layoutSubviews()
                })
            }
        }
    }
    
    func checkParticipant(participantRecordName: String) {
        let recordID = CKRecordID(recordName: participantRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                record?.setObject("notWaiting" as CKRecordValue, forKey: "Status")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully updated record!")
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
//    func getRecordName() {
//        let query = CKQuery(recordType: "Participant", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
//        
//        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
//            if let participants = results {
//                for participant in participants {
//                    let participantID = participant.object(forKey: "ParticipantID") as! Int
//                    let pSessionID = participant.object(forKey: "SessionID") as! Int
//                    if participantID == self.userID && pSessionID == self.sessionID {
//                        let recordID = participant.value(forKey: "recordID") as! CKRecordID
//                        self.myRecordName = recordID.recordName
//                    }
//                }
//            }
//        }
//    }
    
    func sortParticipants() {
        participantsWaiting.removeAll()
        participantsNotWaiting.removeAll()
        for participant in participants {
            let status = participant["Status"] as? String
            if status == "waiting" {
                self.participantsWaiting.append(participant)
            } else if status == "notWaiting" {
                self.participantsNotWaiting.append(participant)
            }
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return participantsWaiting.count
        } else {
            return participantsNotWaiting.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "participantCell", for: indexPath)
        
        if indexPath.section == 0 {
            let participantWaiting = participantsWaiting[indexPath.row]
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "MM/dd/yyyy HH:mm"
            let dateString = dateFormat.string(from: participantWaiting.modificationDate!)
            print("waiting")
            cell.textLabel?.text = participantWaiting["Username"] as? String
            cell.detailTextLabel?.text = dateString
            cell.backgroundColor = UIColor(red:47/255, green:147/255, blue:201/255, alpha:1)
            
            return cell
            
        } else {
            let participantNotWaiting = participantsNotWaiting[indexPath.row]
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "MM/dd/yyyy HH:mm"
            let dateString = dateFormat.string(from: participantNotWaiting.modificationDate!)
            print("notWaiting")
            cell.textLabel?.text = participantNotWaiting["Username"] as? String
            cell.detailTextLabel?.text = dateString
            cell.backgroundColor = UIColor.white
            
            return cell
        }
    }
 
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

//    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
//        if editingStyle == .delete {
//            // Delete the row from the data source
//            tableView.deleteRows(at: [indexPath], with: .fade)
//        } else if editingStyle == .insert {
//            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
//        }    
//    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let answerAction = UITableViewRowAction.init(style: .normal, title: "Checked") { (action:UITableViewRowAction, indexPath:IndexPath) in
        
            let selectedParticipant = self.participantsWaiting[indexPath.row]
            let participantRecordID = selectedParticipant["recordID"] as! CKRecordID
            let recordName = participantRecordID.recordName
            self.checkParticipant(participantRecordName: recordName)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                self.loadData()
            })
        }
        
        answerAction.backgroundColor = UIColor.red
        return [answerAction]
    }

}
