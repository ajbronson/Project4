//
//  EditProfileViewController.swift
//  Founders Directory
//
//  Created by Steve Liddle on 9/21/16.
//  Copyright © 2016 Steve Liddle. All rights reserved.
//

import UIKit

class EditProfileViewController : UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextViewDelegate {
    
    // MARK: - Constants
    
    private struct UserMessages {
        static let TakePhotoLabel = "Take Photo"
        static let ProfileDefaultMessage = "(Enter Profile Information Here)"
    }

    // MARK: - Outlets
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var companyText: UITextField!
    @IBOutlet weak var emailText: UITextField!
    @IBOutlet weak var phoneText: UITextField!
    @IBOutlet weak var spouseText: UITextField!
    @IBOutlet weak var emailPrivateSwitch: UISwitch!
    @IBOutlet weak var phonePrivateSwitch: UISwitch!
    @IBOutlet weak var profileText: UITextView!
    @IBOutlet weak var addressText: UITextField!
    @IBOutlet weak var cityText: UITextField!
    @IBOutlet weak var stateText: UITextField!
    @IBOutlet weak var zipText: UITextField!
    
    // MARK: - Properties
    
    var founder: Founder?
    
    // MARK: - View controller lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        updateUI()
        navigationController?.resetBarTransparency()
        
        setupProfileText()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        imageView.applyCircleMask()
    }

    // MARK: - Helpers
    
    private func setupProfileText() {
        if profileText.text.characters.count == 0 {
            profileText.text = UserMessages.ProfileDefaultMessage
        }
        
        
        profileText.layer.borderColor = UIColor.black.cgColor
        profileText.layer.borderWidth = 1.0
        profileText.delegate = self
    }
    
    @objc
    private func updateUI() {
        if let founder = self.founder {
            imageView.image = UIImage(named: founder.imageUrl)
            nameText.text = founder.preferredFullName
            companyText.text = founder.organizationName
            emailText.text = founder.email
            phoneText.text = founder.cell
            addressText.text = "\(founder.homeAddress1) \(founder.homeAddress2)"
            stateText.text = founder.homeState
            cityText.text = founder.homeCity
            zipText.text = founder.homeZip
            spouseText.text = founder.spousePreferredFullName
            emailPrivateSwitch.isOn = !founder.isEmailListed
            phonePrivateSwitch.isOn = !founder.isPhoneListed
            profileText.text = founder.biography
        }
    }

    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        nameText.resignFirstResponder()
        companyText.resignFirstResponder()
        emailText.resignFirstResponder()
        phoneText.resignFirstResponder()
        spouseText.resignFirstResponder()
        profileText.resignFirstResponder()
    }

    // MARK: - Actions
    
    @IBAction func selectImage(_ sender: UIButton) {
        let imagePicker = UIImagePickerController()
        var sourceType: UIImagePickerControllerSourceType = .photoLibrary

        if sender.titleLabel?.text == UserMessages.TakePhotoLabel {
            sourceType = .camera
        }

        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            imagePicker.delegate = self
            imagePicker.sourceType = sourceType
            imagePicker.allowsEditing = true
            present(imagePicker, animated: true)
        }
    }
    
    @IBAction func doneButtonTapped(_ sender: UIBarButtonItem) {
        //TOOD: impement save
    }
    
    // MARK: - Image picker controller delegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let editedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            imageView.image = editedImage
        } else if let originalImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            imageView.image = originalImage
        }
        
        dismiss(animated: true)
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView == profileText {
            if profileText.text == UserMessages.ProfileDefaultMessage {
                profileText.text = ""
            }
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView == profileText {
            if profileText.text.characters.count == 0 {
                profileText.text = UserMessages.ProfileDefaultMessage
            }
        }
    }
}
