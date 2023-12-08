//
//  ChatViewController.swift
//  Messenger
//
//  Created by Elizeu RS on 01/10/23.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation


final class ChatViewController: MessagesViewController {
  
  private var senderPhotoURL: URL?
  private var otherUserPhotoURL: URL?
  
  // let - immutable
  public static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .long
    formatter.locale = .current
//    formatter.locale = Locale(identifier: "en_US")
//    formatter.locale = Locale.init(identifier: "en_US")
    return formatter
  }()
  
  public let otherUserEmail: String
  // make this var, instead of let, so it's mutable.
  private var conversationId: String?
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
    messagesCollectionView.messageCellDelegate = self
    messageInputBar.delegate = self
    setupInputButton()
  }
  
  private func setupInputButton() {
    let button = InputBarButtonItem()
    button.setSize(CGSize(width: 35, height: 35), animated: true)
    button.setImage(UIImage(systemName: "paperclip"), for: .normal)
    button.onTouchUpInside { [weak self] _ in
      self?.presentInputActionSheet()
    }
    messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
    messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
  }
  
  private func presentInputActionSheet() {
    let actionSheet = UIAlertController(title: "Attach Media",
                                        message: "What would you like to attach?",
                                        preferredStyle: .actionSheet)
    actionSheet.addAction(UIAlertAction(title: "Photo", style: .default, handler: { [weak self] _ in
      self?.presentPhotoInputActionSheet()
    }))
    
    actionSheet.addAction(UIAlertAction(title: "Video", style: .default, handler: {  [weak self] _ in
      self?.presentVideoInputActionSheet()
      
    }))
    
    actionSheet.addAction(UIAlertAction(title: "Audio", style: .default, handler: {  _ in
      
    }))
    
    actionSheet.addAction(UIAlertAction(title: "Location", style: .default, handler: {  [weak self] _ in
      self?.presentLocationPicker()
    }))
    
    actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    
    present(actionSheet, animated: true)
  }
  
  private func presentLocationPicker() {
    let vc = LocationPickerViewController(coordinates: nil)
    vc.title = "Pick Location"
    vc.navigationItem.largeTitleDisplayMode = .never
    vc.completion = { [weak self] selectedCoordinates in
      
      guard let strongSelf = self else {
        return
      }
      
      guard let messageId = strongSelf.createMessageId(),
            let conversationId = strongSelf.conversationId,
            let name = strongSelf.title,
            let selfSender = strongSelf.selfSender else {
        return
      }
      
      let longitude: Double = selectedCoordinates.longitude
      let latitude: Double = selectedCoordinates.latitude
      
      print("long=\(longitude) | lat=\(latitude)")
      
      let location = Location(location: CLLocation(latitude: latitude, longitude: longitude),
                           size: .zero)
      
      let message = Message(sender: selfSender,
                            messageId: messageId,
                            sentDate: Date(),
                            kind: .location(location))
      
      DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
        if success {
          print("sent location message")
        }
        else {
          print("failed to send location message")
        }
        
      })
    }
    navigationController?.pushViewController(vc, animated: true)
  }
  
  private func presentPhotoInputActionSheet() {
    let actionSheet = UIAlertController(title: "Attach Photo",
                                        message: "Where would you like to attach a photo from?",
                                        preferredStyle: .actionSheet)
    actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
      
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.delegate = self
      picker.allowsEditing = true
      self?.present(picker, animated: true)
      
    }))
    
    actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: {  [weak self] _ in
      
      let picker = UIImagePickerController()
      picker.sourceType = .photoLibrary
      picker.delegate = self
      picker.allowsEditing = true
      self?.present(picker, animated: true)
      
    }))
    
    actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    
    present(actionSheet, animated: true)
  }
  
  private func presentVideoInputActionSheet() {
    let actionSheet = UIAlertController(title: "Attach Video",
                                        message: "Where would you like to attach a video from?",
                                        preferredStyle: .actionSheet)
    actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
      
      let picker = UIImagePickerController()
      picker.sourceType = .camera
      picker.delegate = self
      picker.mediaTypes = ["public.movie"]
      picker.videoQuality = .typeMedium
      picker.allowsEditing = true
      self?.present(picker, animated: true)
      
    }))
    
    actionSheet.addAction(UIAlertAction(title: "Library", style: .default, handler: {  [weak self] _ in
      
      let picker = UIImagePickerController()
      picker.sourceType = .photoLibrary
      picker.delegate = self
      picker.allowsEditing = true
      picker.mediaTypes = ["public.movie"]
      picker.videoQuality = .typeMedium
      self?.present(picker, animated: true)
      
    }))
    
    actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    
    present(actionSheet, animated: true)
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

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true, completion: nil)
    guard let messageId = createMessageId(),
          let conversationId = conversationId,
          let name = self.title,
          let selfSender = selfSender else {
      return
    }
    
    if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
      let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
      
      // Upload image
      
      StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: "", completion: { [weak self] result in
        guard let strongSelf = self else {
          return
        }
        switch result {
        case .success(let urlString):
          // Ready to send message
          print("Uploaded message photo: \(urlString)")
          
          guard let url = URL(string: urlString),
                let placeholder = UIImage(systemName: "plus") else {
            return
          }
          
          let media = Media(url: url,
                            image: nil,
                            placeholderImage: placeholder,
                            size: .zero)
          
          let message = Message(sender: selfSender,
                                messageId: messageId,
                                sentDate: Date(),
                                kind: .photo(media))
          
          DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
            
            if success {
              print("sent photo message")
            }
            else {
              print("failed to send photo message")
            }
            
          })
          
        case .failure(let error):
          print("message photo upload error: \(error)")
        }
      })
    }
    else if let videoUrl = info[.mediaURL] as? URL {
      let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
      
      // upload video
      
      StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: fileName, completion: { [weak self] result in
        guard let strongSelf = self else {
          return
        }
        switch result {
        case .success(let urlString):
          // Ready to send message
          print("Uploaded message Video: \(urlString)")
          
          guard let url = URL(string: urlString),
                let placeholder = UIImage(systemName: "plus") else {
            return
          }
          
          let media = Media(url: url,
                            image: nil,
                            placeholderImage: placeholder,
                            size: .zero)
          
          let message = Message(sender: selfSender,
                                messageId: messageId,
                                sentDate: Date(),
                                kind: .video(media))
          
          DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: strongSelf.otherUserEmail, name: name, newMessage: message, completion: { success in
            
            if success {
              print("sent photo message")
            }
            else {
              print("failed to send photo message")
            }
            
          })
          
        case .failure(let error):
          print("message photo upload error: \(error)")
        }
      })
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
          let newConversationId = "conversation_\(message.messageId)"
          self?.conversationId = newConversationId
          self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
          self?.messageInputBar.inputTextView.text = nil
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
      DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: message) { [weak self] success in
        if success {
          self?.messageInputBar.inputTextView.text = nil
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
  
  func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
    guard let message = message as? Message else {
      return
    }
    
    switch message.kind {
    case .photo(let media):
      guard let imageUrl = media.url else {
        return
      }
      imageView.sd_setImage(with: imageUrl, completed: nil)
    default:
      break
    }
  }
  
  func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
    let sender = message.sender
    if sender.senderId == selfSender?.senderId {
      // our message that we've sent
      return .link
    }
    
    return .secondarySystemBackground
  }
  
  func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
    
    let sender = message.sender
    
    if sender.senderId == selfSender?.senderId {
      // show our image
      if let currentUserImageURL = self.senderPhotoURL {
        avatarView.sd_setImage(with: currentUserImageURL, completed: nil)
      }
      else {
        // images/safeemail_profile_picture.png
        
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return
        }
        
        let safeEmail = DatabaseManager.safeString(str: email)
        let path = "images/\(safeEmail)_profile_picture.png"
        
        // fetch url
        StorageManager.shared.downloadURL(for: path) { [weak self] result in
          switch result {
          case .success(let url):
            self?.senderPhotoURL = url
            DispatchQueue.main.async {
              avatarView.sd_setImage(with: url, completed: nil)
            }
          case .failure(let error):
            print("\(error)")
          }
        }
      }
    }
    else {
      // other user image
      if let otherUserPhotoURL = self.otherUserPhotoURL {
        avatarView.sd_setImage(with: otherUserPhotoURL, completed: nil)
      }
      else {
        // fetch url
        let email = self.otherUserEmail
        
        let safeEmail = DatabaseManager.safeString(str: email)
        let path = "images/\(safeEmail)_profile_picture.png"
        
        // fetch url
        StorageManager.shared.downloadURL(for: path) { [weak self] result in
          switch result {
          case .success(let url):
            self?.otherUserPhotoURL = url
            DispatchQueue.main.async {
              avatarView.sd_setImage(with: url, completed: nil)
            }
          case .failure(let error):
            print("\(error)")
          }
        }
      }
    }
  }
}

extension ChatViewController: MessageCellDelegate {
  func didTapMessage(in cell: MessageCollectionViewCell) {
    guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
      return
    }
    
    let message = messages[indexPath.section]
    
    switch message.kind {
    case .location(let locationData):
      let coordinates = locationData.location.coordinate
      let vc = LocationPickerViewController(coordinates: coordinates)
      vc.title = "Location"
    navigationController?.pushViewController(vc, animated: true)
    default:
      break
    }
  }
  
  func didTapImage(in cell: MessageCollectionViewCell) {
    guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
      return
    }
    
    let message = messages[indexPath.section]
    
    switch message.kind {
    case .photo(let media):
      guard let imageUrl = media.url else {
        return
      }
      let vc = PhotoViewerViewController(url: imageUrl)
      navigationController?.pushViewController(vc, animated: true)
    case .video(let media):
      guard let videoUrl = media.url else {
        return
      }
      
      let vc = AVPlayerViewController()
      vc.player = AVPlayer(url: videoUrl)
      present(vc, animated: true)
    default:
      break
    }
  }
}
