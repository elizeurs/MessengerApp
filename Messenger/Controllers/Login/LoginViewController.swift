//
//  LoginViewController.swift
//  Messenger
//
//  Created by Elizeu RS on 11/09/23.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import FirebaseCore
import JGProgressHUD

class LoginViewController: UIViewController {
  
  private let spinner = JGProgressHUD(style: .dark)
  
  private let scrollView: UIScrollView = {
    let scrollView = UIScrollView()
    scrollView.clipsToBounds = true
    return scrollView
  }()
  
  private let imageView: UIImageView = {
    let imageView = UIImageView()
    imageView.image = UIImage(named: "logo")
    imageView.contentMode = .scaleAspectFit
    return imageView
  }()
  
  private let emailField: UITextField = {
    let field = UITextField()
    field.autocapitalizationType = .none
    field.autocorrectionType = .no
    field.returnKeyType = .continue
    field.layer.cornerRadius = 12
    field.layer.borderWidth = 1
    field.layer.borderColor = UIColor.lightGray.cgColor
    field.placeholder = "Email Address..."
    field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
    field.leftViewMode = .always
    field.backgroundColor = .white
    return field
  }()
  
  private let passwordField: UITextField = {
    let field = UITextField()
    field.autocapitalizationType = .none
    field.autocorrectionType = .no
    field.returnKeyType = .done
    field.layer.cornerRadius = 12
    field.layer.borderWidth = 1
    field.layer.borderColor = UIColor.lightGray.cgColor
    field.placeholder = "Password..."
    field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
    field.leftViewMode = .always
    field.backgroundColor = .white
    field.isSecureTextEntry = true
    return field
  }()
  
  private let loginButton: UIButton = {
    let button = UIButton()
    button.setTitle("Log In", for: .normal)
    button.backgroundColor = .link
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 12
    button.layer.masksToBounds = true
    button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
    return button
  }()
  
  private let facebookLoginButton: FBLoginButton = {
    let button = FBLoginButton()
    button.permissions = ["public_profile", "email"]
    //    button.permissions = ["email,public_profile"]
    return button
  }()
  
  private let googleLogInButton: GIDSignInButton = {
      let button = GIDSignInButton()
      button.addTarget(self, action: #selector(signInWithGoogle), for: .touchUpInside) // Add this line
      return button
  }()

  @objc func signInWithGoogle() {
      // Your code to handle Google Sign-In goes here
    guard let clientID = FirebaseApp.app()?.options.clientID else { return }

            // Create Google Sign In configuration object.
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
            
            GIDSignIn.sharedInstance.signIn(withPresenting: self) { signInResult, error in
                guard error == nil else { return }

                guard let user = signInResult?.user,
                      let idToken = user.idToken?.tokenString else {
                    print("missing auth object off of google user")
                    return
                }
                
                print("did sign in with google: \(user)")
                
                guard let email = user.profile?.email,
                      let firstName = user.profile?.givenName,
                      let lastName = user.profile?.familyName else { return }
                
                DatabaseManager.shared.userExists(with: email) { exists in
                    if !exists {
                        //insert to database
                        DatabaseManager.shared.insertUser(with: ChatAppUser(firstName: firstName, lastName: lastName, emailAddress: email))
                    }
                }
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                // If sign in succeeded, display the app's main content View.
                
                FirebaseAuth.Auth.auth().signIn(with: credential) { authResult, error in
                    guard authResult != nil, error == nil else {
                        print("failed to log in with google credential")
                        return
                    }
                    
                    print("successfully signed in with google")
                  
                    NotificationCenter.default.post(name: .didLogInNotification, object: nil)
                }
              }
  }
  
  private var loginObserver: NSObjectProtocol?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // [weak self] - we don't want to cause a retention cycle.
    loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification, object: nil, queue: .main) { [weak self] _ in
      
      guard let strongSelf = self else {
        return
      }
      
      strongSelf.navigationController?.dismiss(animated: true, completion: nil)
    }
            
    title = "Log In"
    view.backgroundColor = .white
    
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register",
                                                        style: .done,
                                                        target: self,
                                                        action: #selector(didTapRegister))
    
    loginButton.addTarget(self,
                          action: #selector(loginButtonTapped),
                          for: .touchUpInside)
    
    emailField.delegate = self
    passwordField.delegate = self
    
    facebookLoginButton.delegate = self
    
    // add subviews
    view.addSubview(scrollView)
    scrollView.addSubview(imageView)
    scrollView.addSubview(emailField)
    scrollView.addSubview(passwordField)
    scrollView.addSubview(loginButton)
    scrollView.addSubview(facebookLoginButton)
    scrollView.addSubview(googleLogInButton)
  }
  
  deinit {
    if let observer = loginObserver {
      NotificationCenter.default.removeObserver(observer)
    }
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    scrollView.frame = view.bounds
    
    let size = scrollView.width/4
    imageView.frame = CGRect(x: (scrollView.width-size)/2,
                             y: 30,
                             width: size,
                             height: size)
    emailField.frame = CGRect(x: 30,
                              y: imageView.bottom+30,
                              width: scrollView.width-60,
                              height: 52)
    passwordField.frame = CGRect(x: 30,
                                 y: emailField.bottom+15,
                                 width: scrollView.width-60,
                                 height: 52)
    
    loginButton.frame = CGRect(x: 30,
                               y: passwordField.bottom+15,
                               width: scrollView.width-60,
                               height: 52)
    
    facebookLoginButton.frame = CGRect(x: 30,
                                       y: loginButton.bottom+15,
                                       width: scrollView.width-60,
                                       height: 52)
    
    googleLogInButton.frame = CGRect(x: 30,
                                       y: facebookLoginButton.bottom+15,
                                       width: scrollView.width-60,
                                       height: 52)
  }
  
  @objc private func loginButtonTapped() {
    // dismiss the keyboard
    emailField.resignFirstResponder()
    passwordField.resignFirstResponder()
    
    guard let email = emailField.text, let password = passwordField.text, !email.isEmpty, !password.isEmpty, password.count >= 6 else {
      alertUserLoginError()
      return
    }
    
    spinner.show(in: view)
    
    // firebase log in
    FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password, completion: { [weak self] authResult, error in
      guard let strongSelf = self else {
        return
      }
      
      
      // whenever you do anything user interface related, you need to do it on the main thread.
      DispatchQueue.main.async {
        strongSelf.spinner.dismiss()
      }
      
      guard let result = authResult, error == nil else {
        print("Failed to log in user with email: \(email)")
        return
      }
      
      let user = result.user
      print("Logged In User: \(user)")
      strongSelf.navigationController?.dismiss(animated: true, completion: nil)
    })
  }
  
  func alertUserLoginError() {
    let alert = UIAlertController(title: "Woops", message: "Please enter all information to log in", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
    present(alert, animated: true)
  }
  
  @objc private func didTapRegister() {
    let vc = RegisterViewController()
    vc.title = "Create Account"
    navigationController?.pushViewController(vc, animated: true)
  }
}

extension LoginViewController: UITextFieldDelegate {
  
  // jump from one field to the other, after pressing return key on keyboard.
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    
    if textField == emailField {
      passwordField.becomeFirstResponder()
    } else if textField == passwordField {
      loginButtonTapped()
    }
    
    return true
  }
}

extension LoginViewController: LoginButtonDelegate {
  //  func loginButtonDidLogOut(_ loginButton: FBSDKLoginKit.FBLoginButton) {
  func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
    // no operation
  }
  
  func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
    //  func loginButton(_ loginButton: FBSDKLoginKit.FBLoginButton, didCompleteWith result: FBSDKLoginKit.LoginManagerLoginResult?, error: Error?) {
    guard let token = result?.token?.tokenString else {
      print("User failed to log in with facebook")
      return
    }
    
    let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                     parameters: ["fields": "email, name"],
                                                     tokenString: token,
                                                     version: nil,
                                                     httpMethod: .get)
    
    facebookRequest.start { _, result, error in
      guard let result = result as? [String: Any],
            error == nil else {
        print("Failed to make facebook graph request")
        return
      }
      
            print("\(result)")
      
      guard let userName = result["name"] as? String,
            let email = result["email"] as?  String else {
        print("Failed to get email and name from fb result")
        return
      }
      
      let nameComponents = userName.components(separatedBy: " ")
      guard nameComponents.count == 3 else {
        return
      }
      
      let firstName = nameComponents[0]
      let lastName = nameComponents[2]
      
      DatabaseManager.shared.userExists(with: email) { exists in
        if !exists {
          DatabaseManager.shared.insertUser(with: ChatAppUser(firstName: firstName,
                                                              lastName: lastName,
                                                              emailAddress: email))
        }
      }
      
      let credential = FacebookAuthProvider.credential(withAccessToken: token)
      FirebaseAuth.Auth.auth().signIn(with: credential) { [weak self] authResult, error in
        guard let strongSelf = self else {
          return
        }
        
        guard authResult != nil, error == nil else {
          if let error = error {
            print("Facebook credential login failed, MFA may be needed - \(error)")
          }
          return
        }
        
        print("Successfully logged user in")
        strongSelf.navigationController?.dismiss(animated: true, completion: nil)
      }
    }
  }
}
