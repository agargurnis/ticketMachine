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
    
//    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        
//        let deviceTokenString = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
//        print(deviceTokenString)
//        
//    }
    
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

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        resetBadge()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        DispatchQueue.main.async(execute: { () -> Void in
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "performReload"), object: nil)
        })
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

