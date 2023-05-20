import UIKit

public extension UITableViewCell {
    func loadImage(from url:URL, in imageView:UIImageView, at:IndexPath, placeholder: UIImage? = nil) {
        imageView.image = placeholder
        UIImageLoader.shared.load(from: url, in: imageView, reusing: IndexPathAwareTableViewCell(indexPath: at, cell: self))
    }
}

private extension UIImageView {
    func loadImage(from url:URL, placeholder: UIImage? = nil) {
        self.image = placeholder
        UIImageLoader.shared.load(from: url, in: self)
    }
    
    func cancel() {
        UIImageLoader.shared.cancel(in: AnyHashable(self))
    }
}

internal class UIImageLoader {
    static let shared = UIImageLoader()
    private var imagesCache = [URL:UIImage?]()
    private var runningTasks = [UUID:URLSessionDataTask]()
    private var imageviewMap = [AnyHashable:UUID]()
    @objc private var indexPathAwareCells = [IndexPathAwareTableViewCell]()
    private var observations = [NSKeyValueObservation]()
    private var cacheDispatchWorkItems = [URL: DispatchWorkItem]()
    
    private init() {
        
    }
    
    fileprivate func load(from url:URL, in imageView:UIImageView, reusing cell: IndexPathAwareTableViewCell? = nil) {
        //If Image exists in ram
        if let image = imagesCache[url], let image = image {
            DispatchQueue.main.async {
                imageView.image = image
            }
            return
        } else if let image = UIImage(contentsOfFile: cachedImageFilePath(with: url) ?? "") { //If Image exists on disk
            imagesCache[url] = image
            DispatchQueue.main.async {
                imageView.image = image
            }
            return
        }
        
        let id = UUID()
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {return}
            guard let image = UIImage(data: data) else {return}
            self.imagesCache[url] = image
            DispatchQueue.main.async {
                imageView.image = image
            }
        }
        runningTasks[id] = task
        
        if let cell = cell {
            
            imageviewMap[cell] = id
            // check if cell is being reused by the tableview
            if let preExistingCell = indexPathAwareCells.first (where: { existingCell in
                return existingCell.cell == cell.cell
            }) {
                preExistingCell.isCurrentlyVisible = false
            }
            
            indexPathAwareCells.append(cell)
            observations.append(cell.observe(\.isCurrentlyVisible, options: .new, changeHandler: { [weak self] cell, change in
                guard let self = self else {return}
                guard let isCurrentlyVisible = change.newValue else {return}
                
                if !isCurrentlyVisible {
                    //remove and cancel
                    let workItem = DispatchWorkItem() {
                        //move image to disk cache
               
                        let fileManager = FileManager.default
                        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                        let filePath = documentsURL?.appendingPathComponent("\(url.absoluteString.toHexEncodedString()).png")
                        
                        guard let filePath = filePath else {return}
                        
                        if let image = self.imagesCache[url], let imageData = image?.pngData() {
                            do {
                                try imageData.write(to: filePath, options: .atomic)
                                print("Setting Image At Path:\(filePath)")
                            } catch {
                                print("Couldnt save image in file system:\(error)")
                            }
                        }
                       
                        if FileManager.default.fileExists(atPath: filePath.absoluteString) {
                            self.imagesCache.updateValue(nil, forKey: url) //free up ram
                            print("IMAGE FILE AT:\(url)")
                            print("RAM FREED UP!")
                            print(String(describing: url))
                            print(url)
                        }
                        
                    }
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5.0, execute: workItem)
                    self.cacheDispatchWorkItems[url] = workItem
                } else {
                    self.cacheDispatchWorkItems[url]?.cancel()
                }
               
                                
            }))
        } else {
            imageviewMap[AnyHashable(imageView)] = id
        }
        
        task.resume()
        
    }
    
    fileprivate func cancel(in type:AnyHashable) {
        guard let id = imageviewMap[AnyHashable(type)] else {return}
        guard let task = runningTasks[id] else {return}
        task.cancel()
        runningTasks.removeValue(forKey: id)
        imageviewMap.removeValue(forKey: AnyHashable(type))
    }
    
    fileprivate func cachedImageFilePath(with url: URL) -> String? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let filePath = documentsURL?.appendingPathComponent("\(url.absoluteString.toHexEncodedString()).png")
        print("Getting Image At Path: \(filePath)")
        return filePath?.absoluteString
    }

}

fileprivate class IndexPathAwareTableViewCell: NSObject {
    var indexPath: IndexPath
    var cell: UITableViewCell
    @objc dynamic var isCurrentlyVisible: Bool
    
    init(indexPath: IndexPath, cell: UITableViewCell) {
        self.indexPath = indexPath
        self.cell = cell
        self.isCurrentlyVisible = true
    }
}

extension String {
    func toHexEncodedString(uppercase: Bool = true, prefix: String = "", separator: String = "") -> String {
        return unicodeScalars.map { prefix + .init($0.value, radix: 16, uppercase: uppercase) } .joined(separator: separator)
    }
}
