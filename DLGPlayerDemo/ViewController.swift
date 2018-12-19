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
    @IBOutlet private weak var playOrPauseButton: UIButton!
    
    private var timer: Timer?
    private var playerViewController: DLGSimplePlayerViewController! {
        didSet {
            playerViewController.delegate = self
            playerViewController.isAutoplay = true
//            playerViewController.isMute = true
            playerViewController.preventFromScreenLock = true
            playerViewController.restorePlayAfterAppEnterForeground = true
            playerViewController.minBufferDuration = 1
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        play()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        stopTimer()
        playerViewController.close()
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
        playerViewController.url = "rtmps://devmedia010.toastcam.com:10082/flvplayback/AAAAAACNZM?token=1234567890"
        playerViewController.reset()
        playerViewController.open()
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
        print("player.position", playerViewController.player.position)
    }
    
    @IBAction private func captureButtonClicked() {
        playerViewController.player.snapshot()
            .map { UIImageView(image: $0) }
            .map { [weak self] in
                self?.view.addSubview($0)
        }
    }
    @IBAction private func muteButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
    }
    @IBAction private func playOrPauseButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        if sender.isSelected {
            play()
        } else {
            playerViewController.pause()
        }
    }
    @IBAction private func valueChanged(_ sender: UISlider) {
        playerViewController.player.brightness = sender.value
    }
}

extension ViewController: DLGSimplePlayerViewControllerDelegate {
    func didBeginRender(in viewController: DLGSimplePlayerViewController) {
        coverView?.isHidden = true
    }
    func viewController(_ viewController: DLGSimplePlayerViewController, didReceiveError error: Error) {
        print("didReceiveError", error)
    }
    func viewController(_ viewController: DLGSimplePlayerViewController, didChange status: DLGPlayerStatus) {
        print("didChange", viewController.hash, status.stringValue)
        playOrPauseButton.isSelected = viewController.isPlaying
        
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
