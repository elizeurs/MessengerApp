//
//  StorageManager.swift
//  Messenger
//
//  Created by Elizeu RS on 03/10/23.
//

import Foundation
import FirebaseStorage

/// Allows you to get, fetch, and upload files to firebase storage
final class StorageManager {
  
  static let shared = StorageManager()
  
  // so you can privatize the initializer, so everyone is forced to use 
  private init()  {}
  
  private let storage = Storage.storage().reference()
  
  /*
   /images/afraz9-gmail-com_profile_picture.png
   */
  
  public typealias UploadPictureCompletion = (Result<String, Error>) -> Void
  
  /// Uploads picture to firebase storage and returns completion with url string to download
  public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
    storage.child("images/\(fileName)").putData(data, metadata: nil) { [weak self] metadata, error in
      guard let strongSelf = self else {
          return
      }
      
      guard error == nil else {
        // failed
        print("failed to upload data to firebase for picture")
        completion(.failure(StorageErrors.failedToUpload))
        return
      }
      
      strongSelf.storage.child("images/\(fileName)").downloadURL { url, error in
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
  
  /// Upload image that will be sent in a conversation message
  public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping UploadPictureCompletion) {
    storage.child("message_images/\(fileName)").putData(data, metadata: nil) { [weak self] metadata, error in
      guard error == nil else {
        // failed
        print("failed to upload data to firebase for picture")
        completion(.failure(StorageErrors.failedToUpload))
        return
      }
      
      self?.storage.child("message_images/\(fileName)").downloadURL { url, error in
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
  
  /// Upload video that will be sent in a conversation message
  public func uploadMessageVideo(with fileUrl: URL, fileName: String, completion: @escaping UploadPictureCompletion) {
    storage.child("message_videos/\(fileName)").putFile(from: fileUrl, metadata: nil) { [weak self] metadata, error in
      guard error == nil else {
        // failed
        print("failed to upload video file to firebase for picture")
        completion(.failure(StorageErrors.failedToUpload))
        return
      }
      
      self?.storage.child("message_videos/\(fileName)").downloadURL { url, error in
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

