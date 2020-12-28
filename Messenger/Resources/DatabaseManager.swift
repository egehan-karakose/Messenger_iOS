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

// MARK: - Sending Messages / Conversations
extension DatabaseManager{
    
    
    /*
     "asdasdasd" {
     "messages" : [
     {
     "id": String,
     "type": text, photo, video,
     "content": String,
     "data": Date()
     "sender_email": String,
     "isRead" : true / false
     }
     ],
     
     }
     
     
     conversation => [
     [
     "conversation_id" : "asdasdasd"
     "other_user_email" :
     "latest_message": => {
     "date": Date()
     "latest_message": "message"
     "is_read": true/false
     }
     ],
     ]
     
     */
    
    /// Creates a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, firstMessage: Message, completion: @escaping (Bool) -> Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else { return }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        let ref = database.child("\(safeEmail)")
        
        ref.observeSingleEvent(of: .value) { (snapshot) in
            guard var userNode = snapshot.value as? [String :Any] else {
                completion(false)
                print("user not found")
                return
            }
            
            let messageData = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageData)
            var message = ""
            
            switch firstMessage.kind{
            
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            
            let newConversationData : [String: Any] = [
                "id" : conversationId,
                "other_user_email" : otherUserEmail,
                "latest_message" : [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ],
            ]
            
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                // conversation array exists for current user
                // you shoud append
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode) { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishedCreatingConversation(conversationID: conversationId,
                                                       firstMessage: firstMessage,
                                                       completion: completion)
                }
                
                
            }else{
                // conversation array does not exist
                // create it
                userNode["conversations"] = [
                    newConversationData
                ]
                
                ref.setValue(userNode) {[weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishedCreatingConversation(conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                    
                }
                
            }
            
        }
        
        
    }
    
    
    private func finishedCreatingConversation(conversationID: String ,firstMessage: Message, completion : @escaping (Bool) -> Void) {
        
        //        {
        //           "id": String,
        //           "type": text, photo, video,
        //           "content": String,
        //           "data": Date()
        //           "sender_email": String,
        //           "is_read" : true / false
        //       }
        
        let messageData = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageData)
        var message = ""
        
        switch firstMessage.kind{
        
        case .text(let messageText):
            message = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        
        guard let myEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            completion(false)
            return
            
        }
        
        let currentEmail = DatabaseManager.safeEmail(emailAddress: myEmail)
        
        
        let collectionMessage : [String:Any] = [
            "id": firstMessage.messageId,
            "type": firstMessage.kind.messageKindString,
            "content": message,
            "date": dateString,
            "sender_email": currentEmail,
            "is_read": false
 
        ]
        
        let value : [String: Any] = [
            "messages": [
                collectionMessage]
        ]
        
        database.child("\(conversationID)").setValue(value) { (error, _) in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        }
        
        
    }
    
    
    /// Fetches and returns all conversation for the user with passed in email
    public func getAllConversations(for email: String, completion : @escaping (Result<String,Error>) -> Void){
        
        
        
    }
    
    ///Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id : String, completion : @escaping  (Result<String,Error>) -> Void){
        
        
        
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String , message: Message , comletion : @escaping (Bool) -> Void){
        
        
        
        
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
