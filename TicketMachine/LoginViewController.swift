//
//  LoginViewController.swift
//  TicketMachine
//
//  Created by Arvids Gargurnis on 11/04/2017.
//  Copyright © 2017 Arvids Gargurnis. All rights reserved.
//

import UIKit
import CloudKit

class LoginViewController: UIViewController {
    @IBOutlet weak var segmentController: UISegmentedControl!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var idField: UITextField!
    @IBOutlet weak var mainButton: UIButton!
    
    let publicData = CKContainer.default().publicCloudDatabase
    var users = [CKRecord]()
    
    let role = "student"
    let status = "notWaiting"
    var recordID: CKRecordID?

    override func viewDidLoad() {
        super.viewDidLoad()

        segmentController.selectedSegmentIndex = 0
        nameField.text = ""
        passwordField.text = ""
        idField.text = ""
        idField.isHidden = true
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func segmentChanged(_ sender: Any) {
        if segmentController.selectedSegmentIndex == 0 {
            mainButton.setTitle("Login", for: .normal)
            idField.isHidden = true
            nameField.text = ""
            passwordField.text = ""
            idField.text = ""
        } else if segmentController.selectedSegmentIndex == 1 {
            mainButton.setTitle("Register", for: .normal)
            idField.isHidden = false
            nameField.text = ""
            passwordField.text = ""
            idField.text = ""
        }
    }

    @IBAction func buttonClicked(_ sender: Any) {
        if segmentController.selectedSegmentIndex == 0 {
            authenticateUser()
        } else if segmentController.selectedSegmentIndex == 1 {
            registerUser()
        }
    }
    
    func registerUser() {
        let newUser = CKRecord(recordType: "Account")
        newUser["username"] = nameField.text as CKRecordValue?
        newUser["password"] = passwordField.text as CKRecordValue?
        newUser["id"] = Int(idField.text!) as CKRecordValue?
        newUser["role"] = role as CKRecordValue?
        newUser["status"] = status as CKRecordValue?
        
        publicData.save(newUser, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.resetView()
                })
            } else if let e = error {
                print(e.localizedDescription)
            }
        })
    }
    
    func authenticateUser() {
        let query = CKQuery(recordType: "Account", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let users = results {
                for user in users {
                    let username = user.object(forKey: "username") as! String
                    let password = user.object(forKey: "password") as! String
                    if self.nameField.text == username && self.passwordField.text == password {
                        let userRole = user.object(forKey: "role") as! String
                        DispatchQueue.main.async(execute: { () -> Void in
                            self.loginUser(userRole: userRole)
                        })
                    } else {
                        print("Login failed")
                    }
                }
            }
        }
    }
    
    func loginUser(userRole:String) {
        if userRole == "student" {
            performSegue(withIdentifier: "studentSegue", sender: self)
            nameField.text = ""
            passwordField.text = ""
        } else if userRole == "tutor" {
            performSegue(withIdentifier: "tutorSegue", sender: self)
            nameField.text = ""
            passwordField.text = ""
        }
    }
    
    func resetView() {
        segmentController.selectedSegmentIndex = 0
        mainButton.setTitle("Login", for: .normal)
        nameField.text = ""
        passwordField.text = ""
        idField.isHidden = true
    }
    
}
