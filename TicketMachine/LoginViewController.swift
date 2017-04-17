//
//  LoginViewController.swift
//  TicketMachine
//
//  Created by Arvids Gargurnis on 11/04/2017.
//  Copyright © 2017 Arvids Gargurnis. All rights reserved.
//

import UIKit
import CloudKit

class LoginViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var segmentController: UISegmentedControl!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var idField: UITextField!
    @IBOutlet weak var mainButton: UIButton!
    
    let publicData = CKContainer.default().publicCloudDatabase
    var users = [CKRecord]()

    var username = String()
    var password = String()
    var userID = Int()
    let role = "student"

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        super.viewWillDisappear(animated)
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
        username = nameField.text!.lowercased()
        password = passwordField.text!
        
        if segmentController.selectedSegmentIndex == 0 {
            authenticateUser()
        } else if segmentController.selectedSegmentIndex == 1 {
            checkPassword()
        }
    }
    
    func checkPassword(){
        let passAlert = UIAlertController(title: "Password Verification", message: "Please verify password", preferredStyle: .alert)
        passAlert.addTextField { (passField: UITextField) in
            passField.isSecureTextEntry = true
            passField.placeholder = "Password"
        }
        
        passAlert.addAction(UIAlertAction(title: "Verify", style: .default, handler: { (action: UIAlertAction) in
            let passwordV = passAlert.textFields?.first?.text
            
            if passwordV != "" && passwordV == self.password {
                self.registerUser()
            } else {
                self.present(passAlert, animated: true, completion: nil)
            }
        }))
        
        passAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(passAlert, animated: true, completion: nil)
    }
    
    func registerUser() {
        let newUser = CKRecord(recordType: "Account")
        newUser["username"] = username as CKRecordValue?
        newUser["password"] = password as CKRecordValue?
        newUser["id"] = Int(idField.text!) as CKRecordValue?
        newUser["role"] = role as CKRecordValue?
        
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
                    if self.username == username && self.password == password {
                        let userRole = user.object(forKey: "role") as! String
                        self.userID = user.object(forKey: "id") as! Int
                        DispatchQueue.main.async(execute: { () -> Void in
                            self.loginUser(userRole: userRole)
                        })
                    } else {
                        // show fail feedback
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "studentSegue" {
            if let destinationController = segue.destination as? StudentTableViewController {
                destinationController.username = username
                destinationController.userID = userID
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    func resetView() {
        segmentController.selectedSegmentIndex = 0
        mainButton.setTitle("Login", for: .normal)
        nameField.text = ""
        passwordField.text = ""
        idField.isHidden = true
    }
    
}
