//
//  ViewController.swift
//  DLGPlayerDemo
//
//  Created by KWANG HYOUN KIM on 05/12/2019.
//  Copyright © 2019 KWANG HYOUN KIM. All rights reserved.
//

import Foundation

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "RootViewController") else {
            return
        }
        
        navigationController?.pushViewController(vc, animated: false)
    }
    
}
