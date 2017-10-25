//
//  ViewController.swift
//  TrackMeTraveling
//
//  Created by Anders Fischer-Nielsen on 23/10/2017.
//  Copyright © 2017 Anders Fischer-Nielsen. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit

class ViewController: UIViewController, CLLocationManagerDelegate {
    var locationManager: CLLocationManager!
    var lastUpdated: Date?
    let backgroundPreferenceIdentifier = "background_preference_enabled"
    var backgroundEnabled = false
    
    @IBOutlet weak var backgroundEnabledSwitch: UISwitch!
    @IBOutlet weak var lastUpdatedLabel: UILabel!
    @IBOutlet weak var forceUpdateButton: UIButton!
    @IBOutlet weak var locationView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //TODO: Implement proper resume after app is relaunched.
        locationManager = CLLocationManager()
        locationManager.delegate = self
    }

    //TODO: This is hacky, observer UIApplicationDidBecomeActiveNotification instead.
    //      NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    override func viewWillAppear(_ animated: Bool) {
        backgroundEnabled = UserDefaults.standard.bool(forKey: backgroundPreferenceIdentifier)
        startReceivingSignificantLocationChanges()
        styleMapView()
    }
    
    private func styleMapView() {
        locationView.transform = CGAffineTransform(rotationAngle: CGFloat(-3 * Double.pi/180));
        locationView.layer.borderColor = UIColor.lightText.cgColor
        locationView.layer.borderWidth = 10.0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        backgroundEnabledSwitch.isOn = backgroundEnabled
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func forceUpdate(_ sender: UIButton) {
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestLocation()
        locationManager.stopUpdatingLocation()
        startReceivingSignificantLocationChanges()
    }
    
    @IBAction func backgroundSwitchChanged(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: backgroundPreferenceIdentifier)
        backgroundEnabled = sender.isOn
        startReceivingSignificantLocationChanges()
    }
    
    func startReceivingSignificantLocationChanges() {
        if !backgroundEnabled {
            locationManager.stopUpdatingLocation()
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
        let parameters = ["latitude": location.latitude, "longitude": location.longitude]
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
            UIView.animate(withDuration: 2, animations: { label.alpha = 0 }, completion: nil)
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
