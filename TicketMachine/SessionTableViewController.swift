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
    var username = String()
    var sessionID = Int()
    var userID = Int()
    var myRecordName = String()
    var sessionName = String()
    
    @IBOutlet weak var helpBtn: UIBarButtonItem!
    var status = "notWaiting"
    
    var participants = [CKRecord]()
    var participantsWaiting = [CKRecord]()
    var participantsNotWaiting = [CKRecord]()
    
    var refresh: UIRefreshControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = sessionName
        
        loadData()
        
        refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Pull to load qustions")
        refresh.addTarget(self, action: #selector(SessionTableViewController.loadData), for: .valueChanged)
        self.tableView.addSubview(refresh)
        
        DispatchQueue.main.async { () -> Void in
            NotificationCenter.default.addObserver(self, selector: #selector(SessionTableViewController.loadData), name: NSNotification.Name(rawValue: "performReload"), object: nil)
        }
        
        checkUser()
        setupCloudKitSubscription()
    }
    @IBAction func goBack(_ sender: Any) {
        self.navigationController?.popToViewController((navigationController?.viewControllers[1])!, animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func setupCloudKitSubscription() {
        let userDefaults = UserDefaults.standard
        
        if userDefaults.bool(forKey: "sessionSub") == false {
            let predicate = NSPredicate(format: "TRUEPREDICATE", argumentArray: nil)
            let subscription = CKQuerySubscription(recordType: "Participant", predicate: predicate, options:  [CKQuerySubscriptionOptions.firesOnRecordUpdate, CKQuerySubscriptionOptions.firesOnRecordCreation])
            
            let publicData = CKContainer.default().publicCloudDatabase
            
            publicData.save(subscription) { (subscription:CKSubscription?, error:Error?) in
                if let e = error {
                    print(e.localizedDescription)
                } else {
                    userDefaults.set(true, forKey: "sessionSub")
                    userDefaults.synchronize()
                }
            }
        }
    }
    
    func loadData() {
        let query = CKQuery(recordType: "Participant", predicate: NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID]))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let participants = results {
                self.participants = participants
                self.sortParticipants()
                self.checkHelpStatus()
                DispatchQueue.main.async(execute: { () -> Void in
                    self.tableView.reloadData()
                    self.refresh.endRefreshing()
                    self.view.layoutSubviews()
                })
            }
        }
    }
    
    func checkUser() {
        var userExists = false
        let query = CKQuery(recordType: "Participant", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let participants = results {
                for participant in participants {
                    let participantID = participant.object(forKey: "ParticipantID") as! Int
                    let pSessionID = participant.object(forKey: "SessionID") as! Int
                    if participantID == self.userID && pSessionID == self.sessionID {
                        userExists = true
                        self.getRecordName()
                        self.helpBtn.isEnabled = true
                        break
                    }
                }
                if userExists == false {
                    self.addParticipant()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                        self.getRecordName()
                        self.helpBtn.isEnabled = true
                    })
                }
            }
        }
    }
    
    func checkHelpStatus() {
        if myRecordName != "" {
            let recordID = CKRecordID(recordName: myRecordName)
            
            publicData.fetch(withRecordID: recordID) { (record:CKRecord?, error:Error?) in
                if error == nil {
                    let theStatus = record?.object(forKey: "Status") as? String
                    
                    if theStatus == "waiting" {
                        self.helpBtn.isEnabled = false
                    } else {
                        self.helpBtn.isEnabled = true
                    }
                } else if let e = error {
                    print(e.localizedDescription)
                }
            }
        }
    }

    func addParticipant() {
        let newParticipant = CKRecord(recordType: "Participant")
        newParticipant["Username"] = username as CKRecordValue?
        newParticipant["ParticipantID"] = userID as CKRecordValue?
        newParticipant["Status"] = status as CKRecordValue?
        newParticipant["SessionID"] = sessionID as CKRecordValue?
        
        publicData.save(newParticipant, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.tableView.beginUpdates()
                    self.participantsNotWaiting.insert(newParticipant, at: 0)
                    let indexPath = NSIndexPath(row: 0, section: 1)
                    self.tableView.insertRows(at: [indexPath as IndexPath], with: UITableViewRowAnimation.top)
                    self.tableView.endUpdates()
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
        
    }
    
    func requestTicketFromCloud() {
        let recordID = CKRecordID(recordName: myRecordName)
 
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                record?.setObject("waiting" as CKRecordValue, forKey: "Status")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully updated record!")
                        self.helpBtn.isEnabled = false
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func getRecordName() {
        let query = CKQuery(recordType: "Participant", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let participants = results {
                for participant in participants {
                    let participantID = participant.object(forKey: "ParticipantID") as! Int
                    let pSessionID = participant.object(forKey: "SessionID") as! Int
                    if participantID == self.userID && pSessionID == self.sessionID {
                        let recordID = participant.value(forKey: "recordID") as! CKRecordID
                        self.myRecordName = recordID.recordName
                    }
                }
            }
        }
    }
    
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

    @IBAction func requestTicket(_ sender: Any) {
        requestTicketFromCloud()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
            self.loadData()
        })
    }
    
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
            
            cell.textLabel?.text = participantWaiting["Username"] as? String
            cell.detailTextLabel?.text = dateString
            cell.backgroundColor = UIColor(red:206/255, green:74/255, blue:80/255, alpha:1)
            
            return cell
            
        } else {
            let participantNotWaiting = participantsNotWaiting[indexPath.row]
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "MM/dd/yyyy HH:mm"
            let dateString = dateFormat.string(from: participantNotWaiting.modificationDate!)
            
            cell.textLabel?.text = participantNotWaiting["Username"] as? String
            cell.detailTextLabel?.text = dateString
            cell.backgroundColor = UIColor(red:236/255, green:240/255, blue:241/255, alpha:1)
            
            return cell
        }
    }
}
