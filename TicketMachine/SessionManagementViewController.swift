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
    
    typealias DONE = ()->Void
    
    let publicData = CKContainer.default().publicCloudDatabase
    var sessionID = String()
    var sessionRecordName = String()
    var sessionName = String()
    var username = String()
    var tutorRecordName = String()
    var responseStarted = false
    var participantBS: CKRecordID!
    
    var tutorRecord: CKRecord!
    var tutors = [CKRecord]()
    var participants = [CKRecord]()
    var participantsWaiting = [CKRecord]()
    var participantsNotWaiting = [CKRecord]()
    var participantsBeingSeen = [CKRecord]()
    
    var refresh: UIRefreshControl!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = sessionName
            
        loadData()
        
        refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Pull to load qustions")
        refresh.addTarget(self, action: #selector(SessionManagementViewController.loadData), for: .valueChanged)
        self.tableView.addSubview(refresh)
        
        DispatchQueue.main.async { () -> Void in
            NotificationCenter.default.addObserver(self, selector: #selector(SessionManagementViewController.loadData), name: NSNotification.Name(rawValue: "performReload"), object: nil)
        }
        
        checkTutor()
        setupCloudKitSubscription()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func setupCloudKitSubscription() {
        let userDefaults = UserDefaults.standard

        if userDefaults.bool(forKey: "requestSubscription") == false {
            let predicate = NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID])
            let subscription = CKQuerySubscription(recordType: "Request", predicate: predicate, options: CKQuerySubscriptionOptions.firesOnRecordCreation)
            let notificationInfo = CKNotificationInfo()
            notificationInfo.alertLocalizationKey = "New Question From: %1$@"
            notificationInfo.alertLocalizationArgs = ["Requester"]
            notificationInfo.shouldBadge = true

            subscription.notificationInfo = notificationInfo
            
            publicData.save(subscription) { (subscription:CKSubscription?, error:Error?) in
                if let e = error {
                    print(e.localizedDescription)
                } else {
                    userDefaults.set(true, forKey: "requestSubscription")
                    userDefaults.synchronize()
                }
            }
        }
        
        if userDefaults.bool(forKey: "participantSubscription") == false {
            let predicate = NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID])
            let subscription = CKQuerySubscription(recordType: "Participant", predicate: predicate, options: [CKQuerySubscriptionOptions.firesOnRecordCreation, CKQuerySubscriptionOptions.firesOnRecordUpdate])
            let notificationInfo = CKNotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            
            subscription.notificationInfo = notificationInfo
            
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
        loadTutorData()
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
                            self.deleteTutors()
                            self.deleteRequests()
                            self.performSegue(withIdentifier: "toSessionStatisticsView", sender: self)
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
    
    func deleteRequests() {
        let query = CKQuery(recordType: "Request", predicate: NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID]))
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let requests = results {
                for request in requests {
                    self.publicData.delete(withRecordID: request.recordID, completionHandler: { (record:CKRecordID?, error:Error?) in
                        if error == nil {
                            print("Record Successfully Deleted Request")
                        } else if let e = error {
                            print(e.localizedDescription)
                        }
                    })
                }
            }
        }
    }
    
    func deleteParticipants() {
        for particpant in participants {
            publicData.delete(withRecordID: particpant.recordID, completionHandler: { (record:CKRecordID?, error:Error?) in
                if error == nil {
                    print("Record Successfully Deleted Participants")
                } else if let e = error {
                    print(e.localizedDescription)
                }
            })
        }
    }
    
    func deleteTutors() {
        for tutor in tutors {
            publicData.delete(withRecordID: tutor.recordID, completionHandler: { (record:CKRecordID?, error:Error?) in
                if error == nil {
                    print("Record Successfully Deleted Tutors")
                } else if let e = error {
                    print(e.localizedDescription)
                }
            })
        }
    }
    
    func sortParticipants() {
        participantsWaiting.removeAll()
        participantsNotWaiting.removeAll()
        participantsBeingSeen.removeAll()
        for participant in participants {
            let status = participant["Status"] as? String
            if status == "waiting" {
                self.participantsWaiting.append(participant)
            } else if status == "notWaiting" {
                self.participantsNotWaiting.append(participant)
            } else {
                self.participantsBeingSeen.append(participant)
            }
        }
    }
    
    func checkTutor() {
        var tutorExists = false
        let query = CKQuery(recordType: "Tutor", predicate: NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID]))
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let tutors = results {
                for tutor in tutors {
                    let username = tutor.object(forKey: "Username") as! String
                    let sessionID = tutor.object(forKey: "SessionID") as! String
                    if username == self.username && sessionID == self.sessionID {
                        tutorExists = true
                        let tutorID = tutor.object(forKey: "recordID") as! CKRecordID
                        self.tutorRecordName = tutorID.recordName
                    }
                }
                if tutorExists == false {
                    self.addTutor() {
                        self.loadTutorData()
                        self.addNoTutors()
                    }
                }
            }
        }
    }

    
    func addTutor( done : @escaping DONE ) {
        let newTutor = CKRecord(recordType: "Tutor")
        newTutor["Username"] = username as CKRecordValue?
        newTutor["SessionID"] = sessionID as CKRecordValue?
        
        publicData.save(newTutor, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                print("Seccesssfully added a new tutor")
                DispatchQueue.main.async {
                    done()
                }
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func loadTutorData() {
        let query = CKQuery(recordType: "Tutor", predicate: NSPredicate(format: "%K == %@", argumentArray: ["SessionID", sessionID]))
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let tutors = results {
                self.tutors = tutors
                for tutor in tutors {
                    let username = tutor.object(forKey: "Username") as! String
                    let sessionID = tutor.object(forKey: "SessionID") as! String
                    if username == self.username && sessionID == self.sessionID {
                        self.tutorRecord = tutor
                        let tutorID = tutor.object(forKey: "recordID") as! CKRecordID
                        self.tutorRecordName = tutorID.recordName
                    }
                }
            }
        }
    }
    
    func addResponseTime(responseTime: String) {
        let recordID = CKRecordID(recordName: sessionRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                var timeArray = [String]()
                if record?.object(forKey: "ResponseArray") as? [String] == nil {
                    timeArray.append(responseTime)
                } else {
                    timeArray = record?.object(forKey: "ResponseArray") as! [String]
                    timeArray.append(responseTime)
                }
                
                record?.setObject(timeArray as CKRecordValue, forKey: "ResponseArray")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully updated responseTimes!")
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func addWaitTime(waitTime: String) {
        let recordID = CKRecordID(recordName: sessionRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                var timeArray = [String]()
                if record?.object(forKey: "WaitArray") as? [String] == nil {
                    timeArray.append(waitTime)
                } else {
                    timeArray = record?.object(forKey: "WaitArray") as! [String]
                    timeArray.append(waitTime)
                }
                
                record?.setObject(timeArray as CKRecordValue, forKey: "WaitArray")
                
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully updated waitTimes!")
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func startResponse( done : @escaping DONE ) {
    
        let recordID = CKRecordID(recordName: tutorRecordName)
        let now = Date()
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                record?.setObject(now as CKRecordValue, forKey: "ResponseTime")
                
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully added response time!")
                        self.responseStarted = true
                        done()
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func changeStatus(participantRecordName: String, done : @escaping DONE) {
        let recordID = CKRecordID(recordName: participantRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                record?.setObject("beingSeen" as CKRecordValue, forKey: "Status")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully updated record!")
                        done()
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func finishResponse(participantRecordName: String, done : @escaping DONE) {
        let recordID = CKRecordID(recordName: participantRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                record?.setObject("notWaiting" as CKRecordValue, forKey: "Status")
                
                self.publicData.save(record!, completionHandler: { (savedRecord:CKRecord?, saveError:Error?) in
                    if saveError == nil {
                        print("Successfully updated record!")
                        self.responseStarted = false
                        self.addNoResponses()
                        done()
                    } else if let e = saveError {
                        print(e.localizedDescription)
                    }
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func addNoTutors() {
        let recordID = CKRecordID(recordName: sessionRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                var noTutors = Int()
                if record?.object(forKey: "NoTutors") as? Int == nil {
                    noTutors = 1
                } else {
                    noTutors = record?.object(forKey: "NoTutors") as! Int
                    noTutors += 1
                }
                
                record?.setObject(noTutors as CKRecordValue, forKey: "NoTutors")
                
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

    func addNoResponses() {
        let recordID = CKRecordID(recordName: sessionRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                var noResponses = Int()
                if record?.object(forKey: "NoResponses") as? Int == nil {
                    noResponses = 1
                } else {
                    noResponses = record?.object(forKey: "NoResponses") as! Int
                    noResponses += 1
                }
                
                record?.setObject(noResponses as CKRecordValue, forKey: "NoResponses")
                
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toSessionStatisticsView" {
            if let destinationController = segue.destination as? SessionStatisticViewController {
                destinationController.sessionID = sessionID
                destinationController.sessionName = sessionName
                destinationController.sessionRecordName = sessionRecordName
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return participantsBeingSeen.count
        } else if section == 1 {
            return participantsWaiting.count
        } else {
            return participantsNotWaiting.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && participantsBeingSeen.count == 0{
            return ""
        } else if section == 0 && participantsBeingSeen.count > 0 {
            return "Students being seen"
        } else if section == 1 && participantsWaiting.count == 0 {
            return ""
        } else if section == 1 && participantsWaiting.count > 0 {
            return "Students waiting"
        } else if section == 2 && participantsNotWaiting.count == 0 {
            return ""
        } else {
            return "Students not waiting"
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            let returnedView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 30))
            returnedView.backgroundColor = UIColor(red:242/255, green:214/255, blue:25/255, alpha:1)
            let label = UILabel(frame: CGRect(x: 10, y: 0, width: view.frame.size.width, height: 30))
            label.text = "Students being seen"
            label.textColor = .black
            label.font = UIFont.boldSystemFont(ofSize: 16)
            returnedView.addSubview(label)
            return returnedView
        } else if section == 1 {
            let returnedView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 30))
            returnedView.backgroundColor = UIColor(red:206/255, green:74/255, blue:80/255, alpha:1)
            let label = UILabel(frame: CGRect(x: 10, y: 0, width: view.frame.size.width, height: 30))
            label.text = "Students waiting"
            label.textColor = .black
            label.font = UIFont.boldSystemFont(ofSize: 16)
            returnedView.addSubview(label)
            return returnedView
        } else {
            let returnedView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 30))
            returnedView.backgroundColor = UIColor(red:9/255, green:154/255, blue:77/255, alpha:1)
            let label = UILabel(frame: CGRect(x: 10, y: 0, width: view.frame.size.width, height: 30))
            label.text = "Students not waiting"
            label.textColor = .black
            label.font = UIFont.boldSystemFont(ofSize: 16)
            returnedView.addSubview(label)
            return returnedView
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "participantCell", for: indexPath)
        
        if indexPath.section == 0 {
            let participantBeingSeen = participantsBeingSeen[indexPath.row]
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "HH:mm:ss"
            let dateString = dateFormat.string(from: participantBeingSeen.modificationDate!)
            
            cell.textLabel?.text = participantBeingSeen["Username"] as? String
            cell.detailTextLabel?.text = dateString
            cell.backgroundColor = UIColor(red:236/255, green:240/255, blue:241/255, alpha:1)
            
            return cell
            
        } else if indexPath.section == 1 {
            let participantWaiting = participantsWaiting[indexPath.row]
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "HH:mm:ss"
            let dateString = dateFormat.string(from: participantWaiting.modificationDate!)
            
            cell.textLabel?.text = participantWaiting["Username"] as? String
            cell.detailTextLabel?.text = dateString
            cell.backgroundColor = UIColor(red:236/255, green:240/255, blue:241/255, alpha:1)
            
            return cell
            
        } else {
            let participantNotWaiting = participantsNotWaiting[indexPath.row]
            let dateFormat = DateFormatter()
            dateFormat.dateFormat = "HH:mm:ss"
            let dateString = dateFormat.string(from: participantNotWaiting.modificationDate!)
            
            cell.textLabel?.text = participantNotWaiting["Username"] as? String
            cell.detailTextLabel?.text = dateString
            cell.backgroundColor = UIColor(red:236/255, green:240/255, blue:241/255, alpha:1)
            
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        if tutorRecordName != "" {
            if indexPath.section == 0 && self.participantsBeingSeen[indexPath.row].object(forKey: "recordID") as? CKRecordID == self.participantBS {
                let finishAction = UITableViewRowAction.init(style: .normal, title: "Finish") { (action:UITableViewRowAction, indexPath:IndexPath) in
                    
                    if self.participantsBeingSeen.count != 0 {
                        let selectedParticipant = self.participantsBeingSeen[indexPath.row]
                        let participantRecordID = selectedParticipant["recordID"] as! CKRecordID
                        let responseTime = self.tutorRecord["ResponseTime"] as? Date
                        let now = Date()
                        
                        let formatter = DateComponentsFormatter()
                        formatter.unitsStyle = .full
                        formatter.allowedUnits = [.hour, .minute, .second]
                        let timeString = formatter.string(from: responseTime!, to: now)
                        
                        self.addResponseTime(responseTime: timeString!)
                        
                        let timeAlert = UIAlertController(title: "It Took You..", message: "", preferredStyle: .alert)
                        timeAlert.message?.append(timeString!)
                        timeAlert.message?.append("\n To Answer To This Help Request.")
                        timeAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                        self.present(timeAlert, animated: true, completion: nil)
                        
                        let recordName = participantRecordID.recordName
                        self.finishResponse(participantRecordName: recordName){
                            self.loadData()
                        }
                    } else {
                        print("empty array")
                    }
                }
                finishAction.backgroundColor = UIColor(red:9/255, green:154/255, blue:77/255, alpha:1)
                return [finishAction]
                
            } else if indexPath.section == 1 && responseStarted == false {
                let startAction = UITableViewRowAction.init(style: .normal, title: "Start") { (action:UITableViewRowAction, indexPath:IndexPath) in
                    
                    if self.participantsWaiting.count != 0 {
                        let selectedParticipant = self.participantsWaiting[indexPath.row]
                        let participantRecordID = selectedParticipant["recordID"] as! CKRecordID
                        self.participantBS = participantRecordID
                        let checkTime = selectedParticipant["WaitTime"] as? Date
                        let now = Date()
                        
                        let formatter = DateComponentsFormatter()
                        formatter.unitsStyle = .full
                        formatter.allowedUnits = [.hour, .minute, .second]
                        let timeString = formatter.string(from: checkTime!, to: now)
                        
                        let recordName = participantRecordID.recordName
                        self.addWaitTime(waitTime: timeString!)
                        self.startResponse() {
                            self.changeStatus(participantRecordName: recordName) {
                                self.loadData()
                            }
                        }
                        
                        let timeAlert = UIAlertController(title: "It Took You..", message: "", preferredStyle: .alert)
                        timeAlert.message?.append(timeString!)
                        timeAlert.message?.append("\n To Respond To This Help Request.")
                        timeAlert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                        self.present(timeAlert, animated: true, completion: nil)
                    } else {
                        print("empty array")
                    }
                }
                startAction.backgroundColor = UIColor(red:242/255, green:214/255, blue:25/255, alpha:1)
                return [startAction]
                
            } else {
                let notWaitingAction = UITableViewRowAction.init(style: .normal, title: "No Actions Available", handler: { (action:UITableViewRowAction, indexPath:IndexPath) in
                    // no actions available
                })
                notWaitingAction.backgroundColor = UIColor(red:85/255, green:97/255, blue:112/255, alpha:1)
                return [notWaitingAction]
            }
        } else {
            loadTutorData()
            let waitAction = UITableViewRowAction.init(style: .normal, title: "Loading", handler: { (action:UITableViewRowAction, indexPath:IndexPath) in
                // waiting
            })
            waitAction.backgroundColor = UIColor(red:85/255, green:97/255, blue:112/255, alpha:1)
            return [waitAction]
        }
    }
}
