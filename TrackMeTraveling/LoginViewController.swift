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
        usernameField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        login(email: emailField?.text, username: usernameField?.text, password: passwordField?.text, finished: loggedIn);
    }
    
    func loggedIn(success: Bool, accessToken: String?) {
        if !success { return }
        
        if let username = usernameField.text, let password = passwordField.text {
            if username.isEmpty || password.isEmpty {
                let alertView = UIAlertController(title: "Coul not log in",
                                                  message: "Wrong username or password.",
                                                  preferredStyle:. alert)
                let okAction = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
                alertView.addAction(okAction)
                present(alertView, animated: true, completion: nil)
                return
            }
        }

        UserDefaults.standard.setValue(usernameField.text, forKey: usernameIdentifier)
        UserDefaults.standard.setValue(accessToken, forKey: accessTokenIdentifier)
        DispatchQueue.main.async() {
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
    
    func login(email: String?, username: String?, password: String?,
               finished: @escaping ((_: Bool, _: String?)->Void)) {
        if (email == nil || username == nil || password == nil) {
            return;
        }
        
        let url = URL(string: "http://127.0.0.1:5000/auth")!
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        let parameters = ["username": username, "password": password];
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch let error {
            print(error.localizedDescription)
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let _ = data, error == nil else {
                print("[Unexpected error on POST] \(String(describing: error))")
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("[Unexpected HTTP response] statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(String(describing: response))")
                return
            }
            
            if let json = data {
                do {
                    let deSerialized = try JSONSerialization.jsonObject(with: json, options: []) as? [String: String]
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "loginSuccessful"), object: self)
                    finished(true, deSerialized?["token"])
                } catch { finished(false, nil) }
            }
        }
        task.resume();
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad();
    }
    
    override func viewWillAppear(_ animated: Bool) {
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
        
        //Setup video player:
        let filepath = Bundle.main.path(forResource: "splash.mp4", ofType: nil, inDirectory: nil);
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
    }
}
