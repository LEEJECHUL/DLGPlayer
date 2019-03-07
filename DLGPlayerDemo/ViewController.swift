//
//  ViewController.swift
//  DLGPlayerDemo
//
//  Created by KWANG HYOUN KIM on 07/12/2018.
//  Copyright © 2018 KWANG HYOUN KIM. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet private weak var coverView: UIView?
    @IBOutlet private weak var muteButton: UIButton!
    @IBOutlet private weak var playOrPauseButton: UIButton!
    
    private var timer: Timer?
    private var playerViewController: DLGSimplePlayerViewController? {
        didSet {
            playerViewController.map {
                $0.delegate = self
                $0.isAutoplay = true
                //            $0.isMute = true
                $0.preventFromScreenLock = true
                $0.restorePlayAfterAppEnterForeground = true
                $0.minBufferDuration = 0
                $0.maxBufferDuration = 2
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        playCount = 0
        play()
    }
    private func refresh() {
        playerViewController?.close()
        play()
        
        let rand1 = CGFloat(arc4random_uniform(2))
        let rand2 =  CGFloat(arc4random_uniform(3) + 1)
        let delay: TimeInterval = TimeInterval(rand1 + (1 / rand2))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.refresh()
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
//        refresh()
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            if self.coverView == nil {
//                self.navigationController?.popViewController(animated: true)
//            } else {
//                self.performSegue(withIdentifier: "NextView", sender: nil)
//            }
//        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        stopTimer()
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
    
    private func play() {
        playerViewController?.url = "rtmps://devmedia010.toastcam.com:10082/flvplayback/AAAAAACPUS?token=1234567890"
//        playerViewController?.url = "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4"
        playerViewController?.open()
    }
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timerCompletion), userInfo: nil, repeats: true)
    }
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func timerCompletion() {
        //        print("player.position", playerViewController.player.position)
    }
    
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
                play()
            }
        } else {
            playerViewController?.pause()
        }
    }
    @IBAction private func refreshButtonClicked(_ sender: UIButton) {
        playerViewController?.close()
        play()
    }
    @IBAction private func valueChanged(_ sender: UISlider) {
        playerViewController?.player.brightness = sender.value
    }
    
    private var playCount: Int = 0
}

extension ViewController: DLGSimplePlayerViewControllerDelegate {
    
    private func playTest(_ count: Int) {
        let url = count % 2 == 0 ?
            "rtmps://devmedia010.toastcam.com:10082/flvplayback/AAAAAACPUS?token=1234567890" :
        "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_1mb.mp4"
        
        playerViewController?.close()
        
        print(") ------------------------------------------------------------------------------------")
        print(") open", url)
        playerViewController?.url = url
        playerViewController?.open()
        print(") opening", playerViewController?.url)
    }
    
    
    func didBeginRender(in viewController: DLGSimplePlayerViewController) {
        coverView?.isHidden = true
//        viewController.pause()
        print(") opened", viewController.url)
        
        if #available(iOS 10.0, *), playCount < 5 {
            var count = 0
            
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
                self.playTest(count)
                count += 1
                
                if count > 5 {
                    $0.invalidate()
                }
            }
        }
    }
    func viewController(_ viewController: DLGSimplePlayerViewController, didReceiveError error: Error) {
        print("didReceiveError", error)
    }
    func viewController(_ viewController: DLGSimplePlayerViewController, didChange status: DLGPlayerStatus) {
//        print("didChange", viewController.hash, status.stringValue)
        playOrPauseButton.isSelected = viewController.controlStatus.playing
        muteButton.isSelected = !viewController.isMute
        
        switch status {
        case .opened:
            startTimer()
        case .paused,
             .closed:
            stopTimer()
        default: ()
        }
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
