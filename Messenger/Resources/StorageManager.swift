//
//  StorageManager.swift
//  Messenger
//
//  Created by Egehan Karaköse on 26.12.2020.
//

import Foundation
import FirebaseStorage


final class StorageManager{
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    
    /*
     /images/email_profile_picture.png
     
     */
    
    
    public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
    /// Uploads picture to firebase storage and returns completion url to download
    
    public func uploadProfilePicture(with data: Data, filename: String, completion: @escaping UploadPictureCompletion){
        storage.child("images/\(filename)").putData(data,metadata: nil, completion: { metadata ,error in
            
            guard error == nil else{
                //failed
                print("Failed to upload data to firebase for picture")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("images/\(filename)").downloadURL { (url, error) in
                guard let url = url else {
                    print("Failed To get download url")
                    completion(.failure(StorageErrors.failedToGetDownloadUrl))
                    return
                    
                }
                let urlString = url.absoluteString
                print("download url returned: \(urlString)")
                completion(.success(urlString))
            }

        })
        
    }
    
    
    public enum StorageErrors: Error{
        case failedToUpload
        case failedToGetDownloadUrl
    }
    
    
    public func downloadURL(for path: String , completion: @escaping (Result<URL, Error>) -> Void) {
        let reference = storage.child(path)
        
        reference.downloadURL { (url, error) in
            guard let url = url , error == nil else{
                completion(.failure(StorageErrors.failedToGetDownloadUrl))
                return
            }
            
            completion(.success(url))
        }
    }
    
}

