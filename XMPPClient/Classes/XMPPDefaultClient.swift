//
//  XMPPClient.swift
//  Pods
//
//  Created by Ali Gangji on 6/18/16.
//
//  a default XMPP Client with access to capabilities, roster, archiving, delivery receipts, and last activity

import Foundation
import XMPPFramework

public typealias XMPPMessageCompletionHandler = (_ stream: XMPPStream, _ message: XMPPMessage) -> Void

public protocol XMPPClientDelegate : NSObjectProtocol {
    func xmppClient(sender: XMPPStream, didReceiveMessage message: XMPPMessage, from user: XMPPUserCoreDataStorageObject)
    func xmppClient(sender: XMPPStream, userIsComposing user: XMPPUserCoreDataStorageObject)
}

public class XMPPDefaultClient: NSObject {

    public lazy var connection: XMPPClientConnection = {
        let connection = XMPPClientConnection()
        connection.delegate = self
        return connection
    }()
    
    public lazy var archive: XMPPClientArchive = {
        return XMPPClientArchive()
    }()
    
    public lazy var capabilities: XMPPClientCapabilities = {
        return XMPPClientCapabilities()
    }()
    
    public lazy var roster:XMPPClientRoster = {
        return XMPPClientRoster()
    }()
    
    public lazy var vcard:XMPPClientvCard = {
        return XMPPClientvCard()
    }()
    
    public lazy var receipts:XMPPClientDeliveryReceipts = {
        return XMPPClientDeliveryReceipts()
    }()
    
    public var enableArchiving = true
    public var delegate:XMPPClientDelegate?
    
    var messageCompletionHandler:XMPPMessageCompletionHandler?
    var isSetup = false
    
    public func setup() {
        roster.setup(connection: connection)
        vcard.setup(connection: connection)
        capabilities.setup(connection: connection)
        receipts.setup(connection: connection)
        if enableArchiving {
            archive.setup(connection: connection)
        }
        
        connection.getStream().addDelegate(self, delegateQueue: DispatchQueue.main)
        isSetup = true
    }
    
    public func teardown() {
        connection.getStream().removeDelegate(self)
        if enableArchiving {
            archive.teardown()
        }
        receipts.teardown()
        capabilities.teardown()
        vcard.teardown()
        roster.teardown()
        isSetup = false
    }
    
    public func connect(username username:String, password:String) {
        //if !isSetup {
        if username == "user36@pim.nl" {
            print("entered setup anyway")
            setup()
        }
  
        connection.connect(username: username, password: password)
    }
    
    public func disconnect() {
        connection.disconnect()
        if isSetup {
            teardown()
        }
    }
    
    public func sendMessage(message: String, thread:String, to receiver: String, completionHandler completion:@escaping XMPPMessageCompletionHandler) {
        
        
        let body = DDXMLElement.element(withName: "body", stringValue: message ) as! DDXMLElement
        let messageID = connection.getStream().generateUUID()
        
        
        let threadElement = DDXMLElement.element(withName: "thread", stringValue: thread) as! DDXMLElement
        
        let completeMessage = DDXMLElement.element(withName: "message") as! DDXMLElement
        
        completeMessage.addAttribute(withName: "id", stringValue: messageID!)
        completeMessage.addAttribute(withName: "type", stringValue: "chat")
        completeMessage.addAttribute(withName: "to", stringValue: receiver)
        completeMessage.addChild(body)
        completeMessage.addChild(threadElement)
        
        messageCompletionHandler = completion
        connection.getStream().send(completeMessage)
    }
    
}

extension XMPPDefaultClient: XMPPStreamDelegate {
    
    public func xmppStream(_ sender: XMPPStream, didSend message: XMPPMessage) {
        if let completion = messageCompletionHandler {
            completion(sender, message)
        }
    }
    
    public func xmppStream(_ sender: XMPPStream, didReceive message: XMPPMessage) {
        print("XMPPStream didReceive Message from Default Client Called...")
        
        
        if (!roster.storage.userExists(with: message.from().bare(), xmppStream: connection.getStream())) {
            roster.addNewUser(username: message.from().bare())
            roster.acceptBuddyRequestFrom(username: message.from().bare())
            roster.roster.acceptPresenceSubscriptionRequest(from: message.from().bare(), andAddToRoster: true)
            roster.manualFetch()
        }
        
        if (!roster.storage.userExists(with: message.from().bare(), xmppStream: connection.getStream())) {
            let when = DispatchTime.now() + 2
            DispatchQueue.main.asyncAfter(deadline: when) {
                var user = self.roster.storage.user(for: message.from(), xmppStream: self.connection.getStream(), managedObjectContext: self.roster.storage.mainThreadManagedObjectContext)
            
            
                if message.isChatMessageWithBody() {
                    print("entered here")
                    self.delegate?.xmppClient(sender: sender, didReceiveMessage: message, from: user!)
                } else if let _ = message.forName("composing") {
                    self.delegate?.xmppClient(sender: sender, userIsComposing: user!)
                }
            }

            return
        }
        
            var user = roster.storage.user(for: message.from(), xmppStream: connection.getStream(), managedObjectContext: roster.storage.mainThreadManagedObjectContext)
            
            if message.isChatMessageWithBody() {

                delegate?.xmppClient(sender: sender, didReceiveMessage: message, from: user!)
            } else if let _ = message.forName("composing") {
                delegate?.xmppClient(sender: sender, userIsComposing: user!)
            }
        
    }
    
    
}

extension XMPPDefaultClient: XMPPClientConnectionDelegate {
    public func xmppConnectionDidAuthenticate(sender: XMPPStream) {
        //TODO: initiate retrieval of archives from server
    }
    
    public func xmppConnectionDidConnect(sender: XMPPStream) {
        print("Connected")
    }
    
    public func xmppConnection(sender: XMPPStream!, socketDidConnect socket: GCDAsyncSocket!) {
        print("socket working")
    }
}
