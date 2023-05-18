import UIKit

public extension UIImageView {
    func loadImage(from url:URL, placeholder: UIImage? = nil) {
        self.image = placeholder
        UIImageLoader.shared.load(from: url, in: self)
    }
    
    func cancelLoad() {
        UIImageLoader.shared.cancel(for: self)
    }
}

internal class UIImageLoader {
    static let shared = UIImageLoader()
    private var imagesCache = [URL:UIImage]()
    private var runningTasks = [UUID:URLSessionDataTask]()
    private var imageviewMap = [UIImageView:UUID]()
    
    private init() {
        
    }
    
    func load(from url:URL, in imageView:UIImageView) {
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
        imageviewMap[imageView] = id
        task.resume()
        
    }
    
    func cancel(for imageView:UIImageView) {
        guard let id = imageviewMap[imageView] else {return}
        guard let task = runningTasks[id] else {return}
        task.cancel()
        runningTasks.removeValue(forKey: id)
        imageviewMap.removeValue(forKey: imageView)
    }

}
