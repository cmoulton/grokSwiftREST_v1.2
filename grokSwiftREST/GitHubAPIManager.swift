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
  
  func fetchGists(urlRequest: URLRequestConvertible, completionHandler:
    (Result<[Gist], NSError>, String?) -> Void) {
    Alamofire.request(urlRequest)
      .responseArray { (response:Response<[Gist], NSError>) in
        // need to figure out if this is the last page
        // check the link header, if present
        let next = self.parseNextPageFromHeaders(response.response)
        completionHandler(response.result, next)
    }
  }
  
  func fetchPublicGists(pageToLoad: String?, completionHandler:
    (Result<[Gist], NSError>, String?) -> Void) {
    if let urlString = pageToLoad {
      fetchGists(GistRouter.GetAtPath(urlString), completionHandler: completionHandler)
    } else {
      fetchGists(GistRouter.GetPublic(), completionHandler: completionHandler)
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
  
  // MARK: Pagination
  private func parseNextPageFromHeaders(response: NSHTTPURLResponse?) -> String? {
    guard let linkHeader = response?.allHeaderFields["Link"] as? String else {
      return nil
    }
    /* looks like:
     <https://api.github.com/user/20267/gists?page=2>; rel="next", <https://api.github.com/user/20267/gists?page=6>; rel="last"
     */
    // so split on ","
    let components = linkHeader.characters.split {$0 == ","}.map { String($0) }
    // now we have 2 lines like
    // '<https://api.github.com/user/20267/gists?page=2>; rel="next"'
    // So let's get the URL out of there:
    for item in components {
      // see if it's "next"
      let rangeOfNext = item.rangeOfString("rel=\"next\"", options: [])
      guard rangeOfNext != nil else {
        continue
      }
      // this is the "next" item
      // extract the URL
      let rangeOfPaddedURL = item.rangeOfString("<(.*)>;",
                                                options: .RegularExpressionSearch)
      guard let range = rangeOfPaddedURL else {
        return nil
      }
      let nextURL = item.substringWithRange(range)
      
      // strip off the < and >;
      let startIndex = nextURL.startIndex.advancedBy(1)
      let endIndex = nextURL.endIndex.advancedBy(-2)
      let urlRange = startIndex..<endIndex
      return nextURL.substringWithRange(urlRange)
    }
    return nil
  }
}
