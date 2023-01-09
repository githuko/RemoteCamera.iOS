import UIKit
//import FirebaseCore
//import FirebaseMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application (_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [ UIApplication.LaunchOptionsKey: Any ]? ) -> Bool {
//        FirebaseApp.configure ()

        let fm = FileManager.default
        let documentsPath = NSSearchPathForDirectoriesInDomains ( .documentDirectory, .userDomainMask, true ) [ 0 ] as String

        do {
            let items = try fm.contentsOfDirectory ( atPath: documentsPath )

            for item in items {
                do {
                    try fm.removeItem ( atPath: documentsPath + "/" + item )
                } catch {}
            }
        } catch {}

        return true
    }
}
