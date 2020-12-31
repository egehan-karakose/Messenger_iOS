//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Egehan Karaköse on 25.12.2020.
//

import Foundation
import FirebaseDatabase
import MessageKit



final class DatabaseManager{
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    static func safeEmail(emailAddress: String) -> String{
        return emailAddress.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "@", with: "_")
    }
    
}

extension DatabaseManager {
    public func getDataFor(path: String, completion : @escaping (Result<Any, Error>) -> Void){
        self.database.child("\(path)").observeSingleEvent(of: .value) { (snapshot) in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
                
            }
            completion(.success(value))
        }
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
    public func createNewConversation(with otherUserEmail: String,name: String, firstMessage: Message, completion: @escaping (Bool) -> Void){
        guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String else { return }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: currentEmail)
        
        let ref = database.child("\(safeEmail)")
        
        ref.observeSingleEvent(of: .value) { [weak self] snapshot in
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
            let safeOtherUserEmail = DatabaseManager.safeEmail(emailAddress: otherUserEmail)
            
            let newConversationData : [String: Any] = [
                "id" : conversationId,
                "other_user_email" : safeOtherUserEmail,
                "name": name,
                "latest_message" : [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ],
            ]
            
            let recipient_newConversationData : [String: Any] = [
                "id" : conversationId,
                "other_user_email" : safeEmail,
                "name": currentName,
                "latest_message" : [
                    "date": dateString,
                    "message": message,
                    "is_read": false
                ],
            ]
            
            // update recipient conversation entry
            self?.database.child("\(safeOtherUserEmail)/conversations").observeSingleEvent(of: .value) {[weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    // append
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(safeOtherUserEmail)/conversations").setValue(conversations)
                }else {
                    // create
                    self?.database.child("\(safeOtherUserEmail)/conversations").setValue([recipient_newConversationData])
                    
                }
            }
            
            // update current user conversation entry
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
                    self?.finishedCreatingConversation(name: name,
                                                       conversationID: conversationId,
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
                    self?.finishedCreatingConversation(name: name, conversationID: conversationId, firstMessage: firstMessage, completion: completion)
                    
                }
                
            }
        }
    }
    
    
    private func finishedCreatingConversation(name :String, conversationID: String,  firstMessage: Message, completion : @escaping (Bool) -> Void) {
        
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
            "is_read": false,
            "name": name
            
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
    public func getAllConversations(for email: String, completion : @escaping (Result<[Conversation],Error>) -> Void){
        database.child("\(email)/conversations").observe(.value) { (snapshot) in
            guard let value = snapshot.value as? [[String :Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            let conversations: [Conversation] = value.compactMap { (dictionary) in
                guard let conversationId = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                    return nil
                }
                
                
                let latestMessageObject = LatestMessage(date: date,
                                                        text: message,
                                                        isRead: isRead)
                
                return Conversation(id: conversationId,
                                    name: name,
                                    otherUserEmail: otherUserEmail,
                                    latestMessage: latestMessageObject)
            }
            
            completion(.success(conversations))
        }
        
        
    }
    
    ///Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id : String, completion : @escaping  (Result<[Message],Error>) -> Void){
        
        
        database.child("\(id)/messages").observe(.value) { (snapshot) in
            guard let value = snapshot.value as? [[String :Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            
            let messages: [Message] = value.compactMap { dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let content = dictionary["content"] as? String,
                      let messageID = dictionary["id"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let type = dictionary["type"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString)
                else {
                    print("returned nil")
                    return nil
                }
                
                
                
                var kind : MessageKind?

                if type == "photo" {
                    // photo
                    guard let imageURL = URL(string: content),
                          let placeholder = UIImage(systemName: "plus")

                    else {
                        return nil
                    }
                    let media = Media(url: imageURL, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                    kind = .photo(media)

                }else if type == "video" {
                    // photo
                    guard let videoURL = URL(string: content),
                          let placeholder = UIImage(named: "video_placeholder")

                    else {
                        return nil
                    }
                    let media = Media(url: videoURL, image: nil, placeholderImage: placeholder, size: CGSize(width: 300, height: 300))
                    kind = .video(media)

                }else{
                    kind = .text(content)

                }

                guard let finalKind = kind else {
                    return nil
                }


                let sender = Sender(photoURL: "",
                                    senderId: senderEmail,
                                    displayName: name)
                
                 return Message(sender: sender,
                                   messageId: messageID,
                                   sentDate: date,
                                   kind: finalKind)
                
                
                
            }
            
            completion(.success(messages))
        }        
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, newMessage: Message , completion : @escaping (Bool) -> Void){
        //add new message to messages
        //update sender latest message
        //update recepient latest message
        
        database.child("\(conversation)/messages").observeSingleEvent(of: .value) {[weak self] (snapshot) in
            
            guard let strongSelf = self else { return }
            guard var currentMessages = snapshot.value as? [[String :Any]] else {
                completion(false)
                return
            }
            let messageData = newMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageData)
            var message = ""
            
            switch newMessage.kind{
            
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(let mediaItem):
                if let targetURL = mediaItem.url?.absoluteString{
                    message = targetURL
                }
                break
            case .video(let mediaItem):
                if let targetURL = mediaItem.url?.absoluteString{
                    message = targetURL
                }
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
            
            
            let newMessageEntry : [String:Any] = [
                "id": newMessage.messageId,
                "type": newMessage.kind.messageKindString,
                "content": message,
                "date": dateString,
                "sender_email": currentEmail,
                "is_read": false,
                "name": name
                
            ]
            
            currentMessages.append(newMessageEntry)
            
            strongSelf.database.child("\(conversation)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else{
                    completion(false)
                    return
                }
                strongSelf.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value) { (snapshot) in
                    guard var currentUserConversations = snapshot.value as? [[String: Any]] else {
                        completion(false)
                        return
                    }
                    
                    let updatedValue: [String : Any] = [
                        "date":dateString,
                        "message": message,
                        "is_read": false
                        
                    ]
                    
                    var targetConversation : [String: Any]?
                    
                    var position = 0
                    
                    for conversationDictionary in currentUserConversations {
                        if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                            
                            targetConversation = conversationDictionary
                            break
                        }
                        position += 1
                    }
                    targetConversation?["latest_message"] = updatedValue
                    guard let finalConversation = targetConversation else {
                        completion(false)
                        return
                        
                    }
                    currentUserConversations[position]  = finalConversation
                    
                    strongSelf.database.child("\(currentEmail)/conversations").setValue(currentUserConversations) { (error, _) in
                        guard error ==  nil else {
                            completion(false)
                            return
                        }
                        
                        
                        // update latest message for recipient
                        
                        strongSelf.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) { (snapshot) in
                            guard var otherUserConversations = snapshot.value as? [[String: Any]] else {
                                completion(false)
                                return
                            }
                            
                            let updatedValue: [String : Any] = [
                                "date":dateString,
                                "message": message,
                                "is_read": false
                                
                            ]
                            
                            var targetConversation : [String: Any]?
                            
                            var position = 0
                            
                            for conversationDictionary in otherUserConversations {
                                if let currentId = conversationDictionary["id"] as? String, currentId == conversation {
                                    
                                    targetConversation = conversationDictionary
                                    break
                                }
                                position += 1
                            }
                            targetConversation?["latest_message"] = updatedValue
                            guard let finalConversation = targetConversation else {
                                completion(false)
                                return
                                
                            }
                            otherUserConversations[position]  = finalConversation
                            
                            strongSelf.database.child("\(otherUserEmail)/conversations").setValue(otherUserConversations) { (error, _) in
                                guard error ==  nil else {
                                    completion(false)
                                    return
                                }
                                completion(true)
                            }
                        }
                    }
                }
            }
        }
    }
    public func deleteConversation(conversationId : String, completion : @escaping (Bool) -> Void){
        guard let email = UserDefaults.standard.value(forKey:"email") as? String else {
            return
        }
        
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        
        // Get all conversation for current user
        // delete conversation in collection with target id
        // reset those conversation for the user in database
        let ref = database.child("\(safeEmail)/conversations")
            
        ref.observeSingleEvent(of: .value) { (snapshot) in
            if var conversations = snapshot.value as? [[String: Any]] {
                var positionToRemove = 0
                for conversation in conversations{
                    if let id = conversation["id"] as? String,
                       id == conversationId {
                        break
                    }
                    positionToRemove += 1
                }
                conversations.remove(at: positionToRemove)
                ref.setValue(conversations) { (error, _) in
                    guard error == nil else{
                        completion(false)
                        print("failed to write updated conversation")
                        return
                    }
                    print("conversation deleted")
                    completion(true)
                }
            }
        }
        
        
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
