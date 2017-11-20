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
import CoreData
import NotificationCenter
import AVFoundation
import AVKit
import QuartzCore

// Keychain Configuration
struct KeychainConfiguration {
    static let serviceName = "TrackMeTraveling"
    static let accessGroup: String? = nil
}

class LoginViewController: UIViewController {
    //TODO: Move to globl constants class/struct.
    let loggedInIdentifier = "user_logged_in"
    let usernameIdentifier = "user_username"
    let accessTokenIdentifier = "user_access_token"
    let refreshTokenIdentifier = "user_refresh_token"
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var signInOrUpButton: UIButton!
    @IBOutlet weak var signInStateText: UIButton!
    
    //TODO: Use ressources.
    let signUpText = "Don't have an account? Sign up.";
    let signInText = "Already have an account? Sign in."
    
    var videoLooper: AVPlayerLooper!;
    var signInState = true;
    
    @IBAction func signInOrUp(_ sender: UIButton) {
        signInState = !signInState;
        updateViewsFromSignInState();
    }
    
    @IBAction func loginAction(_ sender: AnyObject) {
        login(email: emailField?.text, username: usernameField?.text, password: passwordField?.text);
    }
    
    func login(email: String?, username: String?, password: String?) {
        if (email == nil || username == nil || password == nil) { return }
        let parameters = ["username": username, "password": password];
        JSONRequestHelper.POSTRequestTo(url: "/auth", withData: parameters, successCallBack: handleResponse, errorCallback: handleFailureResponse, unauthorizedCallback: {})
    }
    
    func handleResponse(data: Data?, response: URLResponse?) {
        if let json = data {
            do {
                let deserialized = try JSONSerialization.jsonObject(with: json, options: []) as? [String: String]
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "loginSuccessful"), object: self)
                self.loggedIn(success: true, accessToken: deserialized?["access_token"], refreshToken: deserialized?["refresh_token"])
            } catch { self.loggedIn(success: false, accessToken: nil, refreshToken: nil) }
        }
    }
    
    func handleFailureResponse() {
        self.loggedIn(success: false, accessToken: nil, refreshToken: nil)
    }
    
    func loggedIn(success: Bool, accessToken: String?, refreshToken: String?) {
        if !success { return }
        
        DispatchQueue.main.async() {
            if let username = self.usernameField.text, let password = self.passwordField.text {
                if username.isEmpty || password.isEmpty {
                    let alertView = UIAlertController(title: "Coul not log in",
                                                      message: "Wrong username or password.",
                                                      preferredStyle:. alert)
                    let okAction = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
                    alertView.addAction(okAction)
                    self.present(alertView, animated: true, completion: nil)
                    return
                }
            }

            UserDefaults.standard.setValue(self.usernameField.text, forKey: self.usernameIdentifier)
            UserDefaults.standard.setValue(accessToken, forKey: self.accessTokenIdentifier)
            UserDefaults.standard.setValue(refreshToken, forKey: self.refreshTokenIdentifier)
            self.performSegue(withIdentifier: "dismissLogin", sender: self)
        }
    }
    
    func updateViewsFromSignInState() {
        if (!signInState) {
            UIView.animate(withDuration: 0.2, animations: {
                self.emailField.alpha = 1;
            }, completion: { (value: Bool) in self.emailField.isHidden = false });
            signInOrUpButton.setTitle("Sign up", for: .normal);
            signInStateText.setTitle(signInText, for: .normal);
        }
        else {
            UIView.animate(withDuration: 0.2, animations: {
                self.emailField.alpha = 0;
            }, completion: { (value: Bool) in self.emailField.isHidden = true });
            signInOrUpButton.setTitle("Sign in", for: .normal);
            signInStateText.setTitle(signUpText, for: .normal);
        }
    }
    
    

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad();
        //Setup video player:
        let filepath = Bundle.main.path(forResource: "crop.mp4", ofType: nil, inDirectory: nil);
        let fileURL = NSURL.fileURL(withPath:filepath!);
        let playerItem = AVPlayerItem.init(url: fileURL);
        let avPlayer = AVQueuePlayer.init();
        avPlayer.actionAtItemEnd = AVPlayerActionAtItemEnd.none;
        let videoLayer = AVPlayerLayer.init(player: avPlayer);
        videoLayer.frame = self.view.bounds;
        videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill;
        self.view.layer.insertSublayer(videoLayer, at: 0);
        videoLooper = AVPlayerLooper(player: avPlayer, templateItem: playerItem);
        avPlayer.play();
        
        //Set appearance:
        self.setNeedsStatusBarAppearanceUpdate();
        if (signInState) { emailField.isHidden = true; }
        
        //Setup textfields:
        func setTextField(field: UITextField) {
            let color = UIColor(red: 1, green: 1, blue: 1, alpha: 0.7);
            field.backgroundColor = UIColor.clear;
            field.layer.borderColor = color.cgColor;
            field.layer.borderWidth = 1;
            field.layer.cornerRadius = 4;
            field.attributedPlaceholder = NSAttributedString.init(string: field.placeholder!, attributes:[NSAttributedStringKey.foregroundColor: color]);
        }
        
        [usernameField, passwordField, emailField].forEach { field in setTextField(field: field)}
    }
}
