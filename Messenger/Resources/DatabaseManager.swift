//
//  DatabaseManager.swift
//  Messenger
//
//  Created by Elizeu RS on 17/09/23.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
  
  static let shared = DatabaseManager()
  
  private let database = Database.database().reference()
  
  static func safeString(str: String) -> String {
    var safeString = str.replacingOccurrences(of: ".", with: "-")
    safeString = safeString.replacingOccurrences(of: "@", with: "-")
    return safeString
  }
  
}

// MARK: - Account Mgmt

extension DatabaseManager {
  
  public func userExists(with email: String,
                         completion: @escaping ((Bool) -> Void)) {
    
    var safeEmail = email.replacingOccurrences(of: ".", with: "-")
    safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
    
    database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
      guard snapshot.value as? String != nil else {
        completion(false)
        return
      }
      
      completion(true)
    })
  }
  
  // 3 slashes: you can add a documentation string. so, whenever you call this function, the autocomplete will show this.
  /// Inserts new user to database
  public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
    database.child(user.safeEmail).setValue([
      "first_name": user.firstName,
      "last_name": user.lastName
    ]) { error, _ in
      guard error == nil else {
        print("failed to write to database")
        completion(false)
        return
      }
      
      /*
        users => [
          [
            "name":
            "safe_email":
          ],
          [
            "name":
            "safe_email":
          ]
       ]
       */
      
      self.database.child("users").observeSingleEvent(of: .value) { snapshot in
        if var usersCollection = snapshot.value as? [[String: String]] {
          // apend to user dictionary
          let newElement = [
            
              "name": user.firstName + " " + user.lastName,
              "email": user.safeEmail
            
          ]
          usersCollection.append(newElement)
          
          self.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
            guard error == nil else {
              completion(false)
              return
            }
            
            completion(true)

          })
        }
        else {
          // create that array
          let newCollection: [[String: String]] = [
            [
              "name": user.firstName + " " + user.lastName,
              "email": user.safeEmail
            ]
          ]
          
          self.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
            guard error == nil else {
              completion(false)
              return
            }
            
            completion(true)

          })
        }
      }
    }
  }
  
  public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
    database.child("users").observeSingleEvent(of: .value, with: { snapshot in
      guard let value = snapshot.value as? [[String: String]] else {
        completion(.failure(DatabaseError.failedToFetch))
          return
      }
      completion(.success(value))
    })
  }
  
  public enum DatabaseError: Error {
    case failedToFetch
  }
}

// MARK: - Sending messages / conversations

extension DatabaseManager {
  
  /*
    "dfsdfdsfds" {
       "messages": [
           {
               "id": String,
               "type": text, photo, video
               "content": String,
               "date": Date(),
               "sender_email": String,
               "isRead": true/false
           }
       ]
   }
   
   conversation => [
       [

           "conversation_id": dfsdfdsfds,
           "other_user_email": text, photo, video
           "latest_message": => {
             "date": Date(),
             "latest_message": "message",
             "is_read": true/false
          }
       ],
   ]
   */
  
  // add documentation strings
  /// Create a new conversation with target user email and first message sent
  public func createNewConversation(with otherUserEmail: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
    guard let currentEmail = UserDefaults.standard.value(forKey: "email") as? String else {
      return
    }
    let safeEmail = DatabaseManager.safeString(str: currentEmail)
    
    let ref = database.child("\(safeEmail)")
    
    ref.observeSingleEvent(of: .value) { snapshot in
      guard var userNode = snapshot.value as? [String: Any] else {
        completion(false)
        print("user not found")
        return
      }
      
      let messageDate = firstMessage.sentDate
      let dateString = ChatViewController.dateFormatter.string(from: messageDate)
      
      var message = ""
      
      switch firstMessage.kind {
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
      
      let newConversationData: [String: Any] = [
        "id": conversationId,
        "other_user_email": otherUserEmail,
        "latest_message": [
          "date": dateString,
          "message": message,
          "is_read": false
        ]
      ]
      
      if var conversations = userNode["conversations"] as? [[String: Any]] {
        // conversation array existis for current user
        // you should append
        
        conversations.append(newConversationData)
        userNode["conversations"] = conversations
        // [weak self] - we don't wanna cause memory leak or  a memory retention cycle
        ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
          guard error == nil else {
            completion(false)
            return
          }
          self?.finishCreatingConversation(conversationID: conversationId,
                                          firstMessage: firstMessage,
                                          completion: completion)
        })
      }
      else {
        // conversation array does not exist
        // create it
        userNode["conversations"] = [
          newConversationData
        ]
        
        ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
          guard error == nil else {
            completion(false)
            return
          }
          
          self?.finishCreatingConversation(conversationID: conversationId,
                                          firstMessage: firstMessage,
                                          completion: completion)
        })
      }
    }
  }
  
  private func finishCreatingConversation(conversationID: String, firstMessage: Message, completion: @escaping(Bool) -> Void) {
//    "id": conversationId,
//    "other_user_email": otherUserEmail,
//    "latest_message": [
//      "date": dateString,
//      "message": message,
//      "is_read": false
    
    let messageDate = firstMessage.sentDate
    let dateString = ChatViewController.dateFormatter.string(from: messageDate)
    
    var message = ""
    switch firstMessage.kind {
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
    
    let currentUserEmail = DatabaseManager.safeString(str: myEmail)
    
    let collectionMessage: [String: Any] = [
      "id": firstMessage.messageId,
      "type": firstMessage.kind.messageKindString,
      "content": message,
      "date": dateString,
      "sender_email": currentUserEmail,
      "is_read": false
    ]
    
    let value: [String: Any] = [
      "messages": [
        collectionMessage
      ]
    ]
    
    print("adding convo: \(conversationID)")
    
    database.child("\(conversationID)").setValue(value, withCompletionBlock: { error, _  in
      guard error == nil else {
        completion(false)
        return
      }
      completion(true)
    })
  }
  
  /// Fetches and returns all conversations for the user with passed in email
  public func getAllConversations(for email: String, completion: @escaping (Result<String, Error>) -> Void) {
    
  }
  
  /// Gets all messages for a given conversation
  public func getAllMessagesForConversation(with id: String, completion: @escaping(Result<String, Error>) -> Void) {
    
  }
  
  /// Sends a message with target conversation and message
  public func sendMessage(to conversation: String, message: Message, completion: @escaping (Bool) -> Void) {
    
  }
}

struct ChatAppUser {
  let firstName: String
  let lastName: String
  let emailAddress: String
  
  var safeEmail: String {
    var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
    safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
    return safeEmail
  }
  
  var profilePictureFileName: String {
    //afraz9-gmail-com_profile_picture.png
    return "\(safeEmail)_profile_picture.png"
  }
}


