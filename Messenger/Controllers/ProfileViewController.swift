//
//  ProfileViewController.swift
//  Messenger
//
//  Created by Elizeu RS on 11/09/23.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage


final class ProfileViewController: UIViewController {
  
  @IBOutlet var tableView: UITableView!
  
  var data = [ProfileViewModel]()
  
    override func viewDidLoad() {
        super.viewDidLoad()
      tableView.register(ProfileTableViewCell.self,
                         forCellReuseIdentifier: ProfileTableViewCell.identifier)
      
      data.append(ProfileViewModel(viewModelType: .info,
                                   title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")",
                                   handler: nil))
      data.append(ProfileViewModel(viewModelType: .info,
                                   title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")",
                                   handler: nil))
      
      data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", handler: { [weak self] in
                
        guard let strongSelf = self else {
          return
        }
        
        let actionSheet = UIAlertController(title: "",
                                            message: "",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Log Out",
                                            style: .destructive, handler: { [weak self] _ in
          
          guard let strongSelf = self else {
            return
          }
          
          UserDefaults.standard.setValue(nil, forKey: "email")
          UserDefaults.standard.setValue(nil, forKey: "name")
          
          // log out facebook
          FBSDKLoginKit.LoginManager().logOut()
          
          // google log out
          GIDSignIn.sharedInstance.signOut()
          
          do {
            try FirebaseAuth.Auth.auth().signOut()
            
              let vc = LoginViewController()
              let nav = UINavigationController(rootViewController: vc)
              nav.modalPresentationStyle = .fullScreen
              strongSelf.present(nav, animated: true)
          } catch {
            print("Failed to log out")
          }
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel",
                                            style: .cancel,
                                            handler: nil))
        
        strongSelf.present(actionSheet, animated: true)
      }))
      
      tableView.register(UITableViewCell.self,
                         forCellReuseIdentifier: "cell")
      tableView.delegate = self
      tableView.dataSource = self
      tableView.tableHeaderView = createTableHeader()
    }
  
  func createTableHeader() -> UIView? {
    // make sure we have an email saved.
    guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
      return nil
    }
    
    let safeEmail = DatabaseManager.safeString(str: email)
    let filename = safeEmail + "_profile_picture.png"
    let path = "images/"+filename
    
    let headerView = UIView(frame: CGRect(x: 0,
                                          y: 0,
                                          width: self.view.width,
                                          height: 300))
    
    headerView.backgroundColor = .systemBlue
    
    let imageView = UIImageView(frame: CGRect(x: (headerView.width-150) / 2,
                                              y: 75,
                                              width: 150,
                                              height: 150))
    
    imageView.contentMode = .scaleAspectFill
    imageView.backgroundColor = .white
    imageView.layer.borderColor = UIColor.white.cgColor
    imageView.layer.borderWidth = 3
    imageView.layer.masksToBounds = true
    imageView.layer.cornerRadius = imageView.width/2
    headerView.addSubview(imageView)
    
    StorageManager.shared.downloadURL(for: path) { result in
      switch result {
      case .success(let url):
        imageView.sd_setImage(with: url, completed: nil)
        // replaced by SDWebImage.
//        self?.downloadImage(imageView: imageView, url: url)
      case .failure(let error):
        print("Failed to get download url: \(error)")
      }
    }
        
    return headerView
  }
  
  // SDWebImage replaced this whole function.
//  func downloadImage(imageView: UIImageView, url: URL) {
//    imageView.sd_setImage(with: url, completed: nil)
    
    //  SDWebImage replaced that.
//    URLSession.shared.dataTask(with: url) { data, _, error in
//      guard let data = data, error == nil else {
//        return
//      }
//
//      // anything ui related should occur on the main thread
//      DispatchQueue.main.async {
//        let image = UIImage(data: data)
//        imageView.image = image
//      }
//      // to kick off the operation
//    }.resume()
//  }
}

extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return data.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let viewModel = data[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier,
                                             for: indexPath) as! ProfileTableViewCell
    cell.setUp(with: viewModel)
    // data doesn't have text anymore.
//    cell.textLabel?.text = data[indexPath.row]
//    cell.textLabel?.textAlignment = .center
//    cell.textLabel?.textColor = .red
    return cell
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // unhighlight the cell
    tableView.deselectRow(at: indexPath, animated: true)
    data[indexPath.row].handler?()
  }
}

class ProfileTableViewCell: UITableViewCell {
  
  static let identifier = "ProfileTableViewCell"
  
  public func setUp(with viewModel: ProfileViewModel) {
    self.textLabel?.text = viewModel.title
    switch viewModel.viewModelType {
    case .info:
      textLabel?.textAlignment = .left
      selectionStyle = .none
    case .logout:
      textLabel?.textColor = .red
      textLabel?.textAlignment = .center
    }
  }
}
