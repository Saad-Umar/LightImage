import UIKit

public extension UITableViewCell {
    func loadImage(from url:URL, in imageView:UIImageView, placeholder: UIImage? = nil) {
        imageView.image = placeholder
        UIImageLoader.shared.load(from: url, in: imageView, reusing: self)
    }
}

public extension UIImageView {
    func loadImage(from url:URL, placeholder: UIImage? = nil) {
        self.image = placeholder
        UIImageLoader.shared.load(from: url, in: self)
    }
    
    func cancel() {
        UIImageLoader.shared.cancel(in: AnyHashable(self))
    }
}

public extension UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        didEndDisplaying cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        UIImageLoader.shared.cancel(in: AnyHashable(cell))
    }
}

internal class UIImageLoader {
    static let shared = UIImageLoader()
    private var imagesCache = [URL:UIImage]()
    private var runningTasks = [UUID:URLSessionDataTask]()
    private var imageviewMap = [AnyHashable:UUID]()
    
    private init() {
        
    }
    
    func load(from url:URL, in imageView:UIImageView, reusing cell:UITableViewCell? = nil) {
        if let image = imagesCache[url] {
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
            imageviewMap[AnyHashable(cell)] = id
        } else {
            imageviewMap[AnyHashable(imageView)] = id
        }
        
        task.resume()
        
    }
    
    func cancel(in type:AnyHashable) {
        guard let id = imageviewMap[AnyHashable(type)] else {return}
        guard let task = runningTasks[id] else {return}
        task.cancel()
        runningTasks.removeValue(forKey: id)
        imageviewMap.removeValue(forKey: AnyHashable(type))
    }

}
