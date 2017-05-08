//
//  SessionStatisticViewController.swift
//  TicketMachine
//
//  Created by Arvids Gargurnis on 07/05/2017.
//  Copyright © 2017 Arvids Gargurnis. All rights reserved.
//

import UIKit
import CloudKit

class SessionStatisticViewController: UITableViewController {
    
    let publicData = CKContainer.default().publicCloudDatabase
    var sessionID = String()
    var sessionRecordName = String()
    var sessionName = String()
    
    var noParticipants = Int()
    var noTutors = Int()
    var noResponses = Int()
    var noHelpRequests = Int()
    var noWithdraws = Int()
    var waitTimes = [String]()
    var responseTimes = [String]()
    
    var refresh: UIRefreshControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = sessionName
        
        loadData()
        
        refresh = UIRefreshControl()
        refresh.attributedTitle = NSAttributedString(string: "Pull to load sessions")
        refresh.addTarget(self, action: #selector(SessionStatisticViewController.loadData), for: .valueChanged)
        self.tableView.addSubview(refresh)
        
        DispatchQueue.main.async { () -> Void in
            NotificationCenter.default.addObserver(self, selector: #selector(SessionStatisticViewController.loadData), name: NSNotification.Name(rawValue: "performReload"), object: nil)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func loadData() {
        let recordID = CKRecordID(recordName: sessionRecordName)
        
        publicData.fetch(withRecordID: recordID, completionHandler: { (record:CKRecord?, error:Error?) in
            if error == nil {
                
                if record?.object(forKey: "NoHelpRequests") as? Int == nil {
                    self.noHelpRequests = 0
                } else {
                    self.noHelpRequests = record?.object(forKey: "NoHelpRequests") as! Int
                }
                
                if record?.object(forKey: "NoWithdraws") as? Int == nil {
                    self.noWithdraws = 0
                } else {
                    self.noWithdraws = record?.object(forKey: "NoWithdraws") as! Int
                }
                
                if record?.object(forKey: "NoResponses") as? Int == nil {
                    self.noResponses = 0
                } else {
                    self.noResponses = record?.object(forKey: "NoResponses") as! Int
                }
                
                if record?.object(forKey: "NoParticipants") as? Int == nil {
                    self.noParticipants = 0
                } else {
                    self.noParticipants = record?.object(forKey: "NoParticipants") as! Int
                }
                
                if record?.object(forKey: "NoTutors") as? Int == nil {
                    self.noTutors = 0
                } else {
                    self.noTutors = record?.object(forKey: "NoTutors") as! Int
                }
                
                if record?.object(forKey: "WaitArray") as? [String] == nil {
                    self.waitTimes = ["There are no time entries in this section"]
                } else {
                    self.waitTimes = record?.object(forKey: "WaitArray") as! [String]
                }
                
                if record?.object(forKey: "ResponseArray") as? [String] == nil {
                    self.responseTimes = ["There are no time entries in this section"]
                } else {
                    self.responseTimes = record?.object(forKey: "ResponseArray") as! [String]
                }
                
                DispatchQueue.main.async(execute: { () -> Void in
                    self.tableView.reloadData()
                    self.refresh.endRefreshing()
                    self.view.layoutSubviews()
                })
                
            } else if let e = error {
                print(e.localizedDescription)
            }
        })

    }
    
    @IBAction func goBack(_ sender: Any) {
        self.navigationController?.popToViewController((navigationController?.viewControllers[1])!, animated: true)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 7
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else if section == 1 {
            return 1
        } else if section == 2 {
            return 1
        } else if section == 3 {
            return 1
        } else if section == 4 {
            return 1
        } else if section == 5 {
            return waitTimes.count
        } else {
            return responseTimes.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Number of tutors"
        } else if section == 1 {
            return "Number of participants"
        } else if section == 2 {
            return "Number of help requests"
        } else if section == 3 {
            return "Number of responses"
        } else if section == 4 {
            return "Number of withdraws"
        } else if section == 5 {
            return "Time the participant had to wait"
        } else {
            return "Time the tutor took whilst responding"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "statCell", for: indexPath)
        
        if indexPath.section == 0 {
            if noTutors == 1 {
                cell.textLabel?.text = "There was " + String(noTutors) + " tutor in this session"
            } else {
                cell.textLabel?.text = "There was " + String(noTutors) + " tutors in this session"
            }
            return cell
            
        } else if indexPath.section == 1 {
            if noParticipants == 1 {
                cell.textLabel?.text = "There was " + String(noParticipants) + " participant in this session"
            } else {
                cell.textLabel?.text = "There was " + String(noParticipants) + " participants in this session"
            }
            
            return cell
            
        } else if indexPath.section == 2 {
            if noHelpRequests == 1 {
                cell.textLabel?.text = String(noHelpRequests) + " time help was requested in this session"
            } else {
                cell.textLabel?.text = String(noHelpRequests) + " times help was requested in this session"
            }
            
            return cell
            
        } else if indexPath.section == 3 {
            if noResponses == 1 {
                cell.textLabel?.text = String(noResponses) + " help request got successfully answered"
            } else {
                cell.textLabel?.text = String(noResponses) + " help requests got successfully answered"
            }
            
            return cell
            
        } else if indexPath.section == 4 {
            if noWithdraws == 1 {
                cell.textLabel?.text = String(noWithdraws) + " help request got withdrawn"
            } else {
                cell.textLabel?.text = String(noWithdraws) + " help requests got withdrawn"
            }
            
            return cell
            
        } else if indexPath.section == 5 {
            cell.textLabel?.text = waitTimes[indexPath.row]
            
            return cell

        } else {
            cell.textLabel?.text = responseTimes[indexPath.row]
            
            return cell
        }
    }

}
