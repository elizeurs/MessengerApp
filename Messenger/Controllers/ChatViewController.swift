//
//  ChatViewController.swift
//  Messenger
//
//  Created by Elizeu RS on 01/10/23.
//

import UIKit
import MessageKit

// MesageType: protocol that comes in from the messageKit
struct Message: MessageType {
  var sender: SenderType
  var messageId: String
  var sentDate: Date
  var kind: MessageKind
}

// SenderType: protocol that comes in from the messageKit
struct Sender: SenderType {
  var photoURL: String
  var senderId: String
  var displayName: String
}

class ChatViewController: MessagesViewController {
  
  private var messages = [Message]()
  
  private let selfSender = Sender(photoURL: "",
                                  senderId: "1",
                                  displayName: "Joe Smith")

    override func viewDidLoad() {
        super.viewDidLoad()
      
      messages.append(Message(sender: selfSender,
                              messageId: "1",
                              sentDate: Date(),
                              kind: .text("Hello world message")))
      
      messages.append(Message(sender: selfSender,
                              messageId: "1",
                              sentDate: Date(),
                              kind: .text("Hello world message. Hello world message. Hello world message.")))
      
      view.backgroundColor = .systemRed
      
      // this MessagesViewController give us a messageCollectionView and there are 3 protocols on it that we need to assign.
      messagesCollectionView.messagesDataSource = self
      messagesCollectionView.messagesLayoutDelegate = self
      messagesCollectionView.messagesDisplayDelegate = self
      
    }

}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
  func currentSender() -> MessageKit.SenderType {
    return selfSender
  }
  
  func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
    return messages[indexPath.section]
  }
  
  func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
    return messages.count
  }
  
  
}
