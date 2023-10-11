//
//  StorageManager.swift
//  Messenger
//
//  Created by Elizeu RS on 03/10/23.
//

import Foundation
import FirebaseStorage

final class StorageManager {
  
  static let shared = StorageManager()
  
  private let storage = Storage.storage().reference()
  
  /*
   /images/afraz9-gmail-com_profile_picture.png
   */
  
  public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
  
  /// Uploads picture to firebase storage and returns completion with url string to download
  public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
    storage.child("images/\(fileName)").putData(data, metadata: nil) { metadata, error in
      guard error == nil else {
        // failed
        print("failed to upload data to firebase for picture")
        completion(.failure(StorageErrors.failedToUpload))
        return
      }
      
      self.storage.child("images/\(fileName)").downloadURL { url, error in
        guard let url = url else {
          print("Failed to get download url")
          completion(.failure(StorageErrors.failedToGetDownloaddUrl))
          return
        }
        
        let urlString = url.absoluteString
        print("download url returned: \(urlString)")
        completion(.success(urlString))
      }
    }
  }
  
  public enum StorageErrors: Error {
    case failedToUpload
    case failedToGetDownloaddUrl
  }
  
  public func downloadURL(for path: String, completion: @escaping (Result<URL, Error>) -> Void) {
    let reference = storage.child(path)
    
    reference.downloadURL { url, error in
      guard let url = url, error == nil else {
        completion(.failure(StorageErrors.failedToGetDownloaddUrl))
        return
      }
      
      completion(.success(url))
    }
  }

}

