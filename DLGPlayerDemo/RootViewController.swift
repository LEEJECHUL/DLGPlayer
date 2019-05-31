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
    
    private var isFirstViewAppearance = true
    private var playerViewController: DLGSimplePlayerViewController? {
        didSet {
            playerViewController.map {
                $0.delegate = self
                $0.isAutoplay = true
                $0.isMute = true
                $0.preventFromScreenLock = true
                $0.restorePlayAfterAppEnterForeground = true
                $0.minBufferDuration = 0
                $0.maxBufferDuration = 2
            }
        }
    }
    
    deinit {
        
        
        print("deinit")
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        navigationItem.leftBarButtonItem = .init(title: "close", style: .plain, target: self, action: #selector(leftBarButtonItemClicked))
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        if isFirstViewAppearance {
            playRTMP()
//        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        isFirstViewAppearance = false
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        playerViewController?.close()
        coverView?.isHidden = false
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.destination {
        case let vc as DLGSimplePlayerViewController:
            playerViewController = vc
        default: ()
        }
    }
    
    // MARK: - Play Test
    
    private func playDownload() {
        playerViewController?.url = "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4"
        playerViewController?.open()
    }
    private func playRTMP() {
        playerViewController?.url = "rtmps://devmedia011.toastcam.com:10082/flvplayback/AAAAAACPUS?token=1234567890"
        playerViewController?.open()
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
        
        playerViewController?.close()
        
//        print("[playTest] ------------------------------------------------------------------------------------")
//        print("[playTest] will open -> ", url)
        playerViewController?.url = url
        playerViewController?.open()
//        print("[playTest] opening -> ", playerViewController?.url)
    }
    
    // MARK: - Private Selectors
    
    @IBAction private func captureButtonClicked() {
        playerViewController?.player.snapshot()
            .map { UIImageView(image: $0) }
            .map { [weak self] in
                self?.view.addSubview($0)
        }
    }
    @IBAction private func muteButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        playerViewController?.isMute = !sender.isSelected
    }
    @IBAction private func playOrPauseButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        if sender.isSelected {
            if playerViewController?.status == .paused {
                playerViewController?.play()
            } else {
                playRTMP()
            }
        } else {
            playerViewController?.pause()
        }
    }
    @IBAction private func refreshButtonClicked(_ sender: UIButton) {
        playerViewController?.close()
        playRTMP()
    }
    @IBAction private func stopButtonClicked() {
        playerViewController?.close()
    }
    @IBAction private func valueChanged(_ sender: UISlider) {
        playerViewController?.player.brightness = sender.value
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
