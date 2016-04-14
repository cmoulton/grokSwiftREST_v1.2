//
//  GitHubAPIManager.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-04-02.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

class GitHubAPIManager {
  static let sharedInstance = GitHubAPIManager()
  
  func printPublicGists() -> Void {
    Alamofire.request(GistRouter.GetPublic())
      .responseString { response in
        if let receivedString = response.result.value {
          print(receivedString)
        }
    }
  }
  
  func fetchPublicGists(completionHandler: (Result<[Gist], NSError>) -> Void) {
    Alamofire.request(GistRouter.GetPublic())
      .responseArray { (response:Response<[Gist], NSError>) in
        completionHandler(response.result)
    }
  }
  
  func imageFromURLString(imageURLString: String, completionHandler:
    (UIImage?, NSError?) -> Void) {
    Alamofire.request(.GET, imageURLString)
      .response { (request, response, data, error) in
        // use the generic response serializer that returns NSData
        guard let data = data else {
          completionHandler(nil, nil)
          return
        }
        
        let image = UIImage(data: data as NSData)
        completionHandler(image, nil)
    }
  }
}
