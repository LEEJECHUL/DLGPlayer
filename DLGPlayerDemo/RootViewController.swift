//
//  RootViewController.swift
//  DLGPlayerDemo
//
//  Created by KWANG HYOUN KIM on 07/12/2018.
//  Copyright © 2018 KWANG HYOUN KIM. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {
    
    @IBOutlet private weak var coverView: UIView?
    @IBOutlet private weak var muteButton: UIButton!
    @IBOutlet private weak var playOrPauseButton: UIButton!
    @IBOutlet private weak var segmentedControl: UISegmentedControl!
    
    private var isFirstViewAppearance = true
    private var playerViewController1: DLGSimplePlayerViewController? {
        didSet {
            playerViewController1.map {
                $0.delegate = self
                $0.isAllowsFrameDrop = true
                $0.isAutoplay = true
//                $0.isMute = true
                $0.preventFromScreenLock = true
                $0.restorePlayAfterAppEnterForeground = true
                $0.minBufferDuration = 0
                $0.maxBufferDuration = 3
            }
        }
    }
    private var playerViewController2: DLGSimplePlayerViewController? {
        didSet {
            playerViewController2.map {
                $0.delegate = self
                $0.isAllowsFrameDrop = true
                $0.isAutoplay = true
                //                $0.isMute = true
                $0.preventFromScreenLock = true
                $0.restorePlayAfterAppEnterForeground = true
                $0.minBufferDuration = 0
                $0.maxBufferDuration = 3
            }
        }
    }
    
    deinit {
        print("deinit")
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        for i in 0..<segmentedControl.numberOfSegments {
            segmentedControl.setWidth(50, forSegmentAt: i)
        }
        
        DLGPlayerUtils.setDebugEnabled(true)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        playRTMP1()
//        playRTMP2()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        isFirstViewAppearance = false
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        playerViewController1?.stop()
        playerViewController2?.stop()
        coverView?.isHidden = false
    }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.navigationController?.isNavigationBarHidden = UIDevice.current.orientation.isLandscape
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.destination {
        case let vc as DLGSimplePlayerViewController:
            if playerViewController1 == nil {
                playerViewController1 = vc
            } else {
                playerViewController2 = vc
            }
        default: ()
        }
    }
    
    // MARK: - Play Test
    
    private func playDownload1() {
        playerViewController1?.url = "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4"
        playerViewController1?.open()
    }
    private func playDownload2() {
        playerViewController2?.url = "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4"
        playerViewController2?.open()
    }
    private func playRTMP1() {
        playerViewController1?.url = "rtmps://devmedia010.toastcam.com:10082/flvplayback/AAAAAACQLV?token=b6e503e4-f47c-4238-baca-51cbdfc10001"
        playerViewController1?.open()
    }
    private func playRTMP2() {
        playerViewController2?.url = "rtmps://devmedia010.toastcam.com:10082/flvplayback/AAAAAACYMJ?token=b6e503e4-f47c-4238-baca-51cbdfc10001&time=1571796156306&speed=\(playerViewController1?.speed ?? 1)"
        playerViewController2?.open()
    }
    
    // MARK: - Hard Test
    
    private let hardTestCount: Int = 10
    private var playCount: Int = 0
    private func startHardTest() {
        if #available(iOS 10.0, *), playCount < hardTestCount {
            var count = 0
            
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
                self.playTest(0)
                count += 1
                
                if count > self.hardTestCount {
                    $0.invalidate()
                }
            }
        }
    }
    private func playTest(_ count: Int) {
        let url = count % 2 == 0 ?
            "rtmps://devmedia011.toastcam.com:10082/flvplayback/AAAAAACPUS?token=1234567890" :
        "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4"
        
        playerViewController1?.stop()
        playerViewController2?.stop()
        
        playerViewController1?.url = url
        playerViewController1?.open()
        
        playerViewController2?.url = url
        playerViewController2?.open()
    }
    
    // MARK: - Private Selectors
    
    @IBAction private func captureButtonClicked() {
        playerViewController1?.player.snapshot()
            .map { UIImageView(image: $0) }
            .map { [weak self] in
                self?.view.addSubview($0)
                $0.frame = .init(x: 0, y: 100, width: 160, height: 90)
        }
    }
    @IBAction private func muteButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        playerViewController1?.isMute = !sender.isSelected
        playerViewController2?.isMute = !sender.isSelected
    }
    @IBAction private func playOrPauseButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        if sender.isSelected {
            if playerViewController1?.status == .paused {
                playerViewController1?.play()
            } else {
                playRTMP1()
            }
        } else {
            playerViewController1?.pause()
        }
    }
    @IBAction private func refreshButtonClicked(_ sender: UIButton) {
        playerViewController1?.stop()
        playerViewController2?.stop()
        playRTMP1()
        playRTMP2()
    }
    @IBAction private func stopButtonClicked() {
        playerViewController1?.stop()
        playerViewController2?.stop()
    }
    @IBAction private func valueChanged(_ sender: UISlider) {
        playerViewController1?.player.brightness = sender.value
        playerViewController2?.player.brightness = sender.value
    }
    @IBAction private func segmentValueChanged(_ sender: UISegmentedControl) {
        playerViewController1?.stop()
        playerViewController1?.speed = Double(1 << sender.selectedSegmentIndex)
        playRTMP1()
    }
}

extension RootViewController: DLGSimplePlayerViewControllerDelegate {
    func didBeginRender(in viewController: DLGSimplePlayerViewController) {
//        print("didBeginRender -> ", viewController.url)
        coverView?.isHidden = true
    }
    func viewController(_ viewController: DLGSimplePlayerViewController, didReceiveError error: Error) {
//        print("didReceiveError -> ", error)
    }
    func viewController(_ viewController: DLGSimplePlayerViewController, didChange status: DLGPlayerStatus) {
//        print("didChange", viewController.hash, status.stringValue)
        playOrPauseButton.isSelected = viewController.controlStatus.playing
        muteButton.isSelected = !viewController.isMute
    }
}

extension DLGPlayerStatus {
    var stringValue: String {
        switch self {
        case .buffering:
            return "buffering"
        case .closed:
            return "closed"
        case .closing:
            return "closing"
        case .EOF:
            return "EOF"
        case .none:
            return "none"
        case .opened:
            return "opened"
        case .opening:
            return "opening"
        case .paused:
            return "paused"
        case .playing:
            return "playing"
        }
    }
}
