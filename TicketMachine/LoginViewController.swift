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
    
    typealias DONE = ()->Void
    
    @IBOutlet weak var segmentController: UISegmentedControl!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var mainButton: UIButton!
    @IBOutlet var segmentConstraint: NSLayoutConstraint!
    @IBOutlet var segmentHeight: NSLayoutConstraint!
    @IBOutlet weak var registerBtn: UIButton!
    
    var userInfoName = String()
    var userInfoID = String()
    var userNextID = Int()
    
    let publicData = CKContainer.default().publicCloudDatabase
    var users = [CKRecord]()

    var username = String()
    var password = String()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        iCloudUserInfo { (recordID: CKRecordID?, error: NSError?) in
            if (recordID?.recordName) != nil {
                // getting current user info
            } else {
                self.alertSignIn()
                DispatchQueue.main.async {
                    self.mainButton.setTitle("Sign in your Apple ID to continue", for: .normal)
                }
            }
        }
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
            mainButton.setTitle("Enter As Student", for: .normal)
            segmentHeight.isActive = false
            segmentConstraint.isActive = true
            registerBtn.isHidden = true
            nameField.isHidden = true
            passwordField.isHidden = true
        } else if segmentController.selectedSegmentIndex == 1 {
            mainButton.setTitle("Login As Tutor", for: .normal)
            segmentConstraint.isActive = false
            segmentHeight.isActive = true
            registerBtn.isHidden = false
            nameField.isHidden = false
            passwordField.isHidden = false
            nameField.text = ""
            passwordField.text = ""
        }
    }

    @IBAction func buttonClicked(_ sender: Any) {
        username = nameField.text!.lowercased().trimmingCharacters(in: .whitespaces)
        password = passwordField.text!
        
        if nameField.text == "" && passwordField.text == "" {
            shake(textField: nameField)
            shake(textField: passwordField)
        } else if passwordField.text == "" {
            shake(textField: passwordField)
        } else if nameField.text == "" {
            shake(textField: nameField)
        }
        
        if segmentController.selectedSegmentIndex == 0 {
            enterAsStudent()
        } else if segmentController.selectedSegmentIndex == 1 {
            authenticateUser()
        }
    }
    
    func getLastId( done : @escaping DONE ) {
        let query = CKQuery(recordType: "Account", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let accounts = results {
                let lastID = accounts.last?.object(forKey: "ID") as! Int
                self.userNextID = lastID + 1
                DispatchQueue.main.async {
                    done()
                }
            }
        }
    }
    
    @IBAction func register(_ sender: Any) {
        getLastId() {
            self.registerUser()
        }
    }
    
    func alertSignIn() {
        let signInAlert = UIAlertController(title: "Please sign in to your iPhone", message: "This can be done through your settings using your Apple ID", preferredStyle: .alert)
        signInAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(signInAlert, animated: true, completion: nil)
    }
    
    func encryptPassword(myPassword: String) -> String {
        let key = "mysuperawesome32characterkeyring"
        
        let encrypted = AES256CBC.encryptString(myPassword, password: key)
        
        return encrypted!
    }
    
    func decryptPassword(myPassword: String) -> String {
        let key = "mysuperawesome32characterkeyring"
    
        let decrypted = AES256CBC.decryptString(myPassword, password: key)
    
        return decrypted!
    }
    
    func shake(textField: UITextField) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.duration = 0.5
        animation.values = [-20.0, 20.0, -15.0, 15.0, -10.0, 10.0, -5.0, 5.0, 0.0 ]
        textField.layer.add(animation, forKey: "shake")
    }
    
    func shakeScreen() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.duration = 0.5
        animation.values = [-20.0, 20.0, -15.0, 15.0, -10.0, 10.0, -5.0, 5.0, 0.0 ]
        view.layer.add(animation, forKey: "shake")
    }
    
    func registerUser() {
        let registerAlert = UIAlertController(title: "Create A New Account", message: "Enter Account Details", preferredStyle: .alert)
        registerAlert.addTextField { (usernameField: UITextField) in
            usernameField.placeholder = "Username"
        }
        registerAlert.addTextField { (userPasswordField: UITextField) in
            userPasswordField.placeholder = "Password"
            userPasswordField.isSecureTextEntry = true
        }
        registerAlert.addTextField { (passwordCheckField: UITextField) in
            passwordCheckField.placeholder = "Verify your Password"
            passwordCheckField.isSecureTextEntry = true
        }
        
        registerAlert.addAction(UIAlertAction(title: "Register", style: .default, handler: { (action: UIAlertAction) in
            let usernameField = registerAlert.textFields?[0]
            let userPasswordField = registerAlert.textFields?[1]
            let passwordCheckField = registerAlert.textFields?[2]
            
            if usernameField?.text != "" || userPasswordField?.text != "" {
                if userPasswordField?.text == passwordCheckField?.text {
                    let newUser = CKRecord(recordType: "Account")
                    newUser["ID"] = self.userNextID as CKRecordValue?
                    newUser["Username"] = usernameField?.text?.lowercased() as CKRecordValue?
                    newUser["Password"] = self.encryptPassword(myPassword: userPasswordField!.text!) as CKRecordValue?
                    
                    self.publicData.save(newUser, completionHandler: { (record:CKRecord?, error:Error?) in
                        if error == nil {
                            DispatchQueue.main.async(execute: { () -> Void in
                                self.resetView()
                            })
                        } else if let e = error {
                            print(e.localizedDescription)
                        }
                    })
                } else {
                    self.registerUser()
                    self.shakeScreen()
                }
            } else {
                self.registerUser()
                self.shakeScreen()
            }
        }))
        
        registerAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(registerAlert, animated: true, completion: nil)

    }
    
    func authenticateUser() {
        var authenticated = false
        let query = CKQuery(recordType: "Account", predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
        
        publicData.perform(query, inZoneWith: nil) { (results:[CKRecord]?, error:Error?) in
            if let users = results {
                for user in users {
                    let username = user.object(forKey: "Username") as! String
                    let password = user.object(forKey: "Password") as! String
                    if self.username == username && self.password == self.decryptPassword(myPassword: password) {
                        authenticated = true
                        DispatchQueue.main.async {
                            self.enterAsTutor()
                        }
                    }
                }
                if authenticated == false {
                    DispatchQueue.main.async {
                        self.shake(textField: self.passwordField)
                        self.passwordField.text = ""
                    }
                }
            }
        }
    }
    
    func enterAsStudent() {
        performSegue(withIdentifier: "studentSegue", sender: self)
    }
    
    func enterAsTutor() {
        performSegue(withIdentifier: "tutorSegue", sender: self)
        nameField.text = ""
        passwordField.text = ""
    }

    func iCloudUserInfo(complete: @escaping ( _ instance: CKRecordID?, _ error: NSError?) -> ()) {
        let container = CKContainer.default()
        container.fetchUserRecordID() {
            recordID, error in
            if error != nil {
                print(error!.localizedDescription)
                complete(nil, error as NSError?)
            } else {
                complete(recordID, nil)
                container.requestApplicationPermission(.userDiscoverability) { (status, permissionError) in
                    if status == CKApplicationPermissionStatus.granted {
                        container.discoverUserIdentity(withUserRecordID: recordID!, completionHandler: { (user, error) in
                            DispatchQueue.main.async(execute: { 
                                self.userInfoName = (user?.nameComponents?.givenName)! + " " + (user?.nameComponents?.familyName)!
                                self.userInfoID = (recordID?.recordName)!
                                self.mainButton.isEnabled = true
                                self.segmentController.isEnabled = true
                                self.mainButton.backgroundColor = UIColor(red: 52/255, green: 149/255, blue: 203/255, alpha: 1)
                                self.mainButton.setTitle("Enter As Student", for: .normal)
                            })
                        })
                    }
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "studentSegue" {
            if let destinationController = segue.destination as? StudentTableViewController {
                destinationController.username = userInfoName
                destinationController.userID = userInfoID
            }
        } else if segue.identifier == "tutorSegue" {
            if let destinationController = segue.destination as? TutorTableViewController {
                destinationController.username = username
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    func resetView() {
        segmentController.selectedSegmentIndex = 0
        mainButton.setTitle("Enter As Student", for: .normal)
        segmentHeight.isActive = false
        segmentConstraint.isActive = true
        registerBtn.isHidden = true
        nameField.isHidden = true
        passwordField.isHidden = true
    }
    
}
