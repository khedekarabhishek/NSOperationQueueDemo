//
//  ListViewController.swift
//  ClassicPhotos
//
//  Created by Richard Turton on 03/07/2014.
//  Copyright (c) 2014 raywenderlich. All rights reserved.
//

import UIKit
import CoreImage

let dataSourceURL = URL(string:"http://www.raywenderlich.com/downloads/ClassicPhotosDictionary.plist")

class ListViewController: UITableViewController {
  
    var photos = [PhotoRecord]()
    let pendingOperations = PendingOperations ()
    
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.title = "Classic Photos"
    
    fetchPhotoDetails()
  }
  
    func fetchPhotoDetails() {
        
        let  request = NSURLRequest(url: dataSourceURL!)
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        NSURLConnection.sendAsynchronousRequest(request as URLRequest, queue: OperationQueue.main) { (response, data, error) in
            if data != nil{
                
                let datasourceDictionary = try! PropertyListSerialization.propertyList(from: data!, options: [], format: nil) as! NSDictionary
                
                for(key,value) in datasourceDictionary{
                    
                    let name = key as? String
                    let url = NSURL(string: value as? String ?? "")
                    
                    if name != nil && url != nil{
                        let photorecord = PhotoRecord(name: name!, url: url!)
                        self.photos.append(photorecord)
                    }
                }
                self.tableView.reloadData()
            }
            
            if error != nil{
                
                let alert = UIAlertController(title: "OOPS!", message: error?.localizedDescription, preferredStyle: .alert)
                
                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                
                alert.addAction(defaultAction)
                
                self.present(alert, animated: true, completion: {
                    print("alert is here")
                })
            }
        }
    }
    
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  //MARK: - Table view data source
  
  override func tableView(_ tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
    return photos.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
    
    if cell.accessoryView == nil {
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        cell.accessoryView = indicator
    }
    
    let indicator = cell.accessoryView as! UIActivityIndicatorView
    
    let photoDetails = photos[indexPath.row]
    
    cell.textLabel?.text = photoDetails.name
    cell.imageView?.image = photoDetails.image
    
    switch photoDetails.state {
    case .Filtered:
        indicator.stopAnimating()
    case .Failed:
        indicator.stopAnimating()
        cell.textLabel?.text = "Failed to load"
    case .New , . Downloaded:
        indicator.startAnimating()
        if !tableView.isDragging && !tableView.isDecelerating{
            self.startOperationsForPhotoRecord(photoDetails: photoDetails, indexPath: indexPath as NSIndexPath)
        }
    }
    
    return cell
  }
  
  //MARK: Operation Methods
    func startOperationsForPhotoRecord(photoDetails : PhotoRecord, indexPath: NSIndexPath){
        switch photoDetails.state {
        case .New:
            startDownloadForRecord(photoDetails: photoDetails, indexPath: indexPath)
        case .Downloaded:
            startFiltrationForRecord(photoDetails: photoDetails, indexPath: indexPath)
        default:
            print("Do noting")
        }
    }
    
    func startDownloadForRecord(photoDetails : PhotoRecord, indexPath: NSIndexPath){
        
        if let  _ = pendingOperations.downloadsInProgress[indexPath]{
            return
        }
        
        let  downloader = ImageDownloader(photoRecord: photoDetails)
        
        downloader.completionBlock = {
            
            if downloader.isCancelled {
                return
            }
            DispatchQueue.main.async(execute: {
                self.pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath as IndexPath], with: .fade)
            })
        }
        
        self.pendingOperations.downloadsInProgress[indexPath] = downloader
        self.pendingOperations.downloadQueue.addOperation(downloader);

    }
    
    
    func startFiltrationForRecord(photoDetails : PhotoRecord, indexPath: NSIndexPath){
        
        if let _ = pendingOperations.filterationInPogress[indexPath] {
            return
        }
        
        let filterer = ImageFiltration(photoRecord: photoDetails)
        
        
        filterer.completionBlock = {
            
            if filterer.isCancelled {
                return
            }
            
            DispatchQueue.main.async(execute: { 
                self.pendingOperations.filterationInPogress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath as IndexPath], with: .right)
            })
        }
        
        self.pendingOperations.filterationInPogress[indexPath] = filterer
        self.pendingOperations.filterationQueue.addOperation(filterer)
    }
    
    
    
  
   
    //MARK: uiscrollview Methods
    
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        suspendAllOperations()

    }
    
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        if !decelerate {
            loadImagesForOnscreenCells()
            resumeAllOperations()
        }
    }
    
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        loadImagesForOnscreenCells()
        resumeAllOperations()
    }
    
    //MARK: Operation Methods after scrolling
    
    func suspendAllOperations () {
        pendingOperations.downloadQueue.isSuspended = true
        pendingOperations.filterationQueue.isSuspended = true
    }
    
    func resumeAllOperations () {
        pendingOperations.downloadQueue.isSuspended = false
        pendingOperations.filterationQueue.isSuspended = false
    }
    
    func loadImagesForOnscreenCells () {
        //1
        if let pathsArray = tableView.indexPathsForVisibleRows {
            //2
            let allPendingOperations = Array(pendingOperations.downloadsInProgress.keys)
            let allFilteringOpoerations = Array(pendingOperations.filterationInPogress.keys)
            
            let set1 = Set(allPendingOperations as [NSIndexPath])
            let set2 = Set(allFilteringOpoerations as [NSIndexPath])

            let set3: Set = set1.union(set2)
            
            //3
            var toBeCancelled = set3
            let visiblePaths = Set(pathsArray as [NSIndexPath])
            toBeCancelled.subtract(visiblePaths)
            
            //4
            var toBeStarted = visiblePaths
            toBeStarted.subtract(allPendingOperations)
            
            // 5
            for indexPath in toBeCancelled {
                if let pendingDownload = pendingOperations.downloadsInProgress[indexPath] {
                    pendingDownload.cancel()
                }
                pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
                if let pendingFiltration = pendingOperations.filterationInPogress[indexPath] {
                    pendingFiltration.cancel()
                }
                pendingOperations.filterationInPogress.removeValue(forKey: indexPath)
            }
            
            // 6
            for indexPath in toBeStarted {
                let indexPath = indexPath as NSIndexPath
                let recordToProcess = self.photos[indexPath.row]
                startOperationsForPhotoRecord(photoDetails: recordToProcess, indexPath: indexPath)
            }
        }
    }

    
}
