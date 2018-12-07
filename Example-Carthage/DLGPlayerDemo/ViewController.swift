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
        
        playerViewController.url = "/path/to/video"
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
        print("player.position", playerViewController.player.position)
    }
}

extension ViewController: DLGSimplePlayerViewControllerDelegate {
    func viewController(_ viewController: DLGSimplePlayerViewController, didReceiveError error: Error) {
        print("didReceiveError", error)
    }
    func viewController(_ viewController: DLGSimplePlayerViewController, didChange status: DLGPlayerStatus) {
        print("didChange", status)
        
        switch status {
        case .opened:
            startTimer()
        case .closed:
            stopTimer()
        default: ()
        }
    }
}
