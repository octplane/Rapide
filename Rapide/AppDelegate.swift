//
//  AppDelegate.swift
//  Rapide
//
//  Created by Pierre Baillet on 11/06/2014.
//  Copyright (c) 2014 Pierre Baillet. All rights reserved.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, NSStreamDelegate, NSTextFieldDelegate {
                            
    @IBOutlet var window :NSWindow!
    @IBOutlet var clipView :NSClipView!
    @IBOutlet var textView: NSTextView!
    @IBOutlet var tf :NSTextField!

    var inputStream :NSInputStream?
    var outputStream :NSOutputStream?
    var lineRemain :String = ""
    
    let nickname :String = "SpectreMan_"

    var server :CFString = "irc.freenode.org"
    var port :UInt32 = 6667
    var ircPassword :String? = nil
    var motto :String = "Plus rapide qu'un missile !"
    var channel :String = "#swift-test"
    
    
    enum ConnectionStatus: Int {
        case Disconnected, BeforePassword, BeforeNick, BeforeUser, AfterUser, Connected
        func toString() -> String {
            switch self {
            case .Disconnected:
                return "Disconnected"
            case .BeforePassword:
                return "Before Password"
            case .BeforeNick:
                return "Before Nick Setting"
            case .BeforeUser:
                return "Before User Setting"
            case .AfterUser:
                return "After User Setting"
            case .Connected:
                return "Connected"
            }
        }
    }
    
    var status :ConnectionStatus = ConnectionStatus.Disconnected
    
    
    func get<T>(input: T?, orElse: T) -> T {
        if let i = input? {
            return i
        }
        return orElse
    }
    
    func getI(input: String?, orElse: UInt32) -> UInt32 {
        if let i = input?.toInt() {
            return UInt32(i)
        }
        return orElse
    }
    
    func applicationDidFinishLaunching(aNotification: NSNotification?) {
        
        
        let pi =  NSProcessInfo.processInfo()
        
        server = get(pi.environment["server"] as? String, orElse: server as String)
        port = getI(pi.environment["port"] as? String, orElse: port)
        ircPassword = pi.environment["password"] as? String
        channel = get(pi.environment["channel"] as? String, orElse: channel)
        
        println("Connecting to \(server):\(port) and joining \(channel)")
        
        
        var readStream :Unmanaged<CFReadStream>?
        var writeStream  :Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(nil, server, 6667, &readStream, &writeStream)
        
        self.inputStream = readStream!.takeUnretainedValue()
        self.outputStream = writeStream!.takeUnretainedValue()
        
        self.inputStream!.delegate = self
        self.outputStream!.delegate = self
        
        self.inputStream!.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        self.outputStream!.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        
        self.inputStream!.open()
        self.outputStream!.open()
    }
    
    
    func stream(aStream: NSStream!, handleEvent eventCode: NSStreamEvent){
        
        var msg :String = ""
        
        switch eventCode {
        case NSStreamEvent.HasBytesAvailable:
            if aStream == self.inputStream {
                var data = [UInt8](count: 4096, repeatedValue: 0)
                let read = self.inputStream!.read(&data, maxLength: 4096)
                let strData = NSString(bytes: data, length: read, encoding: NSUTF8StringEncoding)
                handleInput(strData!)
            }

        case NSStreamEvent.HasSpaceAvailable:
            if aStream == self.outputStream {
                msg = "Can write bytes"
                handleCommunication()
            } else {
                msg = "Can write on inputStream ??!"
            }
        case NSStreamEvent.OpenCompleted:
            msg = "Open has completed"
            self.status = ConnectionStatus.BeforePassword
        case NSStreamEvent.ErrorOccurred:
            msg = "Something wrong happened..."
        default:
            msg = "Something happened !"
        }
    }

    func applicationWillTerminate(aNotification: NSNotification?) {
        // Insert code here to tear down your application
    }
    
    func handleInput(input :String) {
        var lines: [String] = split(input) { $0 == "\r\n" }
        // what's remaining to process
        if lines.count > 0 {
            lines[0] = lineRemain + lines[0]
        } else {
            lines = [lineRemain]
        }

        lineRemain = lines[lines.count - 1]
        let parsable = lines[0...(lines.count-1)]
        
        for (line) in parsable {
            let parts = line.componentsSeparatedByString(" ")

            println(line)
            textView.insertText( line + "\n" )

            let from = parts[0]
            let code = parts[1]
            if from == "PING" {
                sendMessage("PONG \(code)")
            } else if parts.count > 2 {
                let dest = parts[2]
                let rest = " ".join(parts[3...(parts.count - 1)])

                if code == "JOIN" {
                    let chan = dest.substringFromIndex(advance(dest.startIndex,1))
                    sendMessage("PRIVMSG \(chan) :\(motto)")
                }
                if code == "PRIVMSG" {
                    if rest.rangeOfString("ping", options: nil, range: nil, locale: nil) != nil {
                        sendMessage("PRIVMSG \(dest) :pong.")
                    }
                    if rest.rangeOfString("king", options: nil, range: nil, locale: nil) != nil {
                        sendMessage("PRIVMSG \(dest) :kong.")
                    }
                }
            }
        }
    }

    func handleCommunication() {
        switch self.status {
            
        case ConnectionStatus.BeforePassword:
            if ircPassword != nil {
                sendMessage("PASS \(ircPassword)")
            }
            println("PASS or not.")
            status = ConnectionStatus.BeforeNick
//        case ConnectionStatus.BeforeNick:
            println("Sending Nick")
            let msg = "NICK \(nickname)"
            sendMessage(msg)
            status = ConnectionStatus.BeforeUser
    
//        case ConnectionStatus.BeforeUser:
            println("Sending USER info")
            sendMessage("USER \(nickname) localhost servername Rapido Bot")
            status = ConnectionStatus.AfterUser
            
        case ConnectionStatus.AfterUser:
            println("JOINing")
            sendMessage("JOIN \(channel)")
            status = ConnectionStatus.Connected
        default:
            let c = 1
        }
    }
    
    func sendMessage(msg: String) -> Int {
        let message = msg + "\r\n"
        let l = message.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        var data = [UInt8](count: l, repeatedValue: 0)
        let r:Range = message.startIndex...(message.endIndex.predecessor())
        
        let ret:Bool = message.getBytes(&data, maxLength: l, usedLength: nil, encoding: NSUTF8StringEncoding, options: nil, range: r, remainingRange: nil)
        
        return self.outputStream!.write(data, maxLength: l)

    }
    
    
    override func controlTextDidEndEditing(notif :NSNotification) {
        if notif.object as NSObject == tf {
            sendMessage("PRIVMSG \(channel) :"+tf.stringValue)
        }
    }

}

