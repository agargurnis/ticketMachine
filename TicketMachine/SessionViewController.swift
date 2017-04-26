//
//  SessionViewController.swift
//  TicketMachine
//
//  Created by Arvids Gargurnis on 19/04/2017.
//  Copyright © 2017 Arvids Gargurnis. All rights reserved.
//

import UIKit
import CloudKit

class SessionViewController: UIViewController {

    typealias DONE = ()->Void
    
    let publicData = CKContainer.default().publicCloudDatabase
    var username = String()
    var sessionID = Int()
    var userID = String()
    var myRecordName = String()
    var myRecordID: CKRecordID!
    var myRecord: CKRecord!
    var sessionName = String()
    
    @IBOutlet weak var refreshBtn: UIBarButtonItem!
    @IBOutlet weak var withdrawBtn: UIButton!
    @IBOutlet weak var helpBtn: UIButton!
    @IBOutlet weak var queueLbl: UILabel!
    @IBOutlet weak var helpImg: UIImageView!
    @IBOutlet weak var withdrawImg: UIImageView!
    @IBOutlet weak var queueImg: UIImageView!
    var status = "notWaiting"
    var added = false
    
    var participants = [CKRecord]()
    var participantsWaiting = [CKRecord]()
    var participantsNotWaiting = [CKRecord]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = sessionName
        
        loadData()
        
        DispatchQueue.main.async { () -> Void in
            NotificationCenter.default.addObserver(self, selector: #selector(SessionViewController.loadData), name: NSNotification.Name(rawValue: "performReload"), object: nil)
        }
        
        checkUser()
        setupCloudKitSubscription()
    }
    @IBAction func goBack(_ sender: Any) {
        self.navigationController?.popToViewController((navigationController?.viewControllers[1])!, animated: true)
    }
    
    @IBAction func refresh(_ sender: Any) {
        loadData()
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
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: true)]
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let participants = results {
                self.participantsWaiting.removeAll()
                for participant in participants {
                    let participantStatus = participant.object(forKey: "Status") as? String
                    if participantStatus == "waiting" {
                        self.participantsWaiting.append(participant)
                    }
                }

                DispatchQueue.main.async(execute: {
                    self.checkHelpStatus()
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
                    let participantID = participant.object(forKey: "ParticipantID") as! String
                    let pSessionID = participant.object(forKey: "SessionID") as! Int
                    if participantID == self.userID && pSessionID == self.sessionID {
                        userExists = true
                        self.getRecordName() {
                            self.checkHelpStatus()
                            self.refreshBtn.isEnabled = true
                        }
                        break
                    }
                }
                if userExists == false && self.added == false {
                    self.addParticipant() {
                        self.added = true
                        self.checkUser()
                    }
                } else if userExists == false && self.added == true {
                    self.checkUser()
                }
            }
        }
    }
    
    func setQueueLbl(people: Int, waiting: Bool) {
        DispatchQueue.main.async {
            if waiting == true {
                switch(people){
                case 1:
                    self.queueLbl.text = "1st"
                case 2:
                    self.queueLbl.text = "2nd"
                case 3:
                    self.queueLbl.text = "3rd"
                case 4:
                    self.queueLbl.text = String(people) + "th"
                default:
                    self.queueLbl.text = "empty"
                }
            } else {
                self.queueLbl.text = String(people) + " people"
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
                        self.waitingUI()
                    } else {
                        self.notWaitingUI()
                    }
                } else if let e = error {
                    print(e.localizedDescription)
                }
            }
        }
    }
    
    func addParticipant( done : @escaping DONE ) {
        let newParticipant = CKRecord(recordType: "Participant")
        newParticipant["Username"] = username as CKRecordValue?
        newParticipant["ParticipantID"] = userID as CKRecordValue?
        newParticipant["Status"] = status as CKRecordValue?
        newParticipant["SessionID"] = sessionID as CKRecordValue?
        
        publicData.save(newParticipant, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                DispatchQueue.main.async(execute: { () -> Void in
                    done()
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
        
    }
    
    func requestHelpFromCloud( done : @escaping DONE ) {
        let recordID = CKRecordID(recordName: myRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                record?.setObject("waiting" as CKRecordValue, forKey: "Status")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully requested help!")
                        DispatchQueue.main.async(execute: { () -> Void in
                            done()
                        })
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func withdrawHelpFromCloud( done : @escaping DONE ) {
        let recordID = CKRecordID(recordName: myRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                record?.setObject("notWaiting" as CKRecordValue, forKey: "Status")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully withdrawn request!")
                        DispatchQueue.main.async(execute: { () -> Void in
                            done()
                        })
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func getRecordName( done : @escaping DONE ) {
        let query = CKQuery(recordType: "Participant", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let participants = results {
                for participant in participants {
                    let participantID = participant.object(forKey: "ParticipantID") as! String
                    let pSessionID = participant.object(forKey: "SessionID") as! Int
                    if participantID == self.userID && pSessionID == self.sessionID {
                        self.myRecord = participant
                        self.myRecordID = participant.value(forKey: "recordID") as! CKRecordID
                        self.myRecordName = self.myRecordID.recordName
                        DispatchQueue.main.async(execute: { () -> Void in
                            done()
                        })
                    } else {
                        // not found
                    }
                }
            } else {
                // no results
            }
        }
    }
    
    func waitingUI() {
        DispatchQueue.main.async {
            self.queueImg.image = UIImage(named: "queue")
            self.setQueueLbl(people: self.queuePosition(), waiting: true)
            self.helpBtn.isEnabled = false
            self.helpImg.alpha = 0.2
            //self.helpImg.image = UIImage(named: "help2")
            self.withdrawBtn.isEnabled = true
            self.withdrawImg.alpha = 1
            //self.withdrawImg.image = UIImage(named: "withdraw")
        }
    }
    
    func notWaitingUI() {
        DispatchQueue.main.async {
            self.queueImg.image = UIImage(named: "people")
            self.setQueueLbl(people: self.participantsWaiting.count, waiting: false)
            self.helpBtn.isEnabled = true
            self.helpImg.alpha = 1
            //self.helpImg.image = UIImage(named: "help")
            self.withdrawBtn.isEnabled = false
            self.withdrawImg.alpha = 0.2
            //self.withdrawImg.image = UIImage(named: "withdraw2")
        }
    }
    
    func findRecordIndex(records: [CKRecord], record: CKRecord) -> Int? {
        var index: Int?
        var i = 0
        let recordID = record.recordID
        
        for participant in records {
            let currentRecordID = participant.recordID
            
            if recordID == currentRecordID {
                index = i
                break
            }
            i += 1
        }
        return index
    }
    
    func queuePosition() -> Int {
        var positionInQueue: Int
        
        let indexOfParticipant = findRecordIndex(records: participantsWaiting, record: myRecord)
        if indexOfParticipant != nil {
            positionInQueue = indexOfParticipant! + 1
        } else {
            positionInQueue = 0
        }
        
        return positionInQueue
    }
    
    @IBAction func requestHelp(_ sender: Any) {
        requestHelpFromCloud() {            
            self.loadData()
        }
        
    }
    
    @IBAction func withdrawHelp(_ sender: Any) {
        withdrawHelpFromCloud() {
            self.loadData()
        }
        
    }

}
