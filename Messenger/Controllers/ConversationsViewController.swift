//
//  ViewController.swift
//  Messenger
//
//  Created by Elizeu RS on 11/09/23.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

// final - indicates that no other object of class can subclass it or inherit from it.
/// Controller that shows list of conversations
final class ConversationsViewController: UIViewController {
  
  private let spinner = JGProgressHUD(style: .dark)
  
  private var conversations = [Conversation]()
  
  private let tableView: UITableView = {
    let table = UITableView()
    table.isHidden = true
    table.register(ConversationTableViewCell.self,
                   forCellReuseIdentifier: ConversationTableViewCell.identifier)
    return table
  }()
  
  private let noConversationsLabel: UILabel = {
    let label = UILabel()
    label.text = "No Conversations!"
    label.textAlignment = .center
    label.textColor = .gray
    label.font = .systemFont(ofSize: 21, weight: .medium)
    label.isHidden = true
    return label
  }()
  
  private var loginObserver: NSObjectProtocol?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    //    view.backgroundColor = .red
    
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose,
                                                        target: self,
                                                        action: #selector(didTapComposeButton))
    
    view.addSubview(tableView)
    view.addSubview(noConversationsLabel)
    setupTableView()
    startListeningForConversations()
    
    loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main) { [weak self] _ in
      
      guard let strongSelf = self else {
        return
      }
      
      strongSelf.startListeningForConversations()
    }
  }
  
  private func startListeningForConversations() {
    guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
      return
    }
    
    if let observer = loginObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    
    print("starting conversation fetch...")
    
    // safe emails in the database, 'cause we can't use the dot in firebase keys.
    let safeEmail = DatabaseManager.safeString(str: email)
    
    DatabaseManager.shared.getAllConversations(for: safeEmail, completion: { [weak self] result in
      switch result {
      case .success(let conversations):
        print("successfully got conversation models")
        guard !conversations.isEmpty else {
          self?.tableView.isHidden = true
          self?.noConversationsLabel.isHidden = false
          return
        }
        self?.noConversationsLabel.isHidden = true
        self?.tableView.isHidden = false
        self?.conversations = conversations
        
        // main thread is where all the UI operations should occur
        DispatchQueue.main.async {
          self?.tableView.reloadData()
        }
      case .failure(let error):
        self?.tableView.isHidden = true
        self?.noConversationsLabel.isHidden = false
        print("failure to get convos: \(error)")
      }
    })
  }
  
  @objc private func didTapComposeButton() {
    let vc = NewConversationViewController()
    vc.completion = { [weak self] result in
//      print("\(result)")
      guard let strongSelf = self else {
        return
      }
      
      let currentConversations = strongSelf.conversations
      
      if let targetConversation = currentConversations.first(where: { $0.otherUserEmail == DatabaseManager.safeString(str: result.email)
      }) {
        let vc = ChatViewController(with: targetConversation.otherUserEmail, id: targetConversation.id)
        vc.isNewConversation = false
        vc.title = targetConversation.name
        vc.navigationItem.largeTitleDisplayMode = .never
        strongSelf.navigationController?.pushViewController(vc, animated: true)
      }
      else {
        strongSelf.createNewConversation(result: result)
      }
    }
    let navVC = UINavigationController(rootViewController: vc)
    present(navVC, animated: true)
  }
  
  private func createNewConversation(result: SearchResult) {
    // unwrap name and email. if we don't have them, return. minumum requirement to start a new conversation.
    // email is the thing that we're using in the database to identify users uniquely.
    let name = result.name
    let email = result.email
    
    // check in database if conversation with these two users exists
    // if it does, reuse conversation id
    // otherwise use existing code
    
    DatabaseManager.shared.conversationExists(with: email) { [weak self] result in
      guard let strongSelf = self else {
        return
      }
      switch result {
      case .success(let conversationId):
        let vc = ChatViewController(with: email, id: conversationId)
        vc.isNewConversation = false
        vc.title = name
        vc.navigationItem.largeTitleDisplayMode = .never
        strongSelf.navigationController?.pushViewController(vc, animated: true)
      case .failure(_):
        let vc = ChatViewController(with: email, id: nil)
        vc.isNewConversation = true
        vc.title = name
        vc.navigationItem.largeTitleDisplayMode = .never
        strongSelf.navigationController?.pushViewController(vc, animated: true)
      }
    }
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    tableView.frame = view.bounds
    noConversationsLabel.frame = CGRect(x: 10,
                                        y: (view.height-100)/2,
                                        width: view.width-20,
                                        height: 100)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    validateAuth()
  }
  
  private func validateAuth() {
    if FirebaseAuth.Auth.auth().currentUser == nil {
      let vc = LoginViewController()
      let nav = UINavigationController(rootViewController: vc)
      nav.modalPresentationStyle = .fullScreen
      present(nav, animated: false)
    }
  }
  
  private  func setupTableView() {
    tableView.delegate = self
    tableView.dataSource = self
  }
}

extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return conversations.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let model = conversations[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier,
                                             for: indexPath) as! ConversationTableViewCell
//    cell.textLabel?.text = "Hello World"
//    cell.accessoryType = .disclosureIndicator
    cell.configure(with: model)
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let model = conversations[indexPath.row]
    openConversation(model)
  }
  
  func openConversation(_ model: Conversation) {
    let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
    vc.title = model.name
    vc.navigationItem.largeTitleDisplayMode = .never
    navigationController?.pushViewController(vc, animated: true)
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 120
  }
  
  func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    return .delete
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      // begin delete
      let conversationId = conversations[indexPath.row].id
      tableView.beginUpdates()
      self.conversations.remove(at: indexPath.row)
      tableView.deleteRows(at: [indexPath], with: .left)
      
      DatabaseManager.shared.deleteConversation(conversationId: conversationId) { success in
        if !success {
            // add model and row back and show error alert
        }
      }
      tableView.endUpdates()
    }
  }
}

