//
//  JSONRequestHelper.swift
//  TrackMeTraveling
//
//  Created by Anders Fischer-Nielsen on 02/11/2017.
//  Copyright © 2017 Anders Fischer-Nielsen. All rights reserved.
//

import Foundation

class JSONRequestHelper {
    static func POSTRequestTo(url: String, withData json: [String: String?]?,
                       successCallBack: @escaping ((Data?, URLResponse?)->Void),
                       errorCallback: @escaping (()->Void),
                       unauthorizedCallback: @escaping (()->Void)) {
        let url = URL(string: url)!
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        
        do { request.httpBody = try JSONSerialization.data(withJSONObject: json!, options: .prettyPrinted) }
        catch let error {
            print(error.localizedDescription)
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let _ = data, error == nil else {
                print("[Unexpected error on POST] \(String(describing: error))")
                errorCallback()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if (httpResponse.statusCode == 401) {
                    unauthorizedCallback()
                }
                else if httpResponse.statusCode == 200 {
                    successCallBack(data, response)
                }
                else {
                    errorCallback();
                }
                return
            }
        }
        task.resume()
    }
}
