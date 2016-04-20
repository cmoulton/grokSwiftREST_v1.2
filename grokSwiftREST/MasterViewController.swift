//
//  MasterViewController.swift
//  grokSwiftREST
//
//  Created by Christina Moulton on 2016-04-02.
//  Copyright © 2016 Teak Mobile Inc. All rights reserved.
//

import UIKit
import PINRemoteImage
import SafariServices
import Alamofire
import BRYXBanner

class MasterViewController: UITableViewController,
  LoginViewDelegate,
  SFSafariViewControllerDelegate {
  @IBOutlet weak var gistSegmentedControl: UISegmentedControl!

  var notConnectedBanner: Banner?
  var detailViewController: DetailViewController? = nil
  var safariViewController: SFSafariViewController?

  var gists = [Gist]()
  var nextPageURLString: String?
  var isLoading = false
  var dateFormatter = NSDateFormatter()

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.

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
    GitHubAPIManager.sharedInstance.clearCache()
    self.isLoading = true
    let completionHandler: (Result<[Gist], NSError>, String?) -> Void = { (result, nextPage) in
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
    
    switch gistSegmentedControl.selectedSegmentIndex {
      case 0:
        GitHubAPIManager.sharedInstance.fetchPublicGists(urlToLoad, completionHandler:
          completionHandler)
      case 1:
        GitHubAPIManager.sharedInstance.fetchMyStarredGists(urlToLoad, completionHandler:
          completionHandler)
      case 2:
        GitHubAPIManager.sharedInstance.fetchMyGists(urlToLoad, completionHandler:
          completionHandler)
      default:
        print("got an index that I didn't expect for selectedSegmentIndex")
    }
  }
  
  func handleLoadGistsError(error: NSError) {
    print(error)
    nextPageURLString = nil
    
    isLoading = false
    
    if error.domain != NSURLErrorDomain {
      return
    }
    
    if error.code == NSURLErrorUserAuthenticationRequired {
      self.showOAuthLoginView()
    } else if error.code == NSURLErrorNotConnectedToInternet {
      self.showNotConnectedBanner()
    }
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    
    if (!GitHubAPIManager.sharedInstance.isLoadingOAuthToken) {
      loadInitialData()
    }
  }
  
  func loadInitialData() {
    isLoading = true
    GitHubAPIManager.sharedInstance.OAuthTokenCompletionHandler = { error in
      guard error == nil else {
        print(error)
        self.isLoading = false
        // TODO: handle error
        // Something went wrong, try again
        self.showOAuthLoginView()
        return
      }
      if let _ = self.safariViewController {
        self.dismissViewControllerAnimated(false) {}
      }
      self.loadGists(nil)
    }
    
    if (!GitHubAPIManager.sharedInstance.hasOAuthToken()) {
      showOAuthLoginView()
      return
    }
    loadGists(nil)
  }
  
  func showOAuthLoginView() {
    let storyboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle())
    GitHubAPIManager.sharedInstance.isLoadingOAuthToken = true
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
        GitHubAPIManager.sharedInstance.OAuthTokenCompletionHandler?(NSError(domain: GitHubAPIManager.ErrorDomain, code: -1,
          userInfo: [NSLocalizedDescriptionKey:
            "Could not create an OAuth authorization URL",
            NSLocalizedRecoverySuggestionErrorKey: "Please retry your request"]))
        return
      }
      self.safariViewController = SFSafariViewController(URL: authURL)
      self.safariViewController?.delegate = self
      guard let webViewController = self.safariViewController else {
        return
      }
      self.presentViewController(webViewController, animated: true, completion: nil)
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // MARK: - Creation
  func insertNewObject(sender: AnyObject) {
    let createVC = CreateGistViewController(nibName: nil, bundle: nil)
    self.navigationController?.pushViewController(createVC, animated: true)
  }

  // MARK: - Segues

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "showDetail" {
      if let indexPath = self.tableView.indexPathForSelectedRow {
        let gist = gists[indexPath.row] as Gist
        if let detailViewController = (segue.destinationViewController as!
          UINavigationController).topViewController as?
          DetailViewController {
          detailViewController.gist = gist
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
    return gistSegmentedControl.selectedSegmentIndex == 2
  }
  
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle:
    UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
      let gistToDelete = gists[indexPath.row]
      guard let idToDelete = gistToDelete.id else {
        return
      }
      // remove from array of gists
      gists.removeAtIndex(indexPath.row)
      // remove table view row
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
      
      // delete from API
      GitHubAPIManager.sharedInstance.deleteGist(idToDelete) {
        (error) in
        if let _ = error {
          print(error)
          // Put it back
          self.gists.insert(gistToDelete, atIndex: indexPath.row)
          tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Right)
          // tell them it didn't work
          let alertController = UIAlertController(title: "Could not delete gist",
                                                  message: "Sorry, your gist couldn't be deleted. Maybe GitHub is "
                                                    + "down or you don't have an internet connection.",
                                                  preferredStyle: .Alert)
          // add ok button
          let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
          alertController.addAction(okAction)
          // show the alert
          self.presentViewController(alertController, animated:true, completion: nil)
        }
      }
    } else if editingStyle == .Insert {
      // Create a new instance of the appropriate class, insert it into the array,
      // and add a new row to the table view.
    }
  }
  
  // MARK: - Pull to Refresh
  func refresh(sender:AnyObject) {
    GitHubAPIManager.sharedInstance.isLoadingOAuthToken = false
    nextPageURLString = nil // so it doesn't try to append the results
    GitHubAPIManager.sharedInstance.clearCache()
    loadInitialData()
  }
  
  // MARK: - Safari View Controller Delegate
  func safariViewController(controller: SFSafariViewController, didCompleteInitialLoad
    didLoadSuccessfully: Bool) {
    // Detect not being able to load the OAuth URL
    if (!didLoadSuccessfully) {
      controller.dismissViewControllerAnimated(true, completion: nil)
    }
  }
  
  @IBAction func segmentedControlValueChanged(sender: UISegmentedControl) {
    // clear out the table view
    gists = []
    tableView.reloadData()
    
    // only show add & edit buttons for my gists
    if (gistSegmentedControl.selectedSegmentIndex == 2) {
      self.navigationItem.leftBarButtonItem = self.editButtonItem()
      let addButton = UIBarButtonItem(barButtonSystemItem: .Add,
                                      target: self,
                                      action: #selector(insertNewObject(_:)))
      self.navigationItem.rightBarButtonItem = addButton
    } else {
      self.navigationItem.leftBarButtonItem = nil
      self.navigationItem.rightBarButtonItem = nil
    }
    
    // then load the new list of gists
    loadGists(nil)
  }
  
  func showNotConnectedBanner() {
    // show not connected error & tell em to try again when they do have a connection
    // check for existing banner
    if let existingBanner = self.notConnectedBanner {
      existingBanner.dismiss()
    }
    self.notConnectedBanner = Banner(title: "No Internet Connection",
                                     subtitle: "Could not load gists." +
      " Try again when you're connected to the internet",
                                     image: nil,
                                     backgroundColor: UIColor.redColor())
    self.notConnectedBanner?.dismissesOnSwipe = true
    self.notConnectedBanner?.show(duration: nil)
  }
  
}
