//
//  XMPPClientRosterCoreDataStorage.swift
//  Pods
//
//  Created by Ali Gangji on 6/30/16.
//
//

import Foundation
import XMPPFramework

public class XMPPClientRosterCoreDataStorage: XMPPRosterCoreDataStorage {
    
    public override init() {
        super.init(databaseFilename: "XMPPRoster", storeOptions: nil)
        autoRemovePreviousDatabaseFile = false
    }
    /*
    public override func commonInit() {
        super.commonInit()
        autoRemovePreviousDatabaseFile = false
        print(self.databaseFileName)
    }
     */
    override public func managedObjectModelName() -> String! {
        return "XMPPRoster"
    }
    override public func managedObjectModelBundle() -> Bundle! {
        return Bundle(for: XMPPRosterCoreDataStorage.self)
    }
}
