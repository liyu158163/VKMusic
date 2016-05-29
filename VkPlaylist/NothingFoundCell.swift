//
//  NothingFoundCell.swift
//  VkPlaylist
//
//  Created by Илья Халяпин on 02.05.16.
//  Copyright © 2016 Ilya Khalyapin. All rights reserved.
//

import UIKit

class NothingFoundCell: UITableViewCell {

    @IBOutlet weak var messageLabel: UILabel!
    
    override func prepareForReuse() {
        messageLabel.text = nil
    }
    
}
