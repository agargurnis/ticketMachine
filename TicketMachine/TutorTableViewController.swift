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

class TutorTableViewController: UITableViewController, UNUserNotificationCenterDelegate, UITextFieldDelegate {
    
    typealias DONE = ()->Void
    
    let publicData = CKContainer.default().publicCloudDatabase

    var sessionAlert = UIAlertController()
    var username = String()
    var sessionNextID = Int()
    var sessions = [CKRecord]()
    var refresh = UIRefreshControl()
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
    
    @IBAction func createSession(_ sender: Any) {
        newSession()
    }
    
    func newSession() {
        sessionAlert = UIAlertController(title: "New Session", message: "Enter a Session Name \n and a \n 4 Digit Passcodes", preferredStyle: .alert)
        sessionAlert.addTextField { (nameField: UITextField) in
            nameField.placeholder = "Session Name"
        }
        sessionAlert.addTextField { (studentCodeField: UITextField) in
            studentCodeField.placeholder = "Session Passcode for Students"
            studentCodeField.keyboardType = .numberPad
            studentCodeField.delegate = self
            studentCodeField.addTarget(self, action: #selector(self.checkPasscodeLength(_:)), for: .editingChanged)
            studentCodeField.addTarget(self, action: #selector(self.textField(_:shouldChangeCharactersIn:replacementString:)), for: .editingChanged)
            studentCodeField.addTarget(self, action: #selector(self.alertTextFieldDidChange(_:)), for: .editingChanged)
        }
        sessionAlert.addTextField { (tutorCodeField: UITextField) in
            tutorCodeField.placeholder = "Session Passcode for Tutors"
            tutorCodeField.keyboardType = .numberPad
            tutorCodeField.delegate = self
            tutorCodeField.addTarget(self, action: #selector(self.checkPasscodeLength(_:)), for: .editingChanged)
            tutorCodeField.addTarget(self, action: #selector(self.textField(_:shouldChangeCharactersIn:replacementString:)), for: .editingChanged)
            tutorCodeField.addTarget(self, action: #selector(self.alertTextFieldDidChange(_:)), for: .editingChanged)
        }
        
        let createAction = UIAlertAction(title: "Create Session", style: .default) { (action: UIAlertAction) in
            let nameField = self.sessionAlert.textFields?[0]
            let studentCodeField = self.sessionAlert.textFields?[1]
            let tutorCodeField = self.sessionAlert.textFields?[2]
            
            if nameField?.text != "" {
                let newSession = CKRecord(recordType: "Session")
                newSession["Name"] = nameField?.text as CKRecordValue?
                newSession["StudentCode"] = Int((studentCodeField?.text!)!) as CKRecordValue?
                newSession["TutorCode"] = Int((tutorCodeField?.text!)!) as CKRecordValue?
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
            } else {
                self.newSession()
            }
        }
        
        sessionAlert.addAction(createAction)
        createAction.isEnabled = false
        
        sessionAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(sessionAlert, animated: true, completion: nil)

    }
    
    func alertTextFieldDidChange(_ textField: UITextField){
        let textField1: UITextField  = sessionAlert.textFields![1];
        let textField2: UITextField  = sessionAlert.textFields![2];
        let createAction: UIAlertAction = sessionAlert.actions[0];
        if textField1.text?.characters.count == 4 && textField2.text?.characters.count == 4 {
            createAction.isEnabled = true
        } else {
            createAction.isEnabled = false
        }
    }
    
    func checkPasscodeLength(_ textField: UITextField!) {
        if textField.text!.characters.count > 4 {
            textField.deleteBackward()
        } else if textField.text?.characters.count == 4 {
            //createAction.isEnabled = sessionAlert.textFields?[1].text?.characters.count == 4
        }
    }
    
    func checkPasscodeDigits(_ textField: UITextField) -> Bool {
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: textField.text!)
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
    {
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var indexPath: IndexPath = self.tableView.indexPathForSelectedRow!
        let destination = segue.destination as! PasscodeViewController
        
        let selectRecord = sessions[indexPath.row]
        
        let sessionName = selectRecord.object(forKey: "Name") as? String
        let sessionRecordID = selectRecord.object(forKey: "recordID") as? CKRecordID
        let recordName = sessionRecordID?.recordName
        let passcode = selectRecord.object(forKey: "TutorCode") as? Int
        let whichPasscode = "Tutor"
        
        destination.username = username
        destination.sessionID = recordName!
        destination.sessionName = sessionName!
        destination.whichPasscode = whichPasscode
        destination.sessionPass = passcode!
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
