//
//  ViewController.swift
//  Messenger
//
//  Created by Elizeu RS on 11/09/23.
//

import UIKit
import FirebaseAuth

class ConversationsViewController: UIViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
//    view.backgroundColor = .red
        
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
}

