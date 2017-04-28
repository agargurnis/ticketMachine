//
//  SessionManagementViewController.swift
//  TicketMachine
//
//  Created by Arvids Gargurnis on 14/04/2017.
//  Copyright © 2017 Arvids Gargurnis. All rights reserved.
//

import UIKit
import CloudKit

class SessionManagementViewController: UITableViewController, UIGestureRecognizerDelegate {
    
    let publicData = CKContainer.default().publicCloudDatabase
    var sessionID = Int()
    var sessionRecordName = String()
    var sessionName = String()
    
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
        
        setupCloudKitSubscription()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func setupCloudKitSubscription() {
        let userDefaults = UserDefaults.standard

        if userDefaults.bool(forKey: "participantSubscription") == false {
            let predicate = NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID])
            let subscription = CKQuerySubscription(recordType: "Participant", predicate: predicate, options: CKQuerySubscriptionOptions.firesOnRecordUpdate)
            let notificationInfo = CKNotificationInfo()
            notificationInfo.alertLocalizationKey = "New Question In Session: " + sessionName
            notificationInfo.shouldBadge = true

            subscription.notificationInfo = notificationInfo

            let publicData = CKContainer.default().publicCloudDatabase

            publicData.save(subscription) { (subscription:CKSubscription?, error:Error?) in
                if let e = error {
                    print(e.localizedDescription)
                } else {
                    userDefaults.set(true, forKey: "participantSubscription")
                    userDefaults.synchronize()
                }
            }
        }
    }

    func loadData() {
        let query = CKQuery(recordType: "Participant", predicate: NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID]))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: true)]
        
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
    
    @IBAction func goBack(_ sender: Any) {
        self.navigationController?.popToViewController((navigationController?.viewControllers[1])!, animated: true)
    }
    
    @IBAction func endSession(_ sender: Any) {
    
        let closeAlert = UIAlertController(title: "Close Session", message: "Are you sure you want to close this session?", preferredStyle: .alert)
    
        closeAlert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { (action: UIAlertAction) in
            self.closeSession()
        }))
    
        closeAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(closeAlert, animated: true, completion: nil)
    }
    
    func closeSession() {
        let recordID = CKRecordID(recordName: sessionRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                record?.setObject("closed" as CKRecordValue, forKey: "Status")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully closed session!")
                        self.title = "Session Closed"
                        DispatchQueue.main.async {
                            self.deleteParticipants()
                        }
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func deleteParticipants() {
        for particpant in participants {
            publicData.delete(withRecordID: particpant.recordID, completionHandler: { (record:CKRecordID?, error:Error?) in
                if error == nil {
                    print("Record Successfully Deleted")
                } else if let e = error {
                    print(e.localizedDescription)
                }
            })
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
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let answerAction = UITableViewRowAction.init(style: .normal, title: "Checked") { (action:UITableViewRowAction, indexPath:IndexPath) in
        
            if self.participantsWaiting.count != 0 {
                let selectedParticipant = self.participantsWaiting[indexPath.row]
                let participantRecordID = selectedParticipant["recordID"] as! CKRecordID
                let answerTime = selectedParticipant["HelpTime"] as? Date
                let now = Date()
                
                let formatter = DateComponentsFormatter()
                formatter.unitsStyle = .full
                formatter.allowedUnits = [.hour, .minute, .second]
                let string = formatter.string(from: answerTime!, to: now)
                
                let timeAlert = UIAlertController(title: "It Took You..", message: "", preferredStyle: .alert)
                timeAlert.message?.append(string!)
                timeAlert.message?.append("\n To Respond To This Help Request.")
                timeAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                self.present(timeAlert, animated: true, completion: nil)

                let recordName = participantRecordID.recordName
                self.checkParticipant(participantRecordName: recordName)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                    self.loadData()
                })
            } else {
                print("empty array")
            }
        }
        
        answerAction.backgroundColor = UIColor(red:9/255, green:154/255, blue:77/255, alpha:1)
        return [answerAction]
    }

}
