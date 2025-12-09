//
//  Logger.swift
//  OralableForProfessionals
//
//  Simple logger for OralableForProfessionals app
//

import Foundation

final class Logger {
    static let shared = Logger()

    private init() {}

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        print("🔍 DEBUG [\(sourceInfo(file: file, function: function, line: line))]: \(message)")
        #endif
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        print("ℹ️ INFO [\(sourceInfo(file: file, function: function, line: line))]: \(message)")
        #endif
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        print("⚠️ WARNING [\(sourceInfo(file: file, function: function, line: line))]: \(message)")
        #endif
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        print("❌ ERROR [\(sourceInfo(file: file, function: function, line: line))]: \(message)")
        #endif
    }

    private func sourceInfo(file: String, function: String, line: Int) -> String {
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let cleanFunction = function.components(separatedBy: "(").first ?? function
        return "\(fileName).\(cleanFunction):\(line)"
    }
}
