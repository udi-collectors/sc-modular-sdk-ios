//
//  Logger.swift
//  ModularSDK
//
//

import OSLog

class Logger {

    static func log(_ message: String, type: OSLogType) {
        os_log("ModularSDK: %@", log: .default, type: type, message)
    }

}
