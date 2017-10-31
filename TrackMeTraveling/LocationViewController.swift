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
    let keychain = KeychainWrapper()
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
        if !(UserDefaults.standard.bool(forKey: backgroundPreferenceIdentifier)) {
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
        let url = URL(string: "http://127.0.0.1:5000/coordinates")!
        
        self.setBeginUpdateOnLabel(label: self.lastUpdatedLabel)
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        let parameters = ["username": "fischer", "latitude": "\(location.latitude)", "longitude": "\(location.longitude)"]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
        } catch let error {
            print(error.localizedDescription)
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let _ = data, error == nil else {
                print("[Unexpected error on POST] \(String(describing: error))")
                self.setUpdateFailedOnLabel(label: self.lastUpdatedLabel)
                return
            }
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                print("[Unexpected HTTP response] statusCode should be 200, but is \(httpStatus.statusCode)")
                print("response = \(String(describing: response))")
                self.setUpdateFailedOnLabel(label: self.lastUpdatedLabel)
                return
            }
            self.lastUpdated = Date()
            DispatchQueue.global().async() {
                self.setMapViewLocation(location: location)
                DispatchQueue.main.async() {
                    self.updateLastUpdated(location: location)
                }
            }
        }
        task.resume()
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
    
    private func setUpdateFailedOnLabel(label: UILabel) {
        DispatchQueue.main.async() {
            label.text = "Update failed."
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
