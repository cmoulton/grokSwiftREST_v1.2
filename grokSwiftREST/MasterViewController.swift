//
//  MasterViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-04-02.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import UIKit
import PINRemoteImage

class MasterViewController: UITableViewController, LoginViewDelegate {

  var detailViewController: DetailViewController? = nil
  var gists = [Gist]()
  var nextPageURLString: String?
  var isLoading = false
  var dateFormatter = NSDateFormatter()

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = self.editButtonItem()

    let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(MasterViewController.insertNewObject(_:)))
    self.navigationItem.rightBarButtonItem = addButton
    if let split = self.splitViewController {
        let controllers = split.viewControllers
        self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
    }
  }

  override func viewWillAppear(animated: Bool) {
    self.clearsSelectionOnViewWillAppear = self.splitViewController!.collapsed
    
    // add refresh control for pull to refresh
    if (self.refreshControl == nil) {
      self.refreshControl = UIRefreshControl()
      self.refreshControl?.addTarget(self,
                                     action: #selector(refresh(_:)),
                                     forControlEvents: UIControlEvents.ValueChanged)
    }
    
    self.dateFormatter.dateStyle = .ShortStyle
    self.dateFormatter.timeStyle = .LongStyle
    
    super.viewWillAppear(animated)
  }
  
  func loadGists(urlToLoad: String?) {
    self.isLoading = true
    GitHubAPIManager.sharedInstance.fetchPublicGists(urlToLoad) { (result, nextPage) in
      self.isLoading = false
      self.nextPageURLString = nextPage
      
      // tell refresh control it can stop showing up now
      if self.refreshControl != nil && self.refreshControl!.refreshing {
        self.refreshControl?.endRefreshing()
      }
      
      guard result.error == nil else {
        self.handleLoadGistsError(result.error!)
        return
      }
      
      guard let fetchedGists = result.value else {
        print("no gists fetched")
        return
      }
      
      if urlToLoad == nil {
        // empty out the gists because we're not loading another page
        self.gists = []
      }
      
      self.gists += fetchedGists
      
      // update "last updated" title for refresh control
      let now = NSDate()
      let updateString = "Last Updated at " + self.dateFormatter.stringFromDate(now)
      self.refreshControl?.attributedTitle = NSAttributedString(string: updateString)

      self.tableView.reloadData()
    }
  }
  
  func handleLoadGistsError(error: NSError){
    // TODO: show error
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    
    loadInitialData()
  }
  
  func loadInitialData() {
    if (!GitHubAPIManager.sharedInstance.hasOAuthToken()) {
      showOAuthLoginView()
      return
    }
    GitHubAPIManager.sharedInstance.printMyStarredGistsWithOAuth2()
  }
  
  func showOAuthLoginView() {
    let storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle())
    guard let loginVC = storyboard.instantiateViewControllerWithIdentifier(
      "LoginViewController") as? LoginViewController else {
      assert(false, "Misnamed view controller")
      return
    }
    loginVC.delegate = self
    self.presentViewController(loginVC, animated: true, completion: nil)
  }
  
  func didTapLoginButton() {
    self.dismissViewControllerAnimated(false) {
      guard let authURL = GitHubAPIManager.sharedInstance.URLToStartOAuth2Login() else {
        return
      }
      // TODO: show web page
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  func insertNewObject(sender: AnyObject) {
    let alert = UIAlertController(title: "Not Implemented", message:
      "Can't create new gists yet, will implement later",
                                  preferredStyle: UIAlertControllerStyle.Alert)
    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,
      handler: nil))
    self.presentViewController(alert, animated: true, completion: nil)
  }

  // MARK: - Segues

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "showDetail" {
      if let indexPath = self.tableView.indexPathForSelectedRow {
        let gist = gists[indexPath.row] as Gist
        if let detailViewController = (segue.destinationViewController as!
          UINavigationController).topViewController as?
          DetailViewController {
          detailViewController.detailItem = gist
          detailViewController.navigationItem.leftBarButtonItem =
            self.splitViewController?.displayModeButtonItem()
          detailViewController.navigationItem.leftItemsSupplementBackButton = true
        }
      }
    }
  }

  // MARK: - Table View

  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return gists.count
  }

  override func tableView(tableView: UITableView, cellForRowAtIndexPath
    indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    
    let gist = gists[indexPath.row]
    cell.textLabel?.text = gist.description
    cell.detailTextLabel?.text = gist.ownerLogin
    
    // set cell.imageView to display image at gist.ownerAvatarURL
    if let urlString = gist.ownerAvatarURL, url = NSURL(string: urlString) {
      cell.imageView?.pin_setImageFromURL(url, placeholderImage:
        UIImage(named: "placeholder.png"))
    } else {
      cell.imageView?.image = UIImage(named: "placeholder.png")
    }
    
    // See if we need to load more gists
    if !isLoading {
      let rowsLoaded = gists.count
      let rowsRemaining = rowsLoaded - indexPath.row
      let rowsToLoadFromBottom = 5
    
      if rowsRemaining <= rowsToLoadFromBottom {
        if let nextPage = nextPageURLString {
          self.loadGists(nextPage)
        }
      }
    }
    
    return cell
  }

  override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath:
    NSIndexPath) -> Bool {
    // Return false if you do not want the specified item to be editable.
    return false
  }
  
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle:
    UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
      gists.removeAtIndex(indexPath.row)
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
    } else if editingStyle == .Insert {
      // Create a new instance of the appropriate class, insert it into the array,
      // and add a new row to the table view.
    }
  }
  
  // MARK: - Pull to Refresh
  func refresh(sender:AnyObject) {
    nextPageURLString = nil // so it doesn't try to append the results
    GitHubAPIManager.sharedInstance.clearCache()
    loadGists(nil)
  }
}
