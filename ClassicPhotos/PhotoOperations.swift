//
//  PhotoOperations.swift
//  ClassicPhotos
//
//  Created by Abhishek Khedekar on 23/09/17.
//  Copyright © 2017 raywenderlich. All rights reserved.
//

import Foundation
import UIKit


enum PhotoRecordState{
    case New, Downloaded, Filtered, Failed
}

class PhotoRecord {
    let name:String
    let url:NSURL
    var state = PhotoRecordState.New
    var image = UIImage(named:"Placeholder")
    
    init(name:String,url:NSURL) {
        self.name = name
        self.url = url
    }
}

class PendingOperations:NSObject {
    
    lazy var downloadsInProgress = [NSIndexPath:Operation]()
    lazy var downloadQueue:OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Download queue"
        queue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
        return queue
    }()
    
    
    lazy var filterationInPogress = [NSIndexPath:Operation]()
    lazy var filterationQueue:OperationQueue = {
        var  queue = OperationQueue()
        queue.name = "Image Filtration queue"
        queue.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
        return queue
    }()
        
}


class ImageDownloader: Operation {
   
    let photoRecord : PhotoRecord
    
    init(photoRecord:PhotoRecord) {
        self.photoRecord = photoRecord
    }
    
    override func main() {  
        if self.isCancelled {
            return
        }
        
        let imageData = NSData(contentsOf: self.photoRecord.url as URL)
        
        
        if self.isCancelled {
            return
        }
        
        if (imageData?.length)! > 0 {
            
            self.photoRecord.image = UIImage(data: imageData! as Data)
            self.photoRecord.state = .Downloaded
        }else{
            
            self.photoRecord.image = UIImage(named:"failed")
            self.photoRecord.state = .Failed
        }
    }
}


class ImageFiltration: Operation {
    
    let photoRecord : PhotoRecord
    
    init(photoRecord:PhotoRecord) {
        self.photoRecord = photoRecord
    }
    
    override func main() {
        
        if self.isCancelled {
            return
        }
        
        if self.photoRecord.state != .Downloaded {
            return
        }
        
        
        if let filteredImage =  self.applySepiaFilter(image: self.photoRecord.image!){
           self.photoRecord.image = filteredImage
            self.photoRecord.state = .Filtered
        }

    }
    
    
    func applySepiaFilter(image:UIImage) -> UIImage? {
        
        let inputImage = CIImage(data: UIImagePNGRepresentation(image)!)
        
        
        if self.isCancelled {
            return UIImage(named: "failed")!
        }
        
        let context = CIContext(options:nil)
        let filter = CIFilter(name:"CISepiaTone")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(0.8, forKey: "inputIntensity")
        let outputImage = filter?.outputImage
        
        if self.isCancelled {
            return UIImage(named: "failed")!
        }
        
        let outImage = context.createCGImage(outputImage!, from: outputImage!.extent)
        let returnImage = UIImage(cgImage: outImage!)
        return returnImage
        
    }
}
