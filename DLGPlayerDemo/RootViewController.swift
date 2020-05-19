//
//  RootViewController.swift
//  DLGPlayerDemo
//
//  Created by KWANG HYOUN KIM on 07/12/2018.
//  Copyright © 2018 KWANG HYOUN KIM. All rights reserved.
//

import UIKit

final class RootViewController: UIViewController {
    
    @IBOutlet private weak var containerView: UIView!
    @IBOutlet private weak var muteButton: UIButton!
    @IBOutlet private weak var playOrPauseButton: UIButton!
    @IBOutlet private weak var segmentedControl: UISegmentedControl!
    
    private lazy var players = [DLGSimplePlayerViewController]()
    
    private var isFirstViewAppearance = true
    
    deinit {
        print("RootViewController deinit")
        navigationItem.rightBarButtonItem = nil
    }

    private func createPlayers() {
        for i in 0..<1 {
            let pv = DLGSimplePlayerViewController()
            pv.view.translatesAutoresizingMaskIntoConstraints = true
            pv.delegate = self
            pv.isAllowsFrameDrop = true
            pv.isAutoplay = true
//            pv.isMute = true
            pv.preventFromScreenLock = true
            pv.restorePlayAfterAppEnterForeground = true
            pv.minBufferDuration = 0
            pv.maxBufferDuration = 3
            pv.view.backgroundColor = .red
            
            addChild(pv)
            
            let height = 9 * containerView.frame.width / 16
            
            pv.view.frame = .init(x: 0, y: height * CGFloat(i), width: containerView.frame.width, height: height)
            containerView.addSubview(pv.view)
            players.append(pv)
        }
    }
    private func removePlayers() {
        players.forEach {
            $0.stop()
            $0.removeFromParent()
            $0.view.removeFromSuperview()
        }
        players.removeAll()
    }
    private func playAll() {
        players.forEach {
            $0.url = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
//            $0.url = "rtmps://devmedia010.toastcam.com:10082/flvplayback/AAAAAADIQF?token=b6e503e4-f47c-4238-baca-51cbdfc10001"
            $0.open()
        }
    }
    private func reset() {
        removePlayers()
        createPlayers()
        playAll()
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
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        isFirstViewAppearance = false
        
        reset()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        removePlayers()
    }
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        navigationController?.isNavigationBarHidden = UIDevice.current.orientation.isLandscape
    }
    
    // MARK: - Private Selectors
    
    @IBAction private func captureButtonClicked() {
//        playerViewController?.player.snapshot()
//            .map { UIImageView(image: $0) }
//            .map { [weak self] in
//                self?.view.addSubview($0)
//                $0.frame = .init(x: 0, y: 100, width: 160, height: 90)
//        }
    }
    @IBAction private func muteButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
//        playerViewController?.isMute = !sender.isSelected
    }
    @IBAction private func playOrPauseButtonClicked(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        let vc = players.first
        
        if sender.isSelected {
            vc?.play()
        } else {
            vc?.pause()
        }
    }
    @IBAction private func refreshButtonClicked(_ sender: UIButton) {
    }
    
    private var isPlaying = true
    @IBAction private func stopButtonClicked() {
        guard let vc = players.first else {
            return
        }
        
        if isPlaying {
            vc.player.closeAudio()
        } else {
            vc.stop()
            vc.url = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
            vc.open()
        }
        
        isPlaying = !isPlaying
        
        if #available(iOS 10.0, *) {
            Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.stopButtonClicked()
            }
        } else {
            // Fallback on earlier versions
        }
    }
    @IBAction private func valueChanged(_ sender: UISlider) {
    }
    @IBAction private func segmentValueChanged(_ sender: UISegmentedControl) {
    }
}

extension RootViewController: DLGSimplePlayerViewControllerDelegate {
    func didBeginRender(in viewController: DLGSimplePlayerViewController) {
//        print("didBeginRender -> ", viewController.url)
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
        case .audioClosed:
            return "audioClosed"
        case .closing:
            return "closing"
        case .EOF:
            return "EOF"
        case .none:
            return "none"
        case .opened:
            return "opened"
        case .audioOpened:
            return "audioOpened"
        case .opening:
            return "opening"
        case .paused:
            return "paused"
        case .playing:
            return "playing"
        }
    }
}
