import Foundation
import Photos
import CoreServices

class FileDownloader {
    static func downloadVideo ( _remoteUrlString : String, _filename : String ) {
        DispatchQueue.main.async {
            let l_remoteUrl = URL ( string: _remoteUrlString )
            let l_remoteUrlData = NSData ( contentsOf: l_remoteUrl! )


            if ( l_remoteUrlData == nil ) {
                NotificationCenter.default.post ( name: Notification.Name ( "downloadVideo" ), object: nil, userInfo: [ "result" : "failed" ] )
                return
            }

            let l_localPath = NSSearchPathForDirectoriesInDomains ( .documentDirectory, .userDomainMask, true ) [ 0 ];
            let l_localFilePath = "\( l_localPath )/\( _filename )"

            DispatchQueue.main.async {
                l_remoteUrlData!.write ( toFile: l_localFilePath, atomically: true )
/*
 2022_05_26-081755
 */
                let lAsset = AVURLAsset ( url: URL ( fileURLWithPath: l_localFilePath ) )
//                let lMetadata = lAsset.metadata
                let lAllFormats = lAsset.availableMetadataFormats

                lAllFormats.forEach {
                    let lMetadataItems = lAsset.metadata ( forFormat: $0 )
                    lMetadataItems.forEach {
                        print ( "key: \( $0.key! )" )
                        print ( "data: \( $0.value! )" )
                        print ( "---------" )
                    }
                }
/**/
                PHPhotoLibrary.shared ().performChanges ( {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo ( atFileURL: URL ( fileURLWithPath: l_localFilePath ) )
                } ) { completed, error in
                    if completed {
                        NotificationCenter.default.post ( name: Notification.Name ( "downloadVideo" ), object: nil, userInfo: [ "result" : "SUCCESS" ] )


                    } else {
                        NotificationCenter.default.post ( name: Notification.Name ( "downloadVideo" ), object: nil, userInfo: [ "result" : "failed" ] )
                    }
                }
            }
        }
    }
}
