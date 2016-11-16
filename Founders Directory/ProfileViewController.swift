//
//  ProfileViewController.swift
//  Founders Directory
//
//  Created by Steve Liddle on 9/22/16.
//  Copyright © 2016 Steve Liddle. All rights reserved.
//
//  See http://bit.ly/2da8gxb for discussion of this animation pattern
//

import UIKit

class ProfileViewController : UIViewController {
    
    // MARK: - Constants
    
    struct Animation {
        static let Duration = 0.2
    }

    struct Size {
        static let InfoCellHeight: CGFloat = 200
        static let MaxFontSize: CGFloat = 15
        static let MinFontSize: CGFloat = 28
        static let MaxHeaderHeight: CGFloat = 280
        static let MinHeaderHeight: CGFloat = 166
        static let MaxImageHeight: CGFloat = 80
        static let MinImageHeight: CGFloat = 40
        static let MaxImageOffset: CGFloat = 8
        static let MinImageOffset: CGFloat = 4
        static let MaxSubtitleHeight: CGFloat = 38
        static let MinSubtitleHeight: CGFloat = 0
        // TODO: calculate from profile text size; set high currently to test scrolling
        static let ProfileCellHeight: CGFloat = 400
        static let SubtitleLineHeight: CGFloat = 19
    }
    
    struct Storyboard {
        static let InfoCellIdentifier = "InfoCell"
        static let ProfileCellIdentifier = "ProfileCell"
    }

    // MARK: - Outlets
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageOffsetConstraint: NSLayoutConstraint!
    @IBOutlet weak var subtitleHeightConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var callButton: CircleTagButton!
    @IBOutlet weak var emailButton: CircleTagButton!
    @IBOutlet weak var textButton: CircleTagButton!
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!

    // MARK: - Properties

    var founder: Founder!
    var maxHeaderHeight = Size.MaxHeaderHeight
    var maxSubtitleHeight = Size.MaxSubtitleHeight
    var minHeaderHeight = Size.MinHeaderHeight
    var minSubtitleHeight = Size.MinSubtitleHeight
    var previousScrollOffset: CGFloat = 0

    // MARK: - View controller lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        updateUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        imageView.applyCircleMask()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.makeBarTransparent()
        headerHeightConstraint.constant = maxHeaderHeight
        updateHeader()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let navVC = segue.destination as? UINavigationController {
            if let destVC = navVC.viewControllers.first as? EditProfileViewController {
                destVC.founder = founder
            }
        }
    }

    // MARK: - Helpers

    private func updateUI() {
        imageView.image = PhotoManager.shared.getPhotoFor(founderId: founder.id)
        nameLabel.text = founder.preferredFullName

        var subtitleText = ""

        if founder.preferredFirstName.length > 0 {
            subtitleText = "“\(founder.preferredFirstName)”"
        } else {
            maxHeaderHeight -= Size.SubtitleLineHeight
            maxSubtitleHeight -= Size.SubtitleLineHeight
        }

        if founder.organizationName.length > 0 {
            if subtitleText.length > 0 {
                subtitleText += "\n"
            }

            subtitleText += founder.organizationName
        } else {
            maxHeaderHeight -= Size.SubtitleLineHeight
            maxSubtitleHeight -= Size.SubtitleLineHeight
        }

        subtitleLabel.text = subtitleText

        callButton.disabled = !founder.isPhoneListed
        textButton.disabled = !founder.isPhoneListed
        emailButton.disabled = !founder.isEmailListed

        if founder.id != UserDefaults.standard.integer(forKey: SyncHelper.Constants.userIDKey) {
            navigationItem.rightBarButtonItem = nil
        } 
    }

    // MARK: - Actions

    @IBAction func callPhone(_ sender: CircleTagButton) {
        if founder.isPhoneListed && founder.cell.length > 0 {
            if let url = URL(string: "tel://\(founder.cell)") {
                UIApplication.shared.open(url)
            }
        }
    }

    @IBAction func sendEmail(_ sender: CircleTagButton) {
        if founder.isEmailListed && founder.email.length > 0 {
            if let url = URL(string: "mailto://\(founder.email)") {
                UIApplication.shared.open(url)
            }
        }
    }

    @IBAction func sendText(_ sender: CircleTagButton) {
        if founder.isPhoneListed && founder.cell.length > 0 {
            if let url = URL(string: "sms://\(founder.cell)") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    @IBAction func cancelEdit(segue: UIStoryboardSegue) {
        // Ignore
    }

    @IBAction func saveEdit(segue: UIStoryboardSegue) {
        // TODO: reload the edited Founder record
    }
}

// MARK: - Table view delegate

extension ProfileViewController : UITableViewDelegate {

    // MARK: - Scroll view delegate

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollViewDidStopScrolling()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollViewDidStopScrolling()
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let scrollDiff = scrollView.contentOffset.y - previousScrollOffset
        let absoluteTop: CGFloat = 0;
        let absoluteBottom: CGFloat = scrollView.contentSize.height - scrollView.frame.size.height;
        let isScrollingDown = scrollDiff > 0 && scrollView.contentOffset.y > absoluteTop
        let isScrollingUp = scrollDiff < 0 && scrollView.contentOffset.y < absoluteBottom

        var newHeight = headerHeightConstraint.constant

        if isScrollingDown {
            newHeight = max(Size.MinHeaderHeight, headerHeightConstraint.constant - abs(scrollDiff))
        } else if isScrollingUp {
            newHeight = min(Size.MaxHeaderHeight, headerHeightConstraint.constant + abs(scrollDiff))
        }

        if newHeight != headerHeightConstraint.constant {
            headerHeightConstraint.constant = newHeight
            updateHeader()
            setScrollPosition(position: previousScrollOffset)
        }

        previousScrollOffset = scrollView.contentOffset.y
    }

    func scrollViewDidStopScrolling() {
        let midPoint = minHeaderHeight + ((maxHeaderHeight - minHeaderHeight) / 2)

        if headerHeightConstraint.constant > midPoint {
            expandHeader()
        } else {
            collapseHeader()
        }
    }

    // MARK: - Helpers

    private func collapseHeader() {
        view.layoutIfNeeded()
        UIView.animate(withDuration: Animation.Duration) {
            self.headerHeightConstraint.constant = self.minHeaderHeight
            self.updateHeader()
            self.view.layoutIfNeeded()
        }
    }

    private func expandHeader() {
        view.layoutIfNeeded()
        UIView.animate(withDuration: Animation.Duration) {
            self.headerHeightConstraint.constant = self.maxHeaderHeight
            self.updateHeader()
            self.view.layoutIfNeeded()
        }
    }

    private func setScrollPosition(position: CGFloat) {
        tableView.contentOffset = CGPoint(x: tableView.contentOffset.x, y: position)
    }

    func updateHeader() {
        let range = maxHeaderHeight - minHeaderHeight
        let openAmount = headerHeightConstraint.constant - minHeaderHeight
        let percentage = openAmount / range

        imageHeightConstraint.constant = Size.MinImageHeight + percentage * (Size.MaxImageHeight - Size.MinImageHeight)
//        imageOffsetConstraint.constant = Size.MinImageOffset + percentage * (Size.MaxImageOffset - Size.MinImageOffset)
        subtitleHeightConstraint.constant = minSubtitleHeight + percentage * (maxSubtitleHeight - minSubtitleHeight)

        nameLabel.font = UIFont(name: ".SFUIDisplay", size: Size.MaxFontSize - percentage * (Size.MaxFontSize - Size.MinFontSize))!
        subtitleLabel.alpha = percentage
    }
}
