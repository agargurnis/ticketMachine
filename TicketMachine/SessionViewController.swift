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
    var sessionID = String()
    var userID = String()
    var myRecordName = String()
    var myRecordID: CKRecordID!
    var myRecord: CKRecord!
    var sessionName = String()
    var myRequestRecordID: CKRecordID!
    var myRequestRecordName = String()
    var recordExists = false
    
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
        
        if userDefaults.bool(forKey: "queueSubscription") == false {
            let predicate = NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID])
            let subscription = CKQuerySubscription(recordType: "Participant", predicate: predicate, options: CKQuerySubscriptionOptions.firesOnRecordUpdate)
            
            let notificationInfo = CKNotificationInfo()
            //notificationInfo.shouldBadge = true
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            
            publicData.save(subscription) { (subscription:CKSubscription?, error:Error?) in
                if let e = error {
                    print(e.localizedDescription)
                } else {
                    userDefaults.set(true, forKey: "queueSubscription")
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
                var unsortedArray = [CKRecord]()
                for participant in participants {
                    let participantStatus = participant.object(forKey: "Status") as? String
                    if participantStatus == "waiting" {
                        unsortedArray.append(participant)
                    }
                }
                self.participantsWaiting = self.sortData(recordArray: unsortedArray)
            }
            
            DispatchQueue.main.async {
                self.checkHelpStatus()
            }
        }
    }
    
    func sortData(recordArray: [CKRecord]) -> [CKRecord] {
        guard recordArray.count > 1 else { return recordArray }
        
        var sortedArray = recordArray
        
        for i in stride(from: 1, to: recordArray.count, by: 1) {
            let modDate1 = sortedArray[i].object(forKey: "modificationDate") as! Date
            let modDate2 = sortedArray[i-1].object(forKey: "modificationDate") as! Date
            if modDate1.timeIntervalSince1970 < modDate2.timeIntervalSince1970 {
                let temp = sortedArray[i]
                sortedArray[i] = sortedArray[i-1]
                sortedArray[i-1] = temp
            }
        }
        return sortedArray
    }
    
    func checkUser() {
        var userExists = false
        let query = CKQuery(recordType: "Participant", predicate: NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID]))
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let participants = results {
    
                for participant in participants {
                    let participantID = participant.object(forKey: "ParticipantID") as! String
                    let pSessionID = participant.object(forKey: "SessionID") as! String
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
                        self.addNoParticipants()
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
                    self.queueLbl.text = ""
                }
            } else if waiting == false && people == 1{
                self.queueLbl.text = String(people) + " person"
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
                    
                    if theStatus == "notWaiting" {
                        self.notWaitingUI()
                    } else if theStatus == "waiting" {
                        self.waitingUI()
                    } else {
                        self.beingSeenUI()
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
                DispatchQueue.main.async {
                    done()
                }
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func addNoParticipants() {
        let recordID = CKRecordID(recordName: sessionID)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                var noParticipants = Int()
                if record?.object(forKey: "NoParticipants") as? Int == nil {
                    noParticipants = 1
                } else {
                    noParticipants = record?.object(forKey: "NoParticipants") as! Int
                    noParticipants += 1
                }
                
                record?.setObject(noParticipants as CKRecordValue, forKey: "NoParticipants")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully updated responses int!")
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func addNoHelpRequest() {
        let recordID = CKRecordID(recordName: sessionID)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                var noRequests = Int()
                if record?.object(forKey: "NoHelpRequests") as? Int == nil {
                    noRequests = 1
                } else {
                    noRequests = record?.object(forKey: "NoHelpRequests") as! Int
                    noRequests += 1
                }
                
                record?.setObject(noRequests as CKRecordValue, forKey: "NoHelpRequests")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully updated help reuqests int!")
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func addNoWithdraws() {
        let recordID = CKRecordID(recordName: sessionID)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                var noWithdraws = Int()
                if record?.object(forKey: "NoWithdraws") as? Int == nil {
                    noWithdraws = 1
                } else {
                    noWithdraws = record?.object(forKey: "NoWithdraws") as! Int
                    noWithdraws += 1
                }
                
                record?.setObject(noWithdraws as CKRecordValue, forKey: "NoWithdraws")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully updated withdraws int!")
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func addRequest() {
        let newRequest = CKRecord(recordType: "Request")
        newRequest["SessionID"] = sessionID as CKRecordValue
        newRequest["Requester"] = username as CKRecordValue
        
        publicData.save(newRequest, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                print("record added successfully")
                self.addNoHelpRequest()
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func removeRequest() {
        let query = CKQuery(recordType: "Request", predicate: NSPredicate(format: "%K == %@", argumentArray: ["Requester", username]))
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let requests = results {
                for request in requests {
                    self.publicData.delete(withRecordID: request.recordID, completionHandler: { (record:CKRecordID?, error:Error?) in
                        if error == nil {
                            print("Record Successfully Deleted Request")
                            self.addNoWithdraws()
                        } else if let e = error {
                            print(e.localizedDescription)
                        }
                    })
                }
            }
        }
    }
    
    func requestHelpFromCloud( done : @escaping DONE ) {
        let recordID = CKRecordID(recordName: myRecordName)
        let now = Date()
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                record?.setObject("waiting" as CKRecordValue, forKey: "Status")
                record?.setObject(now as CKRecordValue, forKey: "WaitTime")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully requested help!")
                        self.addRequest()
                        DispatchQueue.main.async {
                            done()
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
    
    func withdrawHelpFromCloud( done : @escaping DONE ) {
        let recordID = CKRecordID(recordName: myRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                record?.setObject("notWaiting" as CKRecordValue, forKey: "Status")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully withdrawn request!")
                        self.removeRequest()
                        DispatchQueue.main.async {
                            done()
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
    
    func getRecordName( done : @escaping DONE ) {
        let query = CKQuery(recordType: "Participant", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let participants = results {
                for participant in participants {
                    let participantID = participant.object(forKey: "ParticipantID") as! String
                    let pSessionID = participant.object(forKey: "SessionID") as! String
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
    
    func beingSeenUI() {
        DispatchQueue.main.async {
            self.queueImg.image = UIImage(named: "queue")
            self.setQueueLbl(people: 1, waiting: true)
            self.helpBtn.isEnabled = false
            self.helpImg.alpha = 0.2
            self.withdrawBtn.isEnabled = true
            self.withdrawImg.alpha = 1
        }
    }
    
    func waitingUI() {
        DispatchQueue.main.async {
            self.queueImg.image = UIImage(named: "queue")
            self.setQueueLbl(people: self.queuePosition(), waiting: true)
            self.helpBtn.isEnabled = false
            self.helpImg.alpha = 0.2
            self.withdrawBtn.isEnabled = true
            self.withdrawImg.alpha = 1
        }
    }
    
    func notWaitingUI() {
        DispatchQueue.main.async {
            if self.participantsWaiting.count == 1 {
                self.queueImg.image = UIImage(named: "person")
            } else {
                self.queueImg.image = UIImage(named: "people")
            }
            self.setQueueLbl(people: self.participantsWaiting.count, waiting: false)
            self.helpBtn.isEnabled = true
            self.helpImg.alpha = 1
            self.withdrawBtn.isEnabled = false
            self.withdrawImg.alpha = 0.2
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
        var positionInQueue = Int()
        
        let indexOfParticipant = findRecordIndex(records: participantsWaiting, record: myRecord)
        if indexOfParticipant != nil {
            positionInQueue = indexOfParticipant! + 1
        } else {
            positionInQueue = 0
        }
        
        return positionInQueue
    }
    
    @IBAction func requestHelp(_ sender: Any) {
        helpBtn.isEnabled = false
        helpImg.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 1, initialSpringVelocity: 6, options: .allowUserInteraction, animations: {
            self.helpImg.transform = CGAffineTransform.identity
        }) { (_ : Bool) -> Void in
            self.requestHelpFromCloud() {
                self.loadData()
            }
        }
    }
    
    @IBAction func withdrawHelp(_ sender: Any) {
        withdrawBtn.isEnabled = false
        withdrawImg.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 1, initialSpringVelocity: 6, options: .allowUserInteraction, animations: {
            self.withdrawImg.transform = CGAffineTransform.identity
        })  { (_ : Bool) -> Void in
            self.withdrawHelpFromCloud() {
                self.loadData()
            }
        }
    }

}
