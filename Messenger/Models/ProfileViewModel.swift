//
//  ProfileViewModel.swift
//  Messenger
//
//  Created by Elizeu RS on 08/12/23.
//

import Foundation

enum ProfileViewModelType {
  case info, logout
}

struct ProfileViewModel {
  let viewModelType: ProfileViewModelType
  let title: String
  let handler: (() -> Void)?
}
