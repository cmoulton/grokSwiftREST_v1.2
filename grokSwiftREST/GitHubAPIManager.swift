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
import Locksmith

class GitHubAPIManager {
  static let sharedInstance = GitHubAPIManager()
  let clientID: String = "1234567890"
  let clientSecret: String = "abcdefghijkl"
  var isLoadingOAuthToken: Bool = false
  
  var OAuthToken: String? {
    set {
      guard let newValue = newValue else {
        let _ = try? Locksmith.deleteDataForUserAccount("github")
        return
      }
      
      guard let _ = try? Locksmith.updateData(["token": newValue], forUserAccount: "github") else {
        let _ = try? Locksmith.deleteDataForUserAccount("github")
        return
      }
    }
    get {
      // try to load from keychain
      Locksmith.loadDataForUserAccount("github")
      let dictionary = Locksmith.loadDataForUserAccount("github")
      return dictionary?["token"] as? String
    }
  }
  
  func clearCache() -> Void {
    let cache = NSURLCache.sharedURLCache()
    cache.removeAllCachedResponses()
  }
  
  func printPublicGists() -> Void {
    Alamofire.request(GistRouter.GetPublic())
      .responseString { response in
        if let receivedString = response.result.value {
          print(receivedString)
        }
    }
  }
  
  func hasOAuthToken() -> Bool {
    if let token = self.OAuthToken {
      return !token.isEmpty
    }
    return false
  }
  
  // MARK: - OAuth flow
  
  func URLToStartOAuth2Login() -> NSURL? {
    let authPath:String = "https://github.com/login/oauth/authorize" +
      "?client_id=\(clientID)&scope=gist&state=TEST_STATE"
    guard let authURL:NSURL = NSURL(string: authPath) else {
      // TODO: handle error
      return nil
    }
    
    return authURL
  }
  
  func extractCodeFromOAuthStep1Response(url: NSURL) -> String? {
    let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
    var code:String?
    guard let queryItems = components?.queryItems else {
      return nil
    }
    for queryItem in queryItems {
      if (queryItem.name.lowercaseString == "code") {
        code = queryItem.value
        break
      }
    }
    return code
  }
  
  func parseOAuthTokenResponse(json: JSON) -> String? {
    var token: String?
    for (key, value) in json {
      switch key {
      case "access_token":
        token = value.string
      case "scope":
        // TODO: verify scope
        print("SET SCOPE")
      case "token_type":
        // TODO: verify is bearer
        print("CHECK IF BEARER")
      default:
        print("got more than I expected from the OAuth token exchange")
        print(key)
      }
    }
    return token
  }
  
  func processOAuthStep1Response(url: NSURL) {
    // extract the code from the URL
    guard let code = extractCodeFromOAuthStep1Response(url) else {
      self.isLoadingOAuthToken = false
      return
    }
    
    // swap the code for an oauth token
    let getTokenPath:String = "https://github.com/login/oauth/access_token"
    let tokenParams = ["client_id": clientID,
                       "client_secret": clientSecret,
                       "code": code]
    let jsonHeader = ["Accept": "application/json"]
    Alamofire.request(.POST, getTokenPath, parameters: tokenParams,
      headers: jsonHeader)
      .responseString { response in
        // TODO: handle response to extract OAuth token
        guard response.result.error == nil else {
          print(response.result.error!)
          self.isLoadingOAuthToken = false
          return
        }
        guard let value = response.result.value else {
          print("no string received in response when swapping oauth code for token")
          self.isLoadingOAuthToken = false
          return
        }
        print(value)
        
        // extract the token from the response
        guard let receivedResults = response.result.value,
          jsonData = receivedResults.dataUsingEncoding(NSUTF8StringEncoding,
            allowLossyConversion: false) else {
            print("no data received or data not JSON")
            self.isLoadingOAuthToken = false
            return
        }
        let jsonResults = JSON(data: jsonData)
        self.OAuthToken = self.parseOAuthTokenResponse(jsonResults)
        self.isLoadingOAuthToken = false
        guard self.hasOAuthToken() else {
          self.isLoadingOAuthToken = false
          return
        }
        self.printMyStarredGistsWithOAuth2()
      }
  }
  
  // MARK: - OAuth 2.0
  func printMyStarredGistsWithOAuth2() -> Void {
    let alamofireRequest = Alamofire.request(GistRouter.GetMyStarred())
      .responseString { response in
        guard let receivedString = response.result.value else {
          print(response.result.error!)
          self.OAuthToken = nil
          return
        }
        print(receivedString)
    }
    debugPrint(alamofireRequest)
  }
  
  // MARK: API Calls
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
