//
//  XMPPClientArchive.swift
//  Pods
//
//  Created by Ali Gangji on 6/18/16.
//
//

import Foundation
import CoreData
import JSQMessagesViewController
import XMPPFramework

public struct Subjects {
    public var userFrom: String?
    public var thread: String?
    
    public init(userFrom: String, thread: String) {
        self.userFrom = userFrom
        self.thread = thread
        // This initializer intentionally left empty
    }
}

public class XMPPClientArchive: NSObject {
    
    public lazy var storage: XMPPMessageArchivingCoreDataStorage = {
       return XMPPMessageArchivingCoreDataStorage.sharedInstance()
    }()
    
    public lazy var archive: XMPPMessageArchiving = {
        let archive = XMPPMessageArchiving(messageArchivingStorage: self.storage)
        archive?.clientSideMessageArchivingOnly = false // BRENO

        return archive!
    }()
    
    var connection:XMPPClientConnection!
    
    public func setup(connection:XMPPClientConnection) {
        self.connection = connection
        connection.activate(module: archive)
        connection.getStream().addDelegate(self, delegateQueue: DispatchQueue.main)
    }
    
    public func teardown() {
        archive.deactivate()
    }
    
    public func getAllSubjectsForJID(jid: String) -> [Subjects]  {
        let moc = storage.mainThreadManagedObjectContext
        let entityDescription = NSEntityDescription.entity(forEntityName: "XMPPMessageArchiving_Message_CoreDataObject", in: moc!)
        let request = NSFetchRequest<NSFetchRequestResult>()
        request.resultType = .dictionaryResultType
        request.entity = entityDescription
        let predicateFormat = "bareJidStr = %@ OR streamBareJidStr = %@"
        let predicate = NSPredicate(format: predicateFormat, jid, jid)
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.propertiesToFetch = ["thread", "bareJidStr"]
        request.propertiesToGroupBy = ["thread", "bareJidStr"]
        
        var returnArray = [Subjects]()
        do {
            let results = try moc?.fetch(request)
        
            for res in results! {
                
                let thread: String
                
                if (res as AnyObject)["thread"]! != nil {
                    thread = (res as AnyObject)["thread"] as! String
                } else {
                    thread = "No_thread"
                }
                
                let from = (res as AnyObject)["bareJidStr"] as! String ?? "No_user_from"
                
                returnArray.append(Subjects(userFrom: from, thread: thread))
                
                print(res)
                print((res as AnyObject)["bareJidStr"] ?? "" )
            }
            
            return returnArray
        } catch _ {
            print("error")
            //catch fetch error here
        }
        
        return returnArray
        
    }
    
    public func getAllMessagesInThread(jid: String, receiverJid: String, inThread thread: String) -> [JSQMessage] {
        let moc = storage.mainThreadManagedObjectContext
        let entityDescription = NSEntityDescription.entity(forEntityName: "XMPPMessageArchiving_Message_CoreDataObject", in: moc!)
        let request = NSFetchRequest<NSFetchRequestResult>()
        let predicateFormat = "(bareJidStr = %@ AND streamBareJidStr = %@) OR (bareJidStr = %@ AND streamBareJidStr = %@)"
        let predicate = NSPredicate(format: predicateFormat, jid, receiverJid, receiverJid, jid, thread)
        
        request.predicate = predicate
        request.entity = entityDescription
        
        var messages = [JSQMessage]()
        
        do {
            let results = try moc?.fetch(request)
            
            for message in results! {
                
                var element: DDXMLElement!
                do {
                    element = try DDXMLElement(xmlString: (message as AnyObject).messageStr)
                } catch _ {
                    element = nil
                }
                
                print(element)
                
                let body: String
                let sender: String
                let subject: String
                let date: NSDate

                
                date = (message as AnyObject).timestamp as NSDate
                
                if (message as AnyObject).thread() != nil {
                    subject = (message as AnyObject).thread()
                } else {
                    subject = "no_subject"
                }
                
                
                if (message as AnyObject).body() != nil {
                    body = (message as AnyObject).body()
                } else {
                    body = ""
                }
            
                if element.attributeStringValue(forName: "to").hasPrefix(jid) {
                    sender = receiverJid
                } else {
                    sender = jid
                }
                
                
                let fullMessage = JSQMessage(senderId: sender, senderDisplayName: sender, date: date as Date!, text: body)
                
                messages.append(fullMessage!)
                
                // TODO Should we sort everytime or insert already sorted?
                messages.sort {
                    $0.date < $1.date
                }
            }
        } catch _ {
            print("error")
            //catch fetch error here
        }
        
        for a in messages {
            print(a)
        }
        
        return messages
    }
    
    
    public func getAllUserMessagesForJID(jid: String) -> [String: [JSQMessage]] {
        let moc = storage.mainThreadManagedObjectContext
        let entityDescription = NSEntityDescription.entity(forEntityName: "XMPPMessageArchiving_Message_CoreDataObject", in: moc!)
        let request = NSFetchRequest<NSFetchRequestResult>()
        let predicateFormat = "bareJidStr = %@ OR streamBareJidStr = %@"
        let predicate = NSPredicate(format: predicateFormat, jid, jid)
        
        request.predicate = predicate
        request.entity = entityDescription
        
        var fullMessages = [String: [JSQMessage]]()
        
        
        do {
            let results = try moc?.fetch(request)
            
            for message in results! {
                var element: DDXMLElement!
                do {
                    element = try DDXMLElement(xmlString: (message as AnyObject).messageStr)
                } catch _ {
                    element = nil
                }
                
                let body: String
                let sender: String
                let date: NSDate
                let subject: String
                
                date = (message as AnyObject).timestamp as NSDate
                

                if (message as AnyObject).thread() != nil {
                    subject = (message as AnyObject).thread()
                } else {
                    subject = "no_subject"
                }
                
                
                if (message as AnyObject).body() != nil {
                    body = (message as AnyObject).body()
                } else {
                    body = ""
                }
                
                sender = (message as AnyObject).bareJidStr
                
                let fullMessage = JSQMessage(senderId: sender, senderDisplayName: sender, date: date as Date!, text: body)
                
                if fullMessages[subject] == nil {
                    fullMessages[subject] = [JSQMessage]()
                }
    
                fullMessages[subject]?.append(fullMessage!)
                
                // TODO Should we sort everytime or insert already sorted?
                fullMessages[subject]?.sort {
                    $0.date < $1.date
                }
                
            }
            
            // Sort
            let retArray = fullMessages.sorted{ ($0.value.last?.date)! > ($1.value.last?.date)! }
            
            for (subject, JSQArray) in retArray {
                for a in JSQArray {
                    print(a)
                }
                
            }
        } catch _ {
            //catch fetch error here
        }
        
        return fullMessages
    }
    
    public func deleteMessages(messages: NSArray) {
        messages.enumerateObjects({ (message, idx, stop) -> Void in
            let moc = self.storage.mainThreadManagedObjectContext
            let entityDescription = NSEntityDescription.entity(forEntityName: "XMPPMessageArchiving_Message_CoreDataObject", in: moc!)
            let request = NSFetchRequest<NSFetchRequestResult>()
            let predicateFormat = "messageStr like %@ "
            let predicate = NSPredicate(format: predicateFormat, message as! String)
            
            request.predicate = predicate
            request.entity = entityDescription
            
            do {
                let results = try moc?.fetch(request)
                
                for message in results! {
                    var element: DDXMLElement!
                    do {
                        element = try DDXMLElement(xmlString: (message as AnyObject).messageStr)
                    } catch _ {
                        element = nil
                    }
                    
                    if element.attributeStringValue(forName: "messageStr") == message as! String {
                        moc?.delete(message as! NSManagedObject)
                    }
                }
            } catch _ {
                //catch fetch error here
            }
        })
    }
    
    public func clearArchive() {
        deleteEntities(entity: "XMPPMessageArchiving_Message_CoreDataObject", fromMoc:storage.mainThreadManagedObjectContext)
        deleteEntities(entity: "XMPPMessageArchiving_Contact_CoreDataObject", fromMoc:storage.mainThreadManagedObjectContext)
    }
    
    private func deleteEntities(entity:String, fromMoc moc:NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
        fetchRequest.entity = NSEntityDescription.entity(forEntityName: entity, in: moc)
        fetchRequest.includesPropertyValues = false
        do {
            if let results = try moc.fetch(fetchRequest) as? [NSManagedObject] {
                for result in results {
                    moc.delete(result)
                }
                
                try moc.save()
            }
        } catch {
            print("failed to clear core data")
        }
    }
}

extension XMPPClientArchive: XMPPStreamDelegate {
    public func xmppStream(sender: XMPPStream!, didReceiveIQ iq: XMPPIQ!) -> Bool {
        print("got iq \(iq)")
        //TODO: complete retrieval of archives from server
        return false
    }
}
