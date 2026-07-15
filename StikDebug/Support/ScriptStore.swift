//
//  ScriptStore.swift
//  StikDebug
//

import Foundation

struct ScriptResource {
    let resourceName: String
    let fileName: String
}

enum ScriptStore {
    static let directoryName = "scripts"
    static let assignmentKey = UserDefaults.Keys.bundleScriptMap
    static let favoriteAppNamesSuiteName = "group.com.stik.sj"
    static let favoriteAppNamesKey = "favoriteAppNames"
    static let defaultScriptName = UserDefaults.Keys.defaultScriptNameValue
    static let bundledResources: [ScriptResource] = [
        ScriptResource(resourceName: "maciOS", fileName: "maciOS.js"),
        ScriptResource(resourceName: "universal", fileName: "universal.js"),
        ScriptResource(resourceName: "Geode", fileName: "Geode.js"),
        ScriptResource(resourceName: "UTM-Dolphin", fileName: "UTM-Dolphin.js")
    ]

    static var directoryURL: URL {
        URL.documentsDirectory.appendingPathComponent(directoryName)
    }

    @discardableResult
    static func prepareDirectory(fileManager: FileManager = .default) throws -> URL {
        let directory = directoryURL
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory)

        if exists && !isDirectory.boolValue {
            try fileManager.removeItem(at: directory)
        }

        if !exists || !isDirectory.boolValue {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        try ensureBundledScripts(in: directory, fileManager: fileManager)
        return directory
    }

    static func scriptURL(named scriptName: String, fileManager: FileManager = .default) throws -> URL {
        guard let scriptName = normalizedScriptFileName(scriptName) else {
            throw CocoaError(.fileReadInvalidFileName)
        }

        let directory = try prepareDirectory(fileManager: fileManager)
        return directory.appendingPathComponent(scriptName)
    }

    static func assignedScriptName(for bundleID: String, defaults: UserDefaults = .standard) -> String? {
        assignedScriptMap(defaults: defaults)[bundleID]
    }

    static func updateAssignedScriptName(_ scriptName: String?, for bundleID: String, defaults: UserDefaults = .standard) {
        var mapping = assignedScriptMap(defaults: defaults)
        if let scriptName, let normalizedName = normalizedScriptFileName(scriptName) {
            mapping[bundleID] = normalizedName
        } else {
            mapping.removeValue(forKey: bundleID)
        }
        defaults.set(mapping, forKey: assignmentKey)
    }

    static func preferredScript(for bundleID: String, fileManager: FileManager = .default) -> (data: Data, name: String)? {
        assignedScript(for: bundleID, fileManager: fileManager) ?? autoScript(for: bundleID, fileManager: fileManager)
    }

    /// The JIT script to run when holding an app alive in the background.
    ///
    /// On a TXM device (iOS 26+) JIT is serviced by handling `brk #0xf00d`
    /// syscalls, so an app that is merely attached — with no script servicing
    /// those traps — hangs the moment it requests executable memory. That is
    /// why keep-alive "didn't work for any app": only apps whose name/bundle
    /// matched an assigned or auto script got a callback. Fall back to the
    /// bundled universal script so *any* app has its JIT traps serviced (and,
    /// for non-JIT apps, its debug connection actively held) while alive.
    ///
    /// Returns `nil` on non-TXM devices, where JIT comes from `CS_DEBUGGED`
    /// alone and a plain attach is enough to hold the app.
    static func keepAliveScript(for bundleID: String, fileManager: FileManager = .default) -> (data: Data, name: String)? {
        guard ProcessInfo.processInfo.hasTXM else {
            return nil
        }

        if let preferred = preferredScript(for: bundleID, fileManager: fileManager) {
            return preferred
        }

        return bundledScript(resourceName: "universal", fileName: "universal.js")
    }

    /// Reads a bundled script straight from the app bundle (not the user's
    /// scripts directory). Used for the keep-alive fallback so the current
    /// shipped script — which supports `should_continue()` cancellation — is
    /// always used, even for users whose documents copy predates it.
    private static func bundledScript(resourceName: String, fileName: String) -> (data: Data, name: String)? {
        guard let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: "js"),
              let data = try? Data(contentsOf: bundleURL) else {
            return nil
        }

        return (data, fileName)
    }

    static func favoriteAppName(
        for bundleID: String,
        defaults: UserDefaults? = UserDefaults(suiteName: favoriteAppNamesSuiteName)
    ) -> String? {
        let names = defaults?.dictionary(forKey: favoriteAppNamesKey) as? [String: String]
        return names?[bundleID]
    }

    static func normalizedScriptFileName(_ candidate: String) -> String? {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              !trimmed.contains("\0") else {
            return nil
        }

        let fileName = URL(fileURLWithPath: trimmed).lastPathComponent
        guard fileName == trimmed,
              fileName != ".",
              fileName != "..",
              URL(fileURLWithPath: fileName).pathExtension.lowercased() == "js" else {
            return nil
        }

        return fileName
    }

    private static func ensureBundledScripts(in directory: URL, fileManager: FileManager) throws {
        for resource in bundledResources {
            guard let bundleURL = Bundle.main.url(forResource: resource.resourceName, withExtension: "js") else {
                continue
            }

            let destination = directory.appendingPathComponent(resource.fileName)
            if !fileManager.fileExists(atPath: destination.path) {
                try fileManager.copyItem(at: bundleURL, to: destination)
            }
        }
    }

    private static func assignedScript(for bundleID: String, fileManager: FileManager) -> (data: Data, name: String)? {
        guard let scriptName = assignedScriptName(for: bundleID),
              let scriptURL = try? scriptURL(named: scriptName, fileManager: fileManager),
              let data = try? Data(contentsOf: scriptURL) else {
            return nil
        }

        return (data, scriptName)
    }

    private static func autoScript(for bundleID: String, fileManager: FileManager) -> (data: Data, name: String)? {
        guard ProcessInfo.processInfo.hasTXM else {
            return nil
        }
        guard #available(iOS 26, *) else {
            return nil
        }

        let appName = (try? JITEnableContext.shared.getAppList()[bundleID]) ?? favoriteAppName(for: bundleID)
        guard let appName,
              let resource = autoScriptResource(for: appName) else {
            return nil
        }

        if let scriptURL = try? scriptURL(named: resource.fileName, fileManager: fileManager),
           let data = try? Data(contentsOf: scriptURL) {
            return (data, resource.fileName)
        }

        guard let bundleURL = Bundle.main.url(forResource: resource.resourceName, withExtension: "js"),
              let data = try? Data(contentsOf: bundleURL) else {
            return nil
        }

        return (data, resource.fileName)
    }

    private static func assignedScriptMap(defaults: UserDefaults) -> [String: String] {
        let rawMap = defaults.dictionary(forKey: assignmentKey) as? [String: String] ?? [:]
        return rawMap.compactMapValues(normalizedScriptFileName)
    }
}
