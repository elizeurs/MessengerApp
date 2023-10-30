//
//  ChatViewController.swift
//  Messenger
//
//  Created by Elizeu RS on 01/10/23.
//

import UIKit
import MessageKit
import InputBarAccessoryView

// MesageType: protocol that comes in from the messageKit
struct Message: MessageType {
  public var sender: SenderType
  public var messageId: String
  public var sentDate: Date
  public var kind: MessageKind
}

extension MessageKind {
  var messageKindString: String {
    switch self {
    case .text(_):
      return "text"
    case .attributedText(_):
      return "attributed_text"
    case .photo(_):
      return "photo"
    case .video(_):
      return "video"
    case .location(_):
      return "location"
    case .emoji(_):
      return "emoji"
    case .audio(_):
      return "audio"
    case .contact(_):
      return "contact"
    case .linkPreview(_):
      return "linkPreview"
    case .custom(_):
      return "custom"
    }
  }
}

// SenderType: protocol that comes in from the messageKit
struct Sender: SenderType {
  public var photoURL: String
  public var senderId: String
  public var displayName: String
}

class ChatViewController: MessagesViewController {
  
  // let - immutable
  public static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .long
    formatter.locale = .current
    return formatter
  }()
  
  public let otherUserEmail: String
  private let conversationId: String?
  public var isNewConversation = false
  
  private var messages = [Message]()
  
  private var selfSender: Sender? {
    guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
      return nil
    }
    
    let safeEmail = DatabaseManager.safeString(str: email)
    
    return Sender(photoURL: "",
                  senderId: safeEmail,
                  displayName: "Me")
  }
  
  // id: string optional - when we are creating a new conversation, there is no identifier yet, but when we click on or tap on a conversation that's in our list it has an id and tha identifier is basically how we're going to observe on the in the database as to what things is changing.
  init(with email: String, id: String?) {
    self.conversationId = id
    self.otherUserEmail = email
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // mocked out some messages here
    //      messages.append(Message(sender: selfSender,
    //                              messageId: "1",
    //                              sentDate: Date(),
    //                              kind: .text("Hello world message")))
    //
    //      messages.append(Message(sender: selfSender,
    //                              messageId: "1",
    //                              sentDate: Date(),
    //                              kind: .text("Hello world message. Hello world message. Hello world message.")))
    
    view.backgroundColor = .systemRed
    
    // this MessagesViewController give us a messageCollectionView and there are 3 protocols on it that we need to assign.
    messagesCollectionView.messagesDataSource = self
    messagesCollectionView.messagesLayoutDelegate = self
    messagesCollectionView.messagesDisplayDelegate = self
    messageInputBar.delegate = self
  }
  
  private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
    DatabaseManager.shared.getAllMessagesForConversation(with: id) { [weak self] result in
      switch result {
      case .success(let messages):
        print("success in getting messages: \(messages)")
        guard !messages.isEmpty else {
          print("messages are empty")
          return
        }
        self?.messages = messages
        
        DispatchQueue.main.async {
          // .reloadDataAndKeepOffset - if the user has scrolled to the top and they're reading older messages and a new message comes in, we don't want it to scroll down, 'cause that's a pretty bad experience.
          self?.messagesCollectionView.reloadDataAndKeepOffset()
          
          if shouldScrollToBottom {
            // scrollToBottom is deprecated. scrollToLastItem, instead.
            // fix: messages on the top getting behind the navigation bar.
            self?.messagesCollectionView.scrollToLastItem()
          }
        }
      case .failure(let error):
        print("failed to get messages: \(error)")
      }
    }
  }
  
  // because we want to present the keyboard once the view actually appeared and not in the loaded state
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // present the keyboard by default.Chat
    messageInputBar.inputTextView.becomeFirstResponder()
    if let conversationId = conversationId {
      listenForMessages(id: conversationId, shouldScrollToBottom: true)
    }
  }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
  
  // called when the send button is clicked.
  func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
    // validate this text(string) is not empty before sending the message. so we don't wanna allow the user to send a message with just spaces in it. make sure this is not empty. otherwise we want to send message.
    guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
          let selfSender = self.selfSender,
          let messageId = createMessageId() else {
      return
    }
    
    print("Sending: \(text)")
    
    let message = Message(sender: selfSender,
                          messageId: messageId,
                          sentDate: Date(),
                          kind: .text(text))
    
    // send message
    if isNewConversation {
      // create conversation in database
      DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: self.title ?? "User", firstMessage: message, completion: { [weak self] success in
        if success {
          print("Message sent")
          self?.isNewConversation = false
        }
        else {
          print("Failed at send")
        }
      })
    }
    else {
      guard let conversationId = conversationId, let name = self.title else {
        return
      }
      // append to existing conversation data
      DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message) { success in
        if success {
          print("message sent")
        }
        else {
          print("failed to send")
        }
      }
    }
  }
  
  private func createMessageId() -> String? {
    // date, otherUserEmail, senderEmail, randomInt
    guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
      return nil
    }
    
    let safeCurrentEmail = DatabaseManager.safeString(str: currentUserEmail)
    
    let dateString = Self.dateFormatter.string(from: Date())
    let safeDate = DatabaseManager.safeString(str: dateString)
    let newIdentifier = "\(otherUserEmail) \(safeCurrentEmail) \(safeDate)"
    
    print("created message id: \(newIdentifier)")
    
    return  newIdentifier
  }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
  func currentSender() -> SenderType {
    if let sender = selfSender {
      return sender
    }
    fatalError("Self Sender is nil, email should be cached")
  }
  
  func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
    return messages[indexPath.section]
  }
  
  func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
    return messages.count
  }
  
  
}
