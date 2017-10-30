//
//  LoginViewController.swift
//  TrackMeTraveling
//
//  Created by Anders Fischer-Nielsen on 30/10/2017.
//  Copyright © 2017 Anders Fischer-Nielsen. All rights reserved.
//

import Foundation

import UIKit
import CoreLocation
import MapKit
import NotificationCenter

class LoginViewController: UIViewController {
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    @IBAction func login(_ sender: UIButton) {
        login(email: emailField?.text, username: usernameField?.text, password: passwordField?.text);
    }
    
    func login(email: String?, username: String?, password: String?) {
        if (email == nil || username == nil || password == nil) {
            return;
        }
        
        let loggedIn: Bool = true;
        //TODO: Implement login.
        if (loggedIn) {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "loginSuccessful"), object: self);
            self.dismiss(animated: true, completion: nil);
            let appDelegate = UIApplication.shared.delegate as! AppDelegate;
            appDelegate.showMainView(animated: true);
        }
    }
}
