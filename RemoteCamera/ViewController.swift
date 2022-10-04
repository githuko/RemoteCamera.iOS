import UIKit
import AVFoundation
import Photos


class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, CLLocationManagerDelegate {
    //MARK:- Vars
    private var mCaptureSession : AVCaptureSession!
    private var mBackCamera : AVCaptureDevice!
    private var mBackInput : AVCaptureInput!
    private var mPreviewLayer : AVCaptureVideoPreviewLayer!
    private var mVideoOutput : AVCaptureMovieFileOutput!
    private var mBackCameraOn = true
    private var mSessionSetupSucceeds = false
    private var mZoomScaleRange: ClosedRange < CGFloat > = 0.5 ... 10.0
    private var mInitialScale: CGFloat = 4.0
    private var mDateFormatter = DateFormatter ()
    private var mFilename: String = ""
    private var mBaseUrl: String = "http://185.69.247.114:8000"
    private var mLocalNotificationBar = UILabel ( frame: CGRect ( x: 0, y: 0, width: 200, height: 41 ) )
    private var mRemoteNotificationBar = UILabel ( frame: CGRect ( x: 0, y: 0, width: 200, height: 41 ) )
    private var misHttpFinished = false
    private var mCmd: String!
    private var mLocationManager = CLLocationManager ()

    // CLLocationManagerDelegate
    private func locationManager ( manager: CLLocationManager, didUpdateLocations locations: [ CLLocation ] ) {}

    // AVCaptureFileOutputRecordingDelegate
    func fileOutput ( _ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [ AVCaptureConnection ], error: Error? ) {
        if ( error == nil ) {
            mLocalNotificationBar.textColor = UIColor.white
            mLocalNotificationBar.text = mFilename
            UISaveVideoAtPathToSavedPhotosAlbum ( outputFileURL.path, nil, nil, nil )
        }
    }
    
    func httpRequest ( _cmd: String ) {
        let lUrl = URL ( string: mBaseUrl + "/" + _cmd )!
        let lTask = URLSession.shared.dataTask ( with: lUrl ) { data, response, error in

            guard
                error == nil,
                let lData = data,
                let lString = String ( data: lData, encoding: .utf8 )
            else {
                DispatchQueue.main.async {
                    self.mRemoteNotificationBar.text = _cmd + " FAILED"
                    self.mRemoteNotificationBar.textColor = UIColor.red
                }
                return
            }

            if ( lString == "OK" ) {
                DispatchQueue.main.async {
                    self.mRemoteNotificationBar.text = _cmd + " SUCCESS"
                    self.mRemoteNotificationBar.textColor = UIColor.white
                }
            } else { //} if ( lString.hasSuffix ( "%" ) ) {
                DispatchQueue.main.async {
                    self.mRemoteNotificationBar.text = _cmd + " " + lString
                    self.mRemoteNotificationBar.textColor = UIColor.white
                }
            }
        }

        lTask.resume ()
    }

    func getCurrentDate () -> String {
        mDateFormatter.dateFormat = "yyyy_MM_dd-HHmmss"
        return mDateFormatter.string ( from: Date () )
    }

    // MARK: - Actions
    @objc func handleLongPress ( _ sender: UILongPressGestureRecognizer ) {
        switch sender.state {
            case .began:
                mRemoteNotificationBar.text = ""
                mRemoteNotificationBar.textColor = UIColor.white

                if ( mFilename == "" ) {
                    mFilename = getCurrentDate ()
                }
                FileDownloader.downloadVideo ( _remoteUrlString: mBaseUrl + "/get", _filename: mFilename + ".MP4" )
            case .changed:
                return
            default:
                return
        }
    }

    @objc func handleTap ( _ sender: UITapGestureRecognizer ) {
        mRemoteNotificationBar.text = ""
        mRemoteNotificationBar.textColor = UIColor.white

        if ( mVideoOutput.isRecording ) {
            httpRequest ( _cmd: "stop" )

            mVideoOutput.stopRecording ()
        } else {
            httpRequest ( _cmd: "start" )
            mLocalNotificationBar.textColor = UIColor.red
            mLocalNotificationBar.text = "recording"
            mFilename = getCurrentDate () + ".MOV"
            let lLocation = mLocationManager.location
            let lPaths = FileManager.default.urls ( for: .documentDirectory, in: .userDomainMask )
            let lFileUrl = lPaths [ 0 ].appendingPathComponent ( mFilename )
            var lMetadata: [ AVMutableMetadataItem ] = []

            let lLocation_metadata = AVMutableMetadataItem ()
            lLocation_metadata.keySpace = AVMetadataKeySpace.quickTimeMetadata
            lLocation_metadata.key = AVMetadataKey.quickTimeMetadataKeyLocationISO6709 as NSString
            lLocation_metadata.identifier = AVMetadataIdentifier.quickTimeMetadataLocationISO6709
            lLocation_metadata.value = String ( format: "%+09.5f%+010.5f%+.0fCRSWGS_84", lLocation!.coordinate.latitude, lLocation!.coordinate.longitude, lLocation!.altitude ) as NSString

            let lCdate_metadata = AVMutableMetadataItem ()
            lCdate_metadata.key = AVMetadataKey.quickTimeMetadataKeyCreationDate as NSString
            lCdate_metadata.identifier = AVMetadataIdentifier.quickTimeMetadataCreationDate
            
            let lFormatter = ISO8601DateFormatter ()
            lFormatter.timeZone = TimeZone.current
            lFormatter.formatOptions.remove ( .withColonSeparatorInTimeZone ) // iOS camera output format
            lCdate_metadata.value = lFormatter.string ( from: Date () )  as NSString

            lMetadata.append ( lLocation_metadata )
            lMetadata.append ( lCdate_metadata )

            mVideoOutput.metadata = lMetadata
            mVideoOutput.startRecording ( to: lFileUrl, recordingDelegate: self as AVCaptureFileOutputRecordingDelegate )
        }
    }

    @objc func handlePan ( _ sender: UIPanGestureRecognizer ) {
        switch sender.state {
            case .began:
                return
            case .changed:
                return
            default:
                return
        }
    }

    @objc func handlePinch ( _ sender: UIPinchGestureRecognizer ) {
        switch sender.state {
        case .began:
            mInitialScale = mBackCamera.videoZoomFactor
        case .changed:
            let lMinAvailableZoomScale = mBackCamera.minAvailableVideoZoomFactor
            let lMaxAvailableZoomScale = mBackCamera.maxAvailableVideoZoomFactor
            let lAvailableZoomScaleRange = lMinAvailableZoomScale...lMaxAvailableZoomScale
            let lResolvedZoomScaleRange = mZoomScaleRange.clamped ( to: lAvailableZoomScaleRange )

            let lResolvedScale = max ( lResolvedZoomScaleRange.lowerBound, min ( sender.scale * mInitialScale, lResolvedZoomScaleRange.upperBound ) )

            do {
                try mBackCamera.lockForConfiguration ()
                mBackCamera.videoZoomFactor = lResolvedScale
            } catch {
                return
            }

            mBackCamera.unlockForConfiguration ()
        default:
            return
        }
    }

    //MARK:- Life Cycle
    override func viewDidLoad () {
        super.viewDidLoad ()
        setupView ()
        
        if ( CLLocationManager.locationServicesEnabled () ) {
            mLocationManager.delegate = self
            mLocationManager.desiredAccuracy = kCLLocationAccuracyBest
            mLocationManager.requestAlwaysAuthorization ()
            mLocationManager.startUpdatingLocation ()
        }

        mLocalNotificationBar.textAlignment = NSTextAlignment.center
        mLocalNotificationBar.translatesAutoresizingMaskIntoConstraints = false

        mRemoteNotificationBar.textAlignment = NSTextAlignment.center
        mRemoteNotificationBar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview ( mLocalNotificationBar )
        view.addSubview ( mRemoteNotificationBar )
        mLocalNotificationBar.layer.zPosition = 1;
        mRemoteNotificationBar.layer.zPosition = 1;

        NSLayoutConstraint.activate ( [
            mLocalNotificationBar.centerXAnchor.constraint ( equalTo: view.safeAreaLayoutGuide.centerXAnchor ),
            mLocalNotificationBar.bottomAnchor.constraint ( equalTo: view.safeAreaLayoutGuide.bottomAnchor ),
            mRemoteNotificationBar.centerXAnchor.constraint ( equalTo: view.safeAreaLayoutGuide.centerXAnchor ),
            mRemoteNotificationBar.bottomAnchor.constraint ( equalTo: view.safeAreaLayoutGuide.topAnchor )
            ] )

        let lTapGestureRecognizer = UITapGestureRecognizer ( target: self, action: #selector ( handleTap ( _: ) ) )
        view.addGestureRecognizer ( lTapGestureRecognizer )

        let lPanGestureRecognizer = UIPanGestureRecognizer ( target: self, action: #selector ( handlePan ( _: ) ) )
        view.addGestureRecognizer ( lPanGestureRecognizer )
        
        let lPinchGestureRecognizer = UIPinchGestureRecognizer ( target: self, action: #selector ( handlePinch ( _: ) ) )
        view.addGestureRecognizer ( lPinchGestureRecognizer )

        let lLongPressGestureRecognizer = UILongPressGestureRecognizer ( target: self, action: #selector ( handleLongPress ( _: ) ) )
        view.addGestureRecognizer ( lLongPressGestureRecognizer )
        
        NotificationCenter.default.addObserver ( self, selector: #selector ( videoDownloaded ), name: Notification.Name ( "downloadVideo" ), object: nil )

        registerSettingsBundle ()
        NotificationCenter.default.addObserver ( self, selector: #selector ( defaultsChanged ), name: UserDefaults.didChangeNotification, object: nil )
        defaultsChanged ()
    }

    func registerSettingsBundle () {
        let lAppDefaults = [ String:AnyObject ] ()
        UserDefaults.standard.register ( defaults: lAppDefaults )
    }

    @objc func defaultsChanged () {
        let lRemoteURL = UserDefaults.standard.string ( forKey: "pref_remoteUrl" )

        if ( ( lRemoteURL != nil ) && ( lRemoteURL != "" ) ) {
            mBaseUrl = lRemoteURL!
        }
    }

    @objc func videoDownloaded ( _ notification: Notification ) {
        let lResult = notification.userInfo? [ "result" ] as? String

        if ( lResult == "SUCCESS" ) {
            DispatchQueue.main.async {
                self.mRemoteNotificationBar.textColor = UIColor.white
                self.mRemoteNotificationBar.text = "download SUCCESS"
            }
        } else {
            DispatchQueue.main.async {
                self.mRemoteNotificationBar.textColor = UIColor.red
                self.mRemoteNotificationBar.text = "download " + ( lResult ?? "unknown" )
            }
        }
    }

    override func viewDidAppear ( _ animated: Bool ) {
        super.viewDidAppear ( animated )
        checkPermissions ()
        setupAndStartCaptureSession ()
    }
    
    //MARK:- Camera Setup
    func setupAndStartCaptureSession () {
        DispatchQueue.global ( qos: .userInitiated ).async {
            //init session
            self.mCaptureSession = AVCaptureSession ()
            //start configuration
            self.mCaptureSession.beginConfiguration ()
            
            //session specific configuration
            if self.mCaptureSession.canSetSessionPreset ( .hd4K3840x2160 ) {
                self.mCaptureSession.sessionPreset = .hd4K3840x2160
            }

            self.mCaptureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
            
            //setup inputs
            self.setupInputs ()
            
            DispatchQueue.main.async {
                //setup preview layer
                self.setupPreviewLayer ()
            }
            
            //setup output
            self.setupOutput ()
            
            //commit configuration
            self.mCaptureSession.commitConfiguration ()
            //start running it
            self.mCaptureSession.startRunning ()
        }
    }
    
    func setupInputs () {
        //get back camera
        if let lDevice = AVCaptureDevice.default ( .builtInTripleCamera, for: .video, position: .back ) {
            mBackCamera = lDevice
        } else {
            //handle this appropriately for production purposes
            fatalError ( "no back camera" )
        }

        //now we need to create an input objects from our devices
        guard let lBInput = try? AVCaptureDeviceInput ( device: mBackCamera ) else {
            fatalError ( "could not create input device from back camera" )
        }
        mBackInput = lBInput
        if !mCaptureSession.canAddInput ( mBackInput ) {
            fatalError ( "could not add back camera input to capture session" )
        }
        configureCameraForHighestFrameRate ( _device: mBackCamera )

        //connect back camera input to session
        mCaptureSession.addInput ( mBackInput )
    }
    
    func configureCameraForHighestFrameRate ( _device: AVCaptureDevice ) {
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?

        for format in _device.formats {
            for range in format.videoSupportedFrameRateRanges {

                if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                    bestFormat = format
                    bestFrameRateRange = range
                }
            }
        }

        if let bestFormat = bestFormat,
           let bestFrameRateRange = bestFrameRateRange {
            do {
                try _device.lockForConfiguration()

                _device.activeFormat = bestFormat
                let supporrtedFrameRanges = mBackCamera.activeFormat.videoSupportedFrameRateRanges.first
                mBackCamera.activeVideoMinFrameDuration = supporrtedFrameRanges?.minFrameDuration ?? bestFrameRateRange.minFrameDuration
                mBackCamera.activeVideoMaxFrameDuration = supporrtedFrameRanges?.maxFrameDuration ?? bestFrameRateRange.maxFrameDuration

                _device.unlockForConfiguration ()
            } catch {}
        }
    }

    func setupOutput () {
        mVideoOutput = AVCaptureMovieFileOutput ()
        
        if mCaptureSession.canAddOutput ( mVideoOutput ) {
            mCaptureSession.addOutput ( mVideoOutput )
        } else {
            fatalError ( "could not add video output" )
        }
        
        mVideoOutput.connections.first?.videoOrientation = .portrait
        
        if ( mVideoOutput.connections.first?.isVideoStabilizationSupported )! {
            mVideoOutput.connections.first?.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.cinematicExtended
        }
    }
    
    func setupPreviewLayer () {
        mPreviewLayer = AVCaptureVideoPreviewLayer ( session: mCaptureSession )
        mPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        view.layer.addSublayer ( mPreviewLayer )
        mPreviewLayer.frame = self.view.layer.frame
    }
}
