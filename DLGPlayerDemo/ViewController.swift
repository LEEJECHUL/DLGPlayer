//
//  ViewController.swift
//  DLGPlayerDemo
//
//  Created by KWANG HYOUN KIM on 07/12/2018.
//  Copyright © 2018 KWANG HYOUN KIM. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    private var timer: Timer?
    private var playerViewController: DLGSimplePlayerViewController! {
        didSet {
            playerViewController.delegate = self
            playerViewController.isAutoplay = true
            playerViewController.isMute = true
            playerViewController.preventFromScreenLock = true
            playerViewController.restorePlayAfterAppEnterForeground = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerViewController.url = "rtmps://devmedia011.toastcam.com:10082/flvplayback/AAAAAACNZM?token=1234567890"
        playerViewController.minBufferDuration = 1
        playerViewController.open()
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.destination {
        case let vc as DLGSimplePlayerViewController:
            playerViewController = vc
        default: ()
        }
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
        print("player.position", playerViewController.player?.position ?? 0)
    }
    
    @IBAction private func captureButtonClicked() {
        playerViewController.player?.snapshot()
            .map { UIImageView(image: $0) }
            .map { [weak self] in
                self?.view.addSubview($0)
        }
    }
    @IBAction private func muteButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        playerViewController.isMute = sender.isSelected
    }
    @IBAction private func valueChanged(_ sender: UISlider) {
        playerViewController.player?.brightness = sender.value
    }
}

extension ViewController: DLGSimplePlayerViewControllerDelegate {
    func viewController(_ viewController: DLGSimplePlayerViewController, didReceiveError error: Error) {
        print("didReceiveError", error)
    }
    func viewController(_ viewController: DLGSimplePlayerViewController, didChange status: DLGPlayerStatus) {
        print("didChange", status.rawValue)
        
        switch status {
        case .opened:
            startTimer()
        case .closed:
            stopTimer()
        default: ()
        }
    }
}
