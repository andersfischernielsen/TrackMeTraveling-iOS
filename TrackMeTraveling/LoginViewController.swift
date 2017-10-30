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
import AVFoundation
import AVKit
import QuartzCore


class LoginViewController: UIViewController {
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
    
    @IBAction func login(_ sender: UIButton) {
        login(email: emailField?.text, username: usernameField?.text, password: passwordField?.text);
    }
    
    @IBAction func signInOrUp(_ sender: UIButton) {
        signInState = !signInState;
        updateViewsFromSignInState();
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
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad();
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
