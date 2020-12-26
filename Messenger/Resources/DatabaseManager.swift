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
            
            completion(true)
        })
        
    }
    
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
