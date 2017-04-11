//
//  XMPPClientRoster.swift
//  Pods
//
//  Created by Ali Gangji on 6/19/16.
//
//

import Foundation
import XMPPFramework

public class XMPPClientRoster: NSObject {
    
    public lazy var storage: XMPPClientRosterCoreDataStorage = {
        return XMPPClientRosterCoreDataStorage()
    }()
    
    public lazy var roster: XMPPRoster = {
        let roster = XMPPRoster(rosterStorage:self.storage)
        roster?.autoFetchRoster = true
        roster?.autoAcceptKnownPresenceSubscriptionRequests = true
        roster?.autoClearAllUsersAndResources = false
        roster?.allowRosterlessOperation = true
        return roster!
    }()
    
    var connection:XMPPClientConnection!

    public func setup(connection:XMPPClientConnection) {
        self.connection = connection
        connection.activate(module: roster)
    }
    
    public func teardown() {
        roster.deactivate()
    }
    
    public func userForJID(jid: String) -> XMPPUserCoreDataStorageObject? {
        let userJID = XMPPJID(string: jid)
        if let user = storage.user(for: userJID, xmppStream: connection.getStream(), managedObjectContext: storage.mainThreadManagedObjectContext) {
            return user
        } else {
            return nil
        }
    }
    
    public func manualFetch() {
        roster.fetch()
    }
    
    public func addNewUser(username: String) {
        roster.addUser(XMPPJID.init(string: username), withNickname: "Nickname1")

    }
    
    public func sendBuddyRequestTo(username: String) {
        let presence: DDXMLElement = DDXMLElement.element(withName: "presence") as! DDXMLElement
        presence.addAttribute(withName: "type", stringValue: "subscribe")
        presence.addAttribute(withName: "to", stringValue: username)
        presence.addAttribute(withName: "from", stringValue: connection.getStream().myJID.bare())
        connection.getStream().send(presence)
    }
    
    public func acceptBuddyRequestFrom(username: String) {
        let presence: DDXMLElement = DDXMLElement.element(withName: "presence") as! DDXMLElement
        presence.addAttribute(withName: "to", stringValue: username)
        presence.addAttribute(withName: "from", stringValue: connection.getStream().myJID.bare())
        presence.addAttribute(withName: "type", stringValue: "subscribed")
        connection.getStream().send(presence)
    }
    
    public func declineBuddyRequestFrom(username: String) {
        let presence: DDXMLElement = DDXMLElement.element(withName: "presence") as! DDXMLElement
        presence.addAttribute(withName: "to", stringValue: username)
        presence.addAttribute(withName: "from", stringValue: connection.getStream().myJID.bare())
        presence.addAttribute(withName: "type", stringValue: "unsubscribed")
        connection.getStream().send(presence)
    }

}
