//
//  AppDelegate.swift
//  Founders Directory
//
//  Created by Steve Liddle on 9/21/16.
//  Copyright © 2016 Steve Liddle. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        DispatchQueue.global().async {
            // NEEDSWORK: Replace this code
            UserDefaults.standard.set("41471165af5bb678bf58467811505450",
                                      forKey: SyncHelper.Constants.sessionTokenKey)
            UserDefaults.standard.synchronize()
            // NEEDSWORK: log in; don't hard-code the session ID

            _ = SyncHelper.shared.synchronizeFounders()
        }

        return true
    }
}
