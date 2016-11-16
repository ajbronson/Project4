//
//  ErrorHelper.swift
//  Founders Directory
//
//  Created by AJ Bronson on 11/15/16.
//  Copyright © 2016 Steve Liddle. All rights reserved.
//

import UIKit

struct ErrorHelper {
    
    static func showAlert(message: String, title: String, dismissTitle: String, view: UIViewController) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: dismissTitle, style: .default, handler: nil)
        alert.addAction(dismissButton)
        view.present(alert, animated: true, completion: nil)
        
    }
}
