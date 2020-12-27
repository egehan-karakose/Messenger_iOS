//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Egehan Karaköse on 25.12.2020.
//

import Foundation
import FirebaseDatabase



final class DatabaseManager{
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String{
        return emailAddress.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "@", with: "_")
    }

}

// MARK: - Account Management



extension DatabaseManager{
    
    public func userExists(with email: String, completion: @escaping ((Bool) -> Void)){
        
        
        let safeEmail = email.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "@", with: "_")
        
        database.child(safeEmail).observeSingleEvent(of: .value) { (snapshot) in
            guard snapshot.value as? String != nil else {
                completion(false)
                // user exists
                return
                 
            }
            // user not exists
            completion(true)
            
            
            
        }
         
    }
    
    
    /// Inserts new user to database
    public func insertUser(with user: ChatAppUser , completion: @escaping (Bool) -> Void){
        database.child(user.safeEmail).setValue([
            "first_name" : user.firstName,
            "last_name" : user.lastName
        ],withCompletionBlock: { error , _ in
            guard error == nil else {
                
                print("Failed to write to database")
                completion(false)
                return
            }

            self.database.child("users").observeSingleEvent(of: .value) { (snapshot) in
                if var usersCollections = snapshot.value as? [[String: String]] {
                    // append to user dictionary
                    
                    let newElement =  ["name" : user.firstName + " " + user.lastName,
                                       "email": user.emailAddress]
                    usersCollections.append(newElement)
                    
                    self.database.child("users").setValue(usersCollections, withCompletionBlock: { error , _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                        
                    })

                    
                    
                    
                }else{
                    // create that array
                    let newCollection : [[String : String]] = [
                        ["name" : user.firstName + " " + user.lastName,
                         "email": user.emailAddress]
                    ]
                    self.database.child("users").setValue(newCollection, withCompletionBlock: { error , _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        completion(true)
                        
                    })
                }
            }
           
        })
        
    }
    
    
    public func getAllUsers(completion : @escaping (Result<[[String: String]], Error>) -> Void) {
        
        database.child("users").observeSingleEvent(of: .value) { (snapshot) in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            completion(.success(value))
        }
        
    }
    
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
    
    /*
     users => [
        [
            "name" :
            "safe_email" :
        ],
        [
            "name" :
            "safe_email" :
        ]

     ]

     */
    
}


struct ChatAppUser {
    let firstName : String
    let lastName : String
    let emailAddress : String
    
    var safeEmail: String {
        return emailAddress.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "@", with: "_")
    }
    // /images/email_profile_picture.png
    
    var profilePictureFilename : String {
        return "\(safeEmail)_profile_picture.png"
    }
}
