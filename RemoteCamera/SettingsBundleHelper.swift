import Foundation
class SettingsBundleHelper {
    struct SettingsBundleKeys {
        static let remoteURL = "pref_remoteURL"
        static let bitRate = "pref_bitRate"
        static let BuildVersionKey = "pref_build"
        static let AppVersionKey = "pref_version"

    }
    class func checkAndExecuteSettings () {
        UserDefaults.standard.set ( "", forKey: SettingsBundleKeys.remoteURL )
        UserDefaults.standard.set ( 8000000, forKey: SettingsBundleKeys.bitRate )

        let appDomain: String? = Bundle.main.bundleIdentifier
        UserDefaults.standard.removePersistentDomain ( forName: appDomain! )
    }
    
    class func setVersionAndBuildNumber () {
        let version: String = Bundle.main.object ( forInfoDictionaryKey: "CFBundleShortVersionString" ) as! String
        UserDefaults.standard.set ( version, forKey: "pref_version" )
        let build: String = Bundle.main.object ( forInfoDictionaryKey: "CFBundleVersion" ) as! String
        UserDefaults.standard.set ( build, forKey: "pref_build" )
    }
}
