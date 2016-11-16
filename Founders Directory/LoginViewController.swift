//
//  LoginViewController.swift
//  Founders Directory
//
//  Created by AJ Bronson on 11/14/16.
//  Copyright © 2016 Steve Liddle. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {
    
    //MARK: - Properties
    
    private struct URLHelper {
        static let userPrefix = "login.php?u="
        static let passwordPrefix = "&p="
        static let devicePrefix = "&d="
    }
    
    //MARK: - Outlets
    
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    //MARK: - View Controller Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loginButton.layer.cornerRadius = 5
    }
    
    //MARK: - Actions
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        //TODO: Implement login functionality
        guard let userName = userNameTextField.text,
            let password = passwordTextField.text,
            let deviceID = UIDevice.current.identifierForVendor?.uuidString,
            userName.characters.count > 0,
            password.characters.count > 0 else { ErrorHelper.showAlert(message: "Please enter a username and a password.", title: "Error", dismissTitle: "OK", view: self); return }
        HttpHelper.shared.getContent(urlString: "\(SyncHelper.Constants.baseSyncUrl)\(URLHelper.userPrefix)\(userName)\(URLHelper.passwordPrefix)\(password)\(URLHelper.devicePrefix)\(deviceID)") {(data) in
            if let data = data {
                guard let rawJSON = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                    let json = rawJSON as? [String:AnyObject],
                    let userID = json["userId"],
                    let session = json["sessionId"] as? String else { ErrorHelper.showAlert(message: "Unable to sign in with these credentials. Please try again.", title: "Error", dismissTitle: "OK", view: self); return }
                UserDefaults.standard.set(session,
                                          forKey: SyncHelper.Constants.sessionTokenKey)
                UserDefaults.standard.set(userID,
                                          forKey: SyncHelper.Constants.userIDKey)
                UserDefaults.standard.synchronize()
                _ = SyncHelper.shared.synchronizeFounders()
                dismiss(animated: true, completion: nil)
            }
        }
    }
}
