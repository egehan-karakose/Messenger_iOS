//
//  PhotoViewerViewController.swift
//  Messenger
//
//  Created by Egehan Karaköse on 23.12.2020.
//

import UIKit
import SDWebImage

class PhotoViewerViewController: UIViewController {

    private let url :URL
    
    
    private let imageView : UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    init(with url: URL){
        self.url = url
        super.init(nibName: nil, bundle: nil)
        title = "Photo"
        navigationItem.largeTitleDisplayMode = .never
        view.addSubview(imageView)
        view.backgroundColor = .black
        self.imageView.sd_setImage(with: url, completed: nil)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        imageView.frame = view.bounds
    }
    

}
