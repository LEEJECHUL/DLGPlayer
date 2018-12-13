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
            playerViewController.autoplay = true
            playerViewController.repeat = true
            playerViewController.preventFromScreenLock = true
            playerViewController.restorePlayAfterAppEnterForeground = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerViewController.url = "rtmps://devmedia011.toastcam.com:10082/flvplayback/AAAAAACNZM?token=1234567890"
        playerViewController.player.minBufferDuration = 1
        playerViewController.player.audio.volume = 1
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
//        print("player.position", playerViewController.player.position)
    }
    
    @IBAction private func valueChanged(_ sender: UISlider) {
        playerViewController.player.brightness = sender.value
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
//        case .playing:
//            print("player.audio.volume", playerViewController.player.audio.volume)
        default: ()
        }
    }
}
