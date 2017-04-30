//
//  AppDelegate.swift
//  TicketMachine
//
//  Created by Arvids Gargurnis on 10/03/2017.
//  Copyright © 2017 Arvids Gargurnis. All rights reserved.
//

import UIKit
import UserNotifications
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        if #available(iOS 10, *) {
            
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                
                guard error == nil else {
                    print(error.debugDescription)
                    return
                }
                
                if granted {
                    application.registerForRemoteNotifications()
                } else {
                    // do nothing
                }
            }
            application.registerForRemoteNotifications()
        } else {
            let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        let cloudKitNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String:NSObject])
        
        if cloudKitNotification.notificationType == CKNotificationType.query {
            DispatchQueue.main.async(execute: { () -> Void in
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "performReload"), object: nil)
            })
        }
    }
    
    func resetBadge() {
        let badgeReset = CKModifyBadgeOperation(badgeValue: 0)
        badgeReset.modifyBadgeCompletionBlock = { (error) -> Void in
            if error == nil {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
        CKContainer.default().add(badgeReset)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        resetBadge()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        DispatchQueue.main.async(execute: { () -> Void in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "performReload"), object: nil)
        })
    }

}

