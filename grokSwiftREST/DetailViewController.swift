//
//  DetailViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-04-02.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import UIKit
import SafariServices
import BRYXBanner

class DetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  @IBOutlet weak var tableView: UITableView!
  var isStarred: Bool?
  var alertController: UIAlertController?
  var notConnectedBanner: Banner?
  
  var gist: Gist? {
    didSet {
      // Update the view.
      self.configureView()
    }
  }
  
  func configureView() {
    fetchStarredStatus()
    if let detailsView = self.tableView {
      detailsView.reloadData()
    }
  }
  
  func fetchStarredStatus() {
    guard let gistId = gist?.id else {
      return
    }
    GitHubAPIManager.sharedInstance.isGistStarred(gistId) {
      result in
      guard result.error == nil else {
        print(result.error)
        if result.error?.domain != NSURLErrorDomain {return}
        
        if result.error?.code == NSURLErrorUserAuthenticationRequired {
          self.alertController = UIAlertController(title:
            "Could not get starred status", message: result.error?.description,
                                            preferredStyle: .Alert)
          // add ok button
          let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
          self.alertController?.addAction(okAction)
          self.presentViewController(self.alertController!, animated:true,
                                     completion: nil)
        } else if result.error?.code == NSURLErrorNotConnectedToInternet {
          self.showOrangeNotConnectedBanner("No Internet Connection",
                                            message: "Can not display starred status. " +
            "Try again when you're connected to the internet")
          
        }
        return
      }
      if let status = result.value where self.isStarred == nil { // just got it
        self.isStarred = status
        self.tableView?.insertRowsAtIndexPaths(
          [NSIndexPath(forRow: 2, inSection: 0)],
          withRowAnimation: .Automatic)
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.configureView()
  }
  
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 2
  }
  
  func tableView(tableView: UITableView,
                 numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      if let _ = isStarred {
        return 3
      }
      return 2
    } else {
      return gist?.files?.count ?? 0
    }
  }
  
  func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if section == 0 {
      return "About"
    } else {
      return "Files"
    }
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    
    switch (indexPath.section, indexPath.row, isStarred) {
      case (0, 0, _):
        cell.textLabel?.text = gist?.description
      case (0, 1, _):
        cell.textLabel?.text = gist?.ownerLogin
      case (0, 2, .None):
        cell.textLabel?.text = ""
      case (0, 2, .Some(true)):
        cell.textLabel?.text = "Unstar"
      case (0, 2, .Some(false)):
        cell.textLabel?.text = "Star"
      default: // section 1
        cell.textLabel?.text = gist?.files?[indexPath.row].filename
    }
    
    return cell
  }
  
  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    switch (indexPath.section, indexPath.row, isStarred){
      case (0, 2, .Some(true)):
        unstarThisGist()
      case (0, 2, .Some(false)):
        starThisGist()
      case (1, _, _):
        guard let file = gist?.files?[indexPath.row],
          urlString = file.raw_url,
          url = NSURL(string: urlString) else {
            return
        }
        let safariViewController = SFSafariViewController(URL: url)
        safariViewController.title = file.filename
        self.navigationController?.pushViewController(safariViewController, animated: true)
      default:
        print("No-op")
    }
  }
  
  func starThisGist() {
    guard let gistId = gist?.id else {
      return
    }
    GitHubAPIManager.sharedInstance.starGist(gistId) {
      (error) in
      guard error == nil else {
        print(error)
        if error?.domain == NSURLErrorDomain &&
          error?.code == NSURLErrorUserAuthenticationRequired {
          self.alertController = UIAlertController(title: "Could not star gist",
                                                   message: error?.description,
                                                   preferredStyle: .Alert)
        } else {
          self.alertController = UIAlertController(title: "Could not star gist",
                                                   message: "Sorry, your gist couldn't be starred. " +
            "Maybe GitHub is down or you don't have an internet connection.",
                                                   preferredStyle: .Alert)
        }
        // add ok button
        let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        self.alertController?.addAction(okAction)
        self.presentViewController(self.alertController!, animated:true, completion: nil)
        return
      }
      self.isStarred = true
      self.tableView.reloadRowsAtIndexPaths(
        [NSIndexPath(forRow: 2, inSection: 0)],
        withRowAnimation: .Automatic)
    }
  }
  
  func unstarThisGist() {
    guard let gistId = gist?.id else {
      return
    }
    GitHubAPIManager.sharedInstance.unstarGist(gistId) {
      (error) in
      guard error == nil else {
        print(error)
        if error?.domain == NSURLErrorDomain &&
          error?.code == NSURLErrorUserAuthenticationRequired {
          self.alertController = UIAlertController(title: "Could not unstar gist",
                                                   message: error?.description,
                                                   preferredStyle: .Alert)
        } else {
          self.alertController = UIAlertController(title: "Could not unstar gist",
                                                   message: "Sorry, your gist couldn't be unstarred. " +
            "Maybe GitHub is down or you don't have an internet connection.",
                                                   preferredStyle: .Alert)
        }
        // add ok button
        let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        self.alertController?.addAction(okAction)
        self.presentViewController(self.alertController!, animated:true, completion: nil)
        return
      }
      self.isStarred = false
      self.tableView.reloadRowsAtIndexPaths(
        [NSIndexPath(forRow: 2, inSection: 0)],
        withRowAnimation: .Automatic)
    }
  }
  
  func showOrangeNotConnectedBanner(title: String, message: String) {
    // show not connected error & tell em to try again when they do have a connection
    // check for existing banner
    if let existingBanner = self.notConnectedBanner {
      existingBanner.dismiss()
    }
    self.notConnectedBanner = Banner(title: title,
      subtitle: message,
      image: nil,
      backgroundColor: UIColor.orangeColor())
    self.notConnectedBanner?.dismissesOnSwipe = true
    self.notConnectedBanner?.show(duration: nil)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
}
