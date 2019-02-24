import UIKit
import TagListView_ObjC
import MBProgressHUD
import PopupDialog
import main
import BrightcovePlayerSDK

let kViewControllerPlaybackServicePolicyKey = "BCpkADawqM3n0ImwKortQqSZCgJMcyVbb8lJVwt0z16UD0a_h8MpEYcHyKbM8CGOPxBRp0nfSVdfokXBrUu3Sso7Nujv3dnLo0JxC_lNXCl88O7NJ0PR0z2AprnJ_Lwnq7nTcy1GBUrQPr5e"
let kViewControllerAccountID = "4800266849001"
let kViewControllerVideoID = "5255514387001"

class SessionViewController : UIViewController, SessionDetailsView {

    private let repository = AppDelegate.me.konfService
    private lazy var presenter: SessionDetailsPresenter = {
        SessionDetailsPresenter(
            uiContext: UI() as! KotlinCoroutineContext,
            view: self,
            sessionId: sessionId,
            repository: repository
        )
    }()
    
    var sessionId = ""

    @IBOutlet private weak var scrollView: UIScrollView!
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var timeLabel: UILabel!
    @IBOutlet private weak var tagsLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    
    @IBOutlet private weak var headerView: UIView!
    @IBOutlet private weak var userNameStackView: UIStackView!
    @IBOutlet private weak var userNamesLabel: UILabel!
    @IBOutlet private weak var userIcon1: UIImageView!
    @IBOutlet private weak var userIcon2: UIImageView!
    
    @IBOutlet private weak var favoriteButton: UIBarButtonItem!

    @IBOutlet private weak var sessionForm: UIView!
    @IBOutlet private weak var goodButton: UIButton!
    @IBOutlet private weak var sosoButton: UIButton!
    @IBOutlet private weak var badButton: UIButton!
    
    @IBOutlet private weak var videoContainerView: UIView!
    
    let sharedSDKManager = BCOVPlayerSDKManager.shared()
    let playbackService = BCOVPlaybackService(accountId: kViewControllerAccountID, policyKey: kViewControllerPlaybackServicePolicyKey)
    let playbackController :BCOVPlaybackController
    
    required init?(coder aDecoder: NSCoder) {
        playbackController = (sharedSDKManager?.createPlaybackController())!
        
        super.init(coder: aDecoder)
        
        playbackController.delegate = self
        playbackController.isAutoAdvance = true
        playbackController.isAutoPlay = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBrightcovePlayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        presenter.onCreate()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        presenter.onDestroy()
    }
    
    func updateView(isFavorite: Bool, session: SessionModel) {
        titleLabel.text = session.title
        
        let startsAt = session.startsAt
        let endsAt = session.endsAt
        
        if (startsAt != nil && endsAt != nil) {
            timeLabel.text = KotlinPair(first: startsAt, second: endsAt).toReadableString()
        }
        
        let image = UIImage(named: isFavorite ? "star_full" : "star_empty")!
        favoriteButton.image = image
        
        let description = session.descriptionText
        descriptionLabel.text = description

        let tags: [String] = [session.room, session.category]
            .compactMap { $0 } // To remove nil
        tagsLabel.text = tags.joined(separator: ", ")

        setupSpeakers(speakers: session.speakers)
    }
    
    func setupRatingButtons(rating: SessionRating?) {
        let buttons: [SessionRating: UIButton] = [
            .good: goodButton,
            .ok: sosoButton,
            .bad: badButton
        ]

        for (buttonRating, button) in buttons {
            button.backgroundColor = (buttonRating == rating)
                ? UIColor.orange
                : UIColor.groupTableViewBackground
        }
    }
    
    func setRatingClickable(clickable: Bool) {
        // TODO: This is a temporary click block to not let user make more than one voting at the time because anotherone would remove first one
    }

    @IBAction private func favorited(_ sender: Any) {
        presenter.onFavoriteButtonClicked()
    }
    
    @IBAction private func goodPressed(_ sender: Any?) {
        presenter.rateSessionClicked(newRating: .good)
    }
    
    @IBAction private func sosoPressed(_ sender: Any?) {
        presenter.rateSessionClicked(newRating: .ok)
    }
    
    @IBAction private func badPressed(_ sender: Any?) {
        presenter.rateSessionClicked(newRating: .bad)
    }
    
    private func setupSpeakers(speakers: [Speaker]) {
        userNamesLabel.text = speakers.map { (speaker) -> String in speaker.fullName }.joined(separator: ", ")
        
        if (speakers.count == 1) {
            userIcon1.isHidden = false
            userIcon2.isHidden = true
            if (speakers[0].profilePicture != nil) {
                userIcon1.loadUserIcon(url: speakers[0].profilePicture!)
            }
        } else if (speakers.count == 2) {
            userIcon1.isHidden = false
            userIcon2.isHidden = false
            if (speakers[0].profilePicture != nil) {
                userIcon2.loadUserIcon(url: speakers[0].profilePicture!)
            }
            if (speakers[1].profilePicture != nil) {
                userIcon1.loadUserIcon(url: speakers[1].profilePicture!)
            }
        } else {
            userIcon1.isHidden = true
            userIcon2.isHidden = true
        }
    }
    
    private func showIndeterminateProgress(message: String) -> MBProgressHUD {
        let hud = MBProgressHUD(for: self.view)!
        hud.label.text = message
        hud.removeFromSuperViewOnHide = true
        self.view.addSubview(hud)
        hud.show(animated: true)
        return hud
    }
    
    private func setupBrightcovePlayer() {
        // Set up our player view. Create with a standard VOD layout.
        guard let playerView = BCOVPUIPlayerView(playbackController: self.playbackController, options: nil, controlsView: BCOVPUIBasicControlView.withVODLayout()) else {
            return
        }
        
        // Install in the container view and match its size.
        self.videoContainerView.addSubview(playerView)
        playerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: self.videoContainerView.topAnchor),
            playerView.rightAnchor.constraint(equalTo: self.videoContainerView.rightAnchor),
            playerView.leftAnchor.constraint(equalTo: self.videoContainerView.leftAnchor),
            playerView.bottomAnchor.constraint(equalTo: self.videoContainerView.bottomAnchor)
            ])
        
        // Associate the playerView with the playback controller.
        playerView.playbackController = playbackController
        
        requestContentFromPlaybackService()
    }
    
    func requestContentFromPlaybackService() {
        playbackService?.findVideo(withVideoID: kViewControllerVideoID, parameters: nil) { (video: BCOVVideo?, jsonResponse: [AnyHashable: Any]?, error: Error?) -> Void in
            
            if let v = video {
                self.playbackController.setVideos([v] as NSArray)
            } else {
                print("ViewController Debug - Error retrieving video: \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
}

extension SessionViewController: BCOVPlaybackControllerDelegate {
    func playbackController(_ controller: BCOVPlaybackController!, didAdvanceTo session: BCOVPlaybackSession!) {
        print("Advanced to new session")
    }
    
    func playbackController(_ controller: BCOVPlaybackController!, playbackSession session: BCOVPlaybackSession!, didProgressTo progress: TimeInterval) {
        print("Progress: \(progress) seconds")
    }
}
