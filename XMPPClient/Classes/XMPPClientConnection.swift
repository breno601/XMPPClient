//
//  XMPPClientConnection.swift
//  Pods
//
//  Created by Ali Gangji on 6/18/16.
//
//  This class handles setting up the XMPP connection.
//  1. create instance
//      let connection = XMPPClientConnection()
//  2. set delegate
//      connection.delegate = self
//  3. add modules
//      connection.activate(capabilities)
//      connection.activate(archiving)
//  4. connect
//      connection.connect("user@domain.com", "password")
//
//

import Foundation
import XMPPFramework

@objc public protocol XMPPClientConnectionDelegate {
    @objc optional func xmppConnection(sender: XMPPStream!, socketDidConnect socket: GCDAsyncSocket!)
    @objc optional func xmppConnectionDidConnect(sender: XMPPStream)
    @objc optional func xmppConnectionDidAuthenticate(sender: XMPPStream)
    @objc optional func xmppConnection(sender: XMPPStream, didNotAuthenticate error: DDXMLElement)
    @objc optional func xmppConnectionDidDisconnect(sender: XMPPStream, withError error: NSError)
}

public class XMPPClientConnection: NSObject {
    
    lazy var stream:XMPPStream = {
        
        let stream = XMPPStream()
        stream?.enableBackgroundingOnSocket = true
        stream?.hostName = "127.0.0.1"
        stream?.hostPort = 5222
        stream?.addDelegate(self, delegateQueue: DispatchQueue.main)
        stream?.startTLSPolicy = XMPPStreamStartTLSPolicy.required;
        self.reconnect.activate(stream)
        
        return stream!
    }()
    
    lazy var reconnect:XMPPReconnect = {
        return XMPPReconnect()
    }()
    
    public var delegate:XMPPClientConnectionDelegate?
    var password:String?
    
    public var customCertEvaluation = true
    
    public func connect(username username:String, password:String) {
        if (isConnected()) {
            delegate?.xmppConnectionDidConnect?(sender: stream)
        } else {
            stream.myJID = XMPPJID(string: username)
            self.password = password
            // TODO Threat errors from trying to connect to set behaviour
            try! stream.connect(withTimeout: XMPPStreamTimeoutNone)
        }
    }
    
    public func disconnect() {
        goOffline()
        stream.disconnect()
    }
    
    public func isConnected() -> Bool {
        return stream.isConnected()
    }
    
    public func getStream() -> XMPPStream {
        return stream
    }
    
    public func activate(module:XMPPModule) {
        module.activate(stream)
    }
    
    public func send(element:DDXMLElement!) {
        stream.send(element)
    }
    
    public func goOnline() {
        let presence = XMPPPresence()
        let domain = stream.myJID.domain
        
        if domain == "gmail.com" || domain == "gtalk.com" || domain == "talk.google.com" {
            let priority: DDXMLElement = DDXMLElement(name: "priority", stringValue: "24")
            presence?.addChild(priority)
        }

        send(element: presence)
    }
    
    public func goOffline() {
        var _ = XMPPPresence(type: "unavailable")
    }

}

// MARK: XMPPStreamDelegate

extension XMPPClientConnection: XMPPStreamDelegate {
    
    public func xmppStream(_ sender: XMPPStream!, socketDidConnect socket: GCDAsyncSocket!) {
        delegate?.xmppConnection!(sender: sender, socketDidConnect: socket)
    }
    
    public func xmppStream(_ sender: XMPPStream!, willSecureWithSettings settings: NSMutableDictionary?) {
        let expectedCertName: String? = sender.myJID.domain
        
        if expectedCertName != nil {
            settings?[kCFStreamSSLPeerName as String] = expectedCertName
        }
        if customCertEvaluation {
            settings?[GCDAsyncSocketManuallyEvaluateTrust] = true
        }
    }
    
    /**
     * Allows a delegate to hook into the TLS handshake and manually validate the peer it's connecting to.
     *
     * This is only called if the stream is secured with settings that include:
     * - GCDAsyncSocketManuallyEvaluateTrust == YES
     * That is, if a delegate implements xmppStream:willSecureWithSettings:, and plugs in that key/value pair.
     *
     * Thus this delegate method is forwarding the TLS evaluation callback from the underlying GCDAsyncSocket.
     *
     * Typically the delegate will use SecTrustEvaluate (and related functions) to properly validate the peer.
     *
     * Note from Apple's documentation:
     *   Because [SecTrustEvaluate] might look on the network for certificates in the certificate chain,
     *   [it] might block while attempting network access. You should never call it from your main thread;
     *   call it only from within a function running on a dispatch queue or on a separate thread.
     *
     * This is why this method uses a completionHandler block rather than a normal return value.
     * The idea is that you should be performing SecTrustEvaluate on a background thread.
     * The completionHandler block is thread-safe, and may be invoked from a background queue/thread.
     * It is safe to invoke the completionHandler block even if the socket has been closed.
     *
     * Keep in mind that you can do all kinds of cool stuff here.
     * For example:
     *
     * If your development server is using a self-signed certificate,
     * then you could embed info about the self-signed cert within your app, and use this callback to ensure that
     * you're actually connecting to the expected dev server.
     *
     * Also, you could present certificates that don't pass SecTrustEvaluate to the client.
     * That is, if SecTrustEvaluate comes back with problems, you could invoke the completionHandler with NO,
     * and then ask the client if the cert can be trusted. This is similar to how most browsers act.
     *
     * Generally, only one delegate should implement this method.
     * However, if multiple delegates implement this method, then the first to invoke the completionHandler "wins".
     * And subsequent invocations of the completionHandler are ignored.
     **/
    
    //func xmppStream(_ sender: XMPPStream, didReceive trust: SecTrust, completionHandler: ((Bool) -> Void)!) {
        
        
    //}
    
    
    public func xmppStream(_ sender: XMPPStream, didReceive trust: SecTrust, completionHandler: ((Bool) -> Void)!) {
        let queue = DispatchQueue(label: "pim.chat")
        queue.async {
            () -> Void in
            var result: SecTrustResultType = SecTrustResultType.deny
            let status = SecTrustEvaluate(trust, &result)
            
            if status == noErr {
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
        
    }
    
    /*func xmppStream(_ sender: XMPPStream, didReceiveTrust trust: SecTrust, completionHandler:
        @escaping (_ shouldTrustPeer: Bool?) -> Void) {
        
        print("Did receive thing called...")
        
        let bgQueue = DispatchQueue(label: "archive.pim")
        
        
        bgQueue.async {
            () -> Void in
            var result: SecTrustResultType = SecTrustResultType.deny
            let status = SecTrustEvaluate(trust, &result)
            
            if status == noErr {
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    }
 */
    
    public func xmppStreamDidSecure(_ sender: XMPPStream!) {
        //did secure
    }
    
    public func xmppStreamDidConnect(_ sender: XMPPStream!) {
        delegate?.xmppConnectionDidConnect?(sender: sender)
        do {
            try stream.authenticate(withPassword: password)
        } catch _ {
            //Handle error
        }
    }
    
    public func xmppStreamDidAuthenticate(_ sender: XMPPStream!) {
        delegate?.xmppConnectionDidAuthenticate?(sender: sender)
        goOnline()
    }
    
    public func xmppStream(_ sender: XMPPStream!, didNotAuthenticate error: DDXMLElement) {
        delegate?.xmppConnection!(sender: sender, didNotAuthenticate: error)
    }
    
    public func xmppStreamDidDisconnect(_ sender: XMPPStream!, withError error: NSError) {
        delegate?.xmppConnectionDidDisconnect?(sender: sender, withError: error)
    }
}
