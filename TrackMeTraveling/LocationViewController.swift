//
//  ViewController.swift
//  TrackMeTraveling
//
//  Created by Anders Fischer-Nielsen on 23/10/2017.
//  Copyright © 2017 Anders Fischer-Nielsen. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData
import MapKit

class LocationViewController: UIViewController, CLLocationManagerDelegate {
    var locationManager: CLLocationManager!
    var lastUpdated: Date?
    var backgroundEnabled = false
    let backgroundPreferenceIdentifier = "background_preference_enabled"
    let usernameIdentifier = "user_username"
    let accessTokenIdentifier = "user_access_token"
    let refreshTokenIdentifier = "user_refresh_token"
    var isAuthenticated = false
    var managedObjectContext: NSManagedObjectContext!
    
    @IBOutlet weak var backgroundEnabledSwitch: UISwitch!
    @IBOutlet weak var lastUpdatedLabel: UILabel!
    @IBOutlet weak var forceUpdateButton: UIButton!
    @IBOutlet weak var locationView: MKMapView!
    @IBOutlet weak var usernameLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.alpha = 0;
        //TODO: Implement proper resume after app is relaunched.
        locationManager = CLLocationManager()
        locationManager.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        styleMapView()
        //TODO: Use constant:
        if let username = UserDefaults.standard.object(forKey: usernameIdentifier) as? String {
            usernameLabel.text! += username
        }
    }

    @objc func didBecomeActive(_ notification: NSNotification) {
        backgroundEnabledSwitch.setOn(UserDefaults.standard.bool(forKey: backgroundPreferenceIdentifier), animated: true)
        setupReceivingOfSignificationLocationChanges()
    }
    
    private func styleMapView() {
        locationView.transform = CGAffineTransform(rotationAngle: CGFloat(-3 * Double.pi/180));
        locationView.layer.borderColor = UIColor.lightText.cgColor
        locationView.layer.borderWidth = 10.0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        showLoginView();
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func forceUpdate(_ sender: UIButton) {
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            locationManager.requestAlwaysAuthorization()
        }
        
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestLocation()
        locationManager.stopUpdatingLocation()
        setupReceivingOfSignificationLocationChanges()
    }
    
    @IBAction func backgroundSwitchChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: backgroundPreferenceIdentifier)
        setupReceivingOfSignificationLocationChanges()
    }
    
    @IBAction func unwindSegue(_ segue: UIStoryboardSegue) {
        isAuthenticated = true
        self.view.alpha = 1.0
    }
    
    @IBAction func logoutAction(_ sender: AnyObject) {
        isAuthenticated = false
        performSegue(withIdentifier: "loginView", sender: self)
    }
    
    func setupReceivingOfSignificationLocationChanges() {
        if !(UserDefaults.standard.bool(forKey: backgroundPreferenceIdentifier))
                || UserDefaults.standard.object(forKey: usernameIdentifier) == nil {
            locationManager.stopMonitoringSignificantLocationChanges()
            return
        }
        
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.activityType = .other
        locationManager.allowsBackgroundLocationUpdates = true
        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            locationManager.requestAlwaysAuthorization()
        }
        else if !CLLocationManager.significantLocationChangeMonitoringAvailable() {
            forceUpdateButton.isUserInteractionEnabled = false
        }
        else {
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !(UserDefaults.standard.bool(forKey: self.backgroundPreferenceIdentifier)) {
            setupReceivingOfSignificationLocationChanges()
            return;
        }
        
        let lastLocation = locations.last?.coordinate
        if lastLocation != nil {
            pushUpdatesToServer(location: lastLocation!)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Location error] Couldn't get location: \(String(describing: error))")
    }
    
    private func pushUpdatesToServer(location: CLLocationCoordinate2D) {
        let url = "/coordinates"
        let access_token = UserDefaults.standard.object(forKey: "user_access_token") as! String;
        
        self.setBeginUpdateOnLabel(label: self.lastUpdatedLabel)
        let body = ["username": "fischer",
                    "latitude": "\(location.latitude)",
                    "longitude": "\(location.longitude)",
                    "access_token": access_token]
        
        func handleSuccessResponse(data: Data?, response: URLResponse?) {
            self.lastUpdated = Date()
            DispatchQueue.global().async() {
                self.setMapViewLocation(location: location)
                DispatchQueue.main.async() {
                    self.updateLastUpdated(location: location)
                }
            }
        }
        
        func handleUnauthorizedResponse() {
            self.callRefreshToken(location: location)
        }
        
        JSONRequestHelper.POSTRequestTo(url: url, withData: body, successCallBack: handleSuccessResponse, errorCallback: handleErrorResponse, unauthorizedCallback: handleUnauthorizedResponse)
    }

    func handleErrorResponse() {
        self.setUpdateFailedOnLabel(label: self.lastUpdatedLabel, wasUnauthorized: false)
    }
    
    func callRefreshToken(location: CLLocationCoordinate2D) {
        let url = "/refreshtoken"
        
        func receiveAccessToken (data: Data?, response: URLResponse?) {
            if let json = data {
                do {
                    let deserialized = try JSONSerialization.jsonObject(with: json, options: []) as? [String: String]
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "loginSuccessful"), object: self)
                    let accessToken = deserialized?["access_token"]
                    let refreshToken = deserialized?["refresh_token"]
                    UserDefaults.standard.set(accessToken, forKey: accessTokenIdentifier)
                    UserDefaults.standard.set(refreshToken, forKey: refreshTokenIdentifier)
                    
                    pushUpdatesToServer(location: location)
                } catch {
                    self.setUpdateFailedOnLabel(label: self.lastUpdatedLabel, wasUnauthorized: true)
                }
            }
        }
        
        func error() {
            self.setUpdateFailedOnLabel(label: self.lastUpdatedLabel, wasUnauthorized: true)
        }
        
        func unauthorized() {
            isAuthenticated = false
            showLoginView()
        }
        
        let refresh = UserDefaults.standard.object(forKey: refreshTokenIdentifier) as! String
        let access = UserDefaults.standard.object(forKey: accessTokenIdentifier) as! String
        let data = ["refresh_token": refresh, "access_token": access,]
        
        JSONRequestHelper.POSTRequestTo(url: url, withData: data, successCallBack: receiveAccessToken(data:response:), errorCallback: error, unauthorizedCallback: unauthorized)
    }
    
    func showLoginView() {
        if !isAuthenticated {
            performSegue(withIdentifier: "loginView", sender: self)
        }
    }
    
    private func updateLastUpdated(location: CLLocationCoordinate2D) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let s = formatter.string(from: self.lastUpdated!)
        self.lastUpdatedLabel.text = "Last updated: " + s
    }
    
    private func setBeginUpdateOnLabel(label: UILabel) {
        DispatchQueue.main.async() {
            label.text = "Updating..."
            UIView.animate(withDuration: 0, animations: { label.alpha = 1 }, completion: nil)
        }
    }
    
    private func setUpdateFailedOnLabel(label: UILabel, wasUnauthorized: Bool) {
        DispatchQueue.main.async() {
            label.text = wasUnauthorized ? "Unauthorized" : "Update failed."
            UIView.animate(withDuration: 4, animations: { label.alpha = 0 }, completion: nil)
        }
    }
    
    private func setMapViewLocation(location: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(center: location, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        locationView.setRegion(region, animated: true)
        locationView.removeAnnotations(locationView.annotations)
        locationView.addAnnotation(LocationPin(coordinate: location))
    }
}

class LocationPin : NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}
