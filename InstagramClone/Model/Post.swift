//
//  Post.swift
//  InstagramClone
//
//  Created by Juan Francisco Dorado Torres on 8/9/19.
//  Copyright © 2019 Juan Francisco Dorado Torres. All rights reserved.
//

import Foundation
import Firebase

class Post {

  // MARK: - Properties

  var uid: String
  var type: String // "image", "video"...
  var caption: String
  var createdAt: Double
  var createdBy: User

  let db = Firestore.firestore()
  var docRef: DocumentReference?

  var postImage: UIImage?
  var imageDownloadURL: String?

  var comments = [Comment]()
  var likes = [User]()

  // MARK: - Constructor

  init(type: String, caption: String, createdBy: User, image: UIImage?) {
    self.uid = ""
    self.type = type
    self.caption = caption
    self.createdBy = createdBy
    self.createdAt = Date().timeIntervalSince1970 // unix time
    self.postImage = image

    docRef = db.collection("posts").document()
    self.uid = docRef!.documentID
  }

  init(dictionary: [String : Any]) {
    self.uid = dictionary["uid"] as? String ?? ""
    self.docRef = db.collection("posts").document(self.uid)
    self.type = dictionary["type"] as? String ?? ""
    self.caption = dictionary["caption"] as? String ?? ""
    self.createdAt = dictionary["createdAt"] as? Double ?? 0.0
    self.imageDownloadURL = dictionary["imageDownloadURL"] as? String

    guard let createdByDictionary = dictionary["createdBy"] as? [String : Any] else { fatalError("Cannot cast createdBy user") }
    self.createdBy = User(dictionary: createdByDictionary)

    likes = []
    if let likesDict = dictionary["likes"] as? [String : Any] {
      self.likes = likesDict.compactMap {
        if let userDict = $1 as? [String : Any] {
          return User.init(dictionary: userDict)
        }
        return nil
      }
    }
  }

  // MARK: - Methods

  func dictionary() -> [String : Any] {
    return [
      "uid" : uid,
      "type" : type,
      "caption" : caption,
      "createdAt" : createdAt,
      "createdBy" : createdBy.dictionary(),
      "imageDownloadURL" : imageDownloadURL ?? ""
    ]
  }
}

// MARK: - Firebase

extension Post {

  func save(_ completion: @escaping (Error?) -> Void) {
    // upload the image
    if let postImage = postImage {
      postImage.uploadToFirebase(path: "posts/\(uid)") { (url, error) in
        // set image download URL
        if let error = error {
          print("Error uploading post image: \(error)")
          return
        }

        guard let url = url else { return }
        self.imageDownloadURL = url.absoluteString

        // save post to db
        self.db.collection("posts")
          .document(self.uid).setData(self.dictionary(), completion: { (error) in
            if let error = error {
              print("***** Error saving post to DB: \(error)")
              return
            }

            // save post dictionary to the user's post node
            self.db.collection("users")
              .document(self.createdBy.uid)
              .updateData(["posts" : FieldValue.arrayUnion([self.uid])], completion: { (error) in
                completion(error)
              })
          })
      }
    }
  }

  func likeBy(_ user: User) {
    self.likes.append(user)
    docRef?.collection("likes").document(user.uid).setData(user.dictionary())
  }
}
