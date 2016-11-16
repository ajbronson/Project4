//
//  SyncHelper.swift
//  Founders Directory
//
//  Created by Steve Liddle on 11/1/16.
//  Copyright © 2016 Steve Liddle. All rights reserved.
//

import UIKit
import GRDB

typealias JSONObject = [String : Any?]
typealias JSONArray = [Any?]

class SyncHelper {
    
    // MARK: - Constants

    private struct Command {
        static let add = "addfounder"
        static let delete = "deletefounder"
        static let getPhoto = "photo"
        static let getUpdates = "getupdatessince"
        static let update = "updatefounder"
        static let uploadPhoto = "uploadphoto"
    }

    struct Constants {
        static let baseSyncUrl = "https://scriptures.byu.edu/founders/v4/"
        static let failureCode = "0"
        static let photoFounder = "founder"
        static let photoSpouse = "spouse"
        static let resultKey = "result"
        static let sessionTokenKey = "sessionKey"
        static let userIDKey = "userIDKey"
        static let successResult = "success"
    }
    
    private struct Parameter {
        static let photoField = "u"
        static let photoType = "f"
        static let id = "i"
        static let maxVersion = "x"
        static let sessionToken = "k"
        static let version = "v"
    }

    // MARK: - Properties
    
    var lastSyncTime: Date?
    var sessionToken: String?
    
    // MARK: - Singleton
    
    static let shared = SyncHelper()

    fileprivate init() {
        loadSessionFromPreferences()
    }

    // MARK: - Public API

    func synchronizeFounders() -> Bool {
        lastSyncTime = Date()
    
        let maxVersion = FounderDatabase.shared.maxFounderVersion()
        var serverMaxVersion = 0

        // Note: In the production version, we won't let users delete
        //       or create founder records, only update.
        serverMaxVersion = syncDeletedFounders(serverMaxVersion);
        serverMaxVersion = syncNewFounders(serverMaxVersion);
        serverMaxVersion = syncDirtyFounders(serverMaxVersion);
        return syncServerFounderUpdates(maxVersion, serverMaxVersion);
    }

    // MARK: - Private helpers

    private func allFieldsMap() -> [String : String] {
        var allFields = [String : String]()
        var index = 0
    
        for field in Founder.allFieldsIdVersion {
            allFields["f\(index)"] = field
            index += 1
        }

        return allFields
    }

    //
    // Download and save locally a photo for a Founder or spouse.
    //
    private func downloadPhoto(id: Int, isSpouse: Bool) {
        guard let token = sessionToken else {
            return
        }

        let photoType = isSpouse ? Constants.photoSpouse : Constants.photoFounder
        let url = syncUrl(forCommand: Command.getPhoto,
                          withArguments: [Parameter.sessionToken : token,
                                          Parameter.id : "\(id)",
                                          Parameter.photoType : photoType])
        HttpHelper.shared.getContent(urlString: url) { (data) in
            if let imageData = data, let photoImage = UIImage(data: imageData) {
                if isSpouse {
                    PhotoManager.shared.saveSpousePhotoFor(founderId: id, photo: photoImage)
                } else {
                    PhotoManager.shared.savePhotoFor(founderId: id, photo: photoImage)
                }
            }
        }
    }
    
    //
    // Download the Founder and/or spouse photo(s) for this Founder record.
    //
    private func downloadPhotos(values: JSONObject) {
        if let idValue = values[Founder.Field.id] as? NSNumber {
            let id = Int(idValue)

            downloadPhoto(id: id, isSpouse: false)
            downloadPhoto(id: id, isSpouse: true)
        }
    }

    private func loadSessionFromPreferences() {
        sessionToken = UserDefaults.standard.string(forKey: Constants.sessionTokenKey)
    }

    private func syncDeletedFounders(_ serverMaxVersion: Int) -> Int {
        guard let token = sessionToken else {
            return serverMaxVersion
        }

        var maxVersion = serverMaxVersion

        for deletedId in FounderDatabase.shared.deletedFounderIds() {
            let url = syncUrl(forCommand: Command.delete,
                              withArguments: [Parameter.sessionToken : token,
                                              Parameter.id : "\(deletedId)"])
            HttpHelper.shared.getContent(urlString: url, failureCode: Constants.failureCode) { (content) in
                maxVersion = Int(content) ?? maxVersion

                if content != Constants.failureCode {
                    // Sync to delete on server worked, so remove from local database
                    FounderDatabase.shared.delete(deletedId)
                }
            }
        }

        return maxVersion
    }

    private func syncDirtyFounders(_ serverMaxVersion: Int) -> Int {
        guard let token = sessionToken else {
            return serverMaxVersion
        }

        var maxVersion = serverMaxVersion

        for dirtyId in FounderDatabase.shared.dirtyFounderIds() {
            var arguments = [Parameter.sessionToken : token,
                             Parameter.id : "\(dirtyId)"]
            let fieldKeyMap = allFieldsMap()
            let founderRow = FounderDatabase.shared.founderRecordForId(dirtyId)

            for (key, field) in fieldKeyMap {
                if let value = founderRow.value(named: field) as? String {
                    arguments[key] = value
                } else {
                    arguments[key] = ""
                }
            }

            arguments[Parameter.version] = founderRow.value(named: Founder.Field.version)

            let url = syncUrl(forCommand: Command.update, withArguments: arguments)

            HttpHelper.shared.postContent(urlString: url) { (data) in
                if let founders = try? JSONSerialization.jsonObject(with: data!,
                                                        options: .allowFragments) as! JSONObject {
                    let founder = FounderDatabase.shared.founderForId(dirtyId)
                    let upResult = uploadPhoto(id: dirtyId, founder: founder, isSpouse: false) ||
                                   uploadPhoto(id: dirtyId, founder: founder, isSpouse: true)

                    // Sync to add on server worked, so update in local database

                    guard let version = founders[Founder.Field.version] as? String else {
                        return
                    }

                    founder.new = Int(Founder.Flag.existing)!

                    // If we had trouble uploading an image, this record is still dirty
                    founder.dirty = Int(upResult ? Founder.Flag.clean : Founder.Flag.dirty)!
                    founder.update(from: founders)

                    maxVersion = Int(version) ?? maxVersion

                    FounderDatabase.shared.update(founder)
                }
            }
        }

        return maxVersion
    }

    private func syncNewFounders(_ serverMaxVersion: Int) -> Int {
        guard let token = sessionToken else {
            return serverMaxVersion
        }

        var maxVersion = serverMaxVersion

        for newId in FounderDatabase.shared.newFounderIds() {
            var arguments = [Parameter.sessionToken : token]
            let fieldKeyMap = allFieldsMap()
            let founderRow = FounderDatabase.shared.founderRecordForId(newId)

            for (key, field) in fieldKeyMap {
                if let value = founderRow.value(named: field) as? String {
                    arguments[key] = value
                } else {
                    arguments[key] = ""
                }
            }

            let url = syncUrl(forCommand: Command.add, withArguments: arguments)
            
            HttpHelper.shared.postContent(urlString: url) { (data) in
                if let serverNew = try? JSONSerialization.jsonObject(with: data!,
                                                                     options: .allowFragments) as! JSONObject {
                    // Sync to add on server worked, so replace in local database
                    
                    // TODO: There could be an issue here.  Make sure this ID doesn't already exist.
                    guard let newIdValue = serverNew[Founder.Field.id] as? String,
                        let version = serverNew[Founder.Field.version] as? String else {
                            return
                    }
                    
                    let founder = FounderDatabase.shared.founderForId(newId)
                    
                    founder.id = Int(newIdValue)!
                    founder.new = Int(Founder.Flag.existing)!
                    founder.dirty = Int(Founder.Flag.clean)!
                    founder.version = Int(version)!
                    
                    maxVersion = Int(version) ?? maxVersion
                    
                    FounderDatabase.shared.update(founder)

                    _ = uploadPhoto(id: newId, founder: founder, isSpouse: false)
                    _ = uploadPhoto(id: newId, founder: founder, isSpouse: true)
                }
            }
        }
        
        return maxVersion
    }

    private func syncServerFounderUpdates(_ maxVersion: Int, _ serverMaxVersion: Int) -> Bool {
        var changesMade = false

        guard let token = sessionToken else {
            return changesMade
        }

        // Ask the server for updates between our max at the beginning of the sync and
        // the new max on the server
        let arguments = [Parameter.sessionToken : token,
                         Parameter.version : "\(maxVersion)",
                         Parameter.maxVersion : "\(serverMaxVersion)"]
        let url = syncUrl(forCommand: Command.getUpdates, withArguments: arguments)

        HttpHelper.shared.getContent(urlString: url) { (data) in
            if let founders = try? JSONSerialization.jsonObject(with: data!,
                                                        options: .allowFragments) as! JSONArray {
                for i in 0 ..< founders.count {
                    if let founderObject = founders[i] as? JSONObject {
                        changesMade = true

                        let id = Int(founderObject[Founder.Field.id] as! NSNumber)

                        let founder = FounderDatabase.shared.founderForId(id)

                        if let deletedValue = founderObject[Founder.Field.deleted] as? String {
                            if deletedValue == Founder.Flag.deleted {
                                // Attempt to delete
                                FounderDatabase.shared.delete(id)
                                continue
                            }
                        }

                        // Attempt to update
                        if founder.id > 0 {
                            founder.update(from: founderObject)
                            FounderDatabase.shared.update(founder)
                            continue
                        }

                        // If we fall through to here, attempt to create
                        FounderDatabase.shared.insert(founder, from: founderObject)

                        downloadPhotos(values: founderObject)
                    }
                }
            }
        }

        return changesMade
    }

    private func syncUrl(forCommand command: String) -> String {
        return "\(Constants.baseSyncUrl)\(command).php"
    }
    
    private func syncUrl(forCommand command: String, withArguments arguments: [String : String]) -> String {
        var url = syncUrl(forCommand: command)

        if arguments.count > 0 {
            var first = true
            url += "?"

            for (key, value) in arguments {
                if first {
                    first = false
                } else {
                    url += "&"
                }

                url += "\(key)=\(value)"
            }
        }

        return url
    }
    
    //
    // Upload a photo for a founder or spouse.  Returns true if successful.
    //
    private func uploadPhoto(id: Int, founder: Founder, isSpouse: Bool) -> Bool {
        guard let token = sessionToken else {
            return false
        }

        var photo: UIImage?

        if (isSpouse) {
            photo = PhotoManager.shared.getSpousePhotoFor(founderId: id)
        } else {
            photo = PhotoManager.shared.getPhotoFor(founderId: id)
        }
        
        if let photoImage = photo {
            let uploadUrl = syncUrl(forCommand: Command.uploadPhoto)
            let photoType = isSpouse ? Constants.photoSpouse : Constants.photoFounder
            let photoField = isSpouse ? Founder.Field.spouseImageUrl : Founder.Field.imageUrl
            let photoParameters = [Parameter.sessionToken : token,
                                   Parameter.id : "\(id)",
                                   Parameter.photoType : photoType,
                                   Parameter.photoField : photoField]
            var success = false

            HttpHelper.shared.postMultipartContent(urlString: uploadUrl,
                                                   parameters: photoParameters,
                                                   image: photoImage) { (data) in
                if let resultObject = try? JSONSerialization.jsonObject(with: data!,
                                                        options: .allowFragments) as! JSONObject {
                    if let resultCode = resultObject[Constants.resultKey] as? String {
                        success = resultCode == Constants.successResult
                    }
                }
            }

            return success
        }

        // There was no photo to upload, so it wasn't a failure.
        return true
    }
}
