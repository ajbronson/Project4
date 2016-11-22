//
//  HttpHelper.swift
//  Founders Directory
//
//  Created by Steve Liddle on 11/2/16.
//  Copyright © 2016 Steve Liddle. All rights reserved.
//

import UIKit

class HttpHelper : NSObject, URLSessionDelegate {
    
    // MARK: - Constants
    
    private struct Allowed {
        static let hostname = "scriptures.byu.edu"
    }
    
    private struct MultiPart {
        static let boundaryEnd = "\r\n--*****--\r\n"
        static let boundaryStart = "--*****\r\n"
        static let crLf = "\r\n"
        static let fieldFormat: NSString = "Content-Disposition: form-data; name=\"%@\"\r\n\r\n"
        static let fileFormat = "Content-Disposition: form-data; name=\"file\"; filename=\"founderphoto\"\r\n\r\n"
        static let methodPost = "POST"
    }
    
    // MARK: - Properties
    
    lazy var analyticsQueue = DispatchQueue.global(qos: .utility)
    var downloadTask: URLSessionDataTask!
    
    // MARK: - Singleton
    
    static let shared = HttpHelper()
    
    fileprivate override init() { }
    
    // MARK: - Public API
    
    // Note: The pattern throughout this module is (1) create semaphore, (2) fire off the HTTP
    //       request, (3) wait for signal from the semaphore, and (4) call the completion handler.
    //       In the background HTTP task, when it's done we signal the semaphore.  The reason for
    //       not letting everything run asynchronously is because the sync algorithm is order-
    //       dependent, and we need to be sure the previous step is done before moving on to the
    //       next one.  This semaphore pattern lets us perform these operations synchronously
    //       in a CPU-friendly way.  We get _signalled_ when we are okay to proceed.  We don't have
    //       to keep checking whether we're done yet.
    func getContent(urlString: String, completionHandler: (Data?) -> ()) {
        if let url = URL(string: urlString) {
            var resultData: Data?
            let semaphore = DispatchSemaphore(value: 0)
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration,
                                     delegate: self,
                                     delegateQueue: nil)
            
            session.dataTask(with: url) { (data, response, error) in
                if error == nil {
                    resultData = data
                }
                
                semaphore.signal()
                }.resume()
            
            semaphore.wait()
            completionHandler(resultData)
        }
    }
    
    func getContent(urlString: String, failureCode: String, completionHandler: (String) -> ()) {
        if let url = URL(string: urlString) {
            var content = ""
            let semaphore = DispatchSemaphore(value: 0)
            
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                if error != nil || data == nil {
                    content = failureCode
                }
                
                content = String(data: data!, encoding: String.Encoding.utf8) ?? failureCode
                semaphore.signal()
                }.resume()
            
            semaphore.wait()
            completionHandler(content)
        }
    }
    
    func getJsonContent(urlString: String, completionHandler: @escaping (JSONObject?) -> ()) {
        if let url = URL(string: urlString) {
            let session = URLSession(configuration: URLSessionConfiguration.default,
                                     delegate: self,
                                     delegateQueue: nil)
            
            session.dataTask(with: url) { (data, response, error) in
                if error == nil {
                    if let result = try? JSONSerialization.jsonObject(with: data!,
                                                                      options: .allowFragments) as! JSONObject {
                        completionHandler(result)
                        return
                    }
                }
                
                completionHandler(nil)
                }.resume()
        }
    }
    
    // Note: this is the one exception to the semaphore pattern described above -- this is just a
    //       "fire and forget" method
    func performGet(urlString: String) {
        // Put this into the background as soon as possible
        analyticsQueue.async {
            if let url = URL(string: urlString) {
                let session = URLSession(configuration: URLSessionConfiguration.default,
                                         delegate: self,
                                         delegateQueue: nil)
                session.dataTask(with: url).resume()
            }
        }
    }
    
    func postContent(urlString: String, completionHandler: (Data?) -> ()) {
        if let url = URL(string: urlString) {
            var resultData: Data?
            let semaphore = DispatchSemaphore(value: 0)
            
            URLSession.shared.dataTask(with: url) { (data, response, error) in
                if error == nil {
                    resultData = data
                }
                
                semaphore.signal()
                }.resume()
            
            semaphore.wait()
            completionHandler(resultData)
        }
    }
    
    func postMultipartContent(urlString: String,
                              parameters: [String : String],
                              image: UIImage,
                              completionHandler: (Data?) -> ()) {
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url,
                                     cachePolicy: .reloadIgnoringLocalCacheData,
                                     timeoutInterval: 10)
            let body = NSMutableString()
            
            for (key, value) in parameters {
                addFormField(payload: body, fieldName: key, value: value)
            }
            
            body.append(MultiPart.boundaryStart)
            body.append(MultiPart.fileFormat)
            
            let requestData = NSMutableData()
            
            requestData.append(body.data(using: String.Encoding.utf8.rawValue)!)
            requestData.append(UIImageJPEGRepresentation(image, 1.0)!)
            requestData.append(MultiPart.boundaryEnd.data(using: String.Encoding.utf8)!)
            
            request.httpBody = requestData as Data
            request.httpMethod = MultiPart.methodPost
            
            let semaphore = DispatchSemaphore(value: 0)
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration,
                                     delegate: self,
                                     delegateQueue: nil)
            var resultData: Data?
            
            session.dataTask(with: url) { (data, response, error) in
                if error == nil {
                    resultData = data
                }
                
                semaphore.signal()
                }.resume()
            
            semaphore.wait()
            completionHandler(resultData)
        }
    }
    
    // MARK: - Session delegate
    
    // The reason I implement the session delegate is because my SSL certificate is self-signed,
    // and I need to tell iOS to accept the certificate anyway.  In addition to specifically
    // trusting scriptures.byu.edu here, I also add the following to Info.plist:
    //
    //  <key>NSAppTransportSecurity</key>
    //  <dict>
    //      <key>NSExceptionDomains</key>
    //      <dict>
    //          <key>scriptures.byu.edu</key>
    //          <dict>
    //              <key>NSExceptionAllowsInsecureHTTPLoads</key>
    //              <true/>
    //          </dict>
    //      </dict>
    //  </dict>
    //
    // Before really making this a production app and sending it to my donors, I should get a real
    // SSL certificate.  (I wonder if Apple would reject the app because of this -- they might. ;-)
    //
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if challenge.protectionSpace.host == Allowed.hostname {
                let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
                
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, credential)
            }
        }
    }
    
    // MARK: - Private helpers
    
    private func addFormField(payload: NSMutableString, fieldName: String, value: String) {
        payload.append(MultiPart.boundaryStart)
        payload.appendFormat(MultiPart.fieldFormat, fieldName)
        payload.append(value + MultiPart.crLf)
    }
}
