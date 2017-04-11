//
//  XMPPClientDeliveryReceipts.swift
//  Pods
//
//  Created by Ali Gangji on 6/19/16.
//
//

import Foundation
import XMPPFramework

public class XMPPClientDeliveryReceipts: NSObject {
    public lazy var receipts: XMPPMessageDeliveryReceipts = {
        let receipts = XMPPMessageDeliveryReceipts(dispatchQueue: DispatchQueue.main)
        receipts?.autoSendMessageDeliveryReceipts = true
        receipts?.autoSendMessageDeliveryRequests = true
        return receipts!
    }()
    
    public func setup(connection:XMPPClientConnection) {
        connection.activate(module: receipts)
    }
    
    public func teardown() {
        receipts.deactivate()
    }
}
