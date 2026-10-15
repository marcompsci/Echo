import Foundation

// MARK: - Error Doctor: what Echo already knows
//
// Instant, on-device answers for the iPhone errors people hit most — the same
// everyday iOS know-how Apple Intelligence has, written out so Echo can explain
// an error the moment it sees it (even offline). An AI then adds detail for
// anything unusual.

nonisolated enum FixAction: Hashable, Sendable, Codable {
    case freeUpStorage                 // Echo's Photo & File Cleanup
    case organizeFiles
    case openEchoSettings              // Echo's page in the Settings app (permissions)
    case liveGuide(goal: String)       // Echo watches your screen and walks you through it
    case openLink(title: String, url: String)
    case remindLater(String)

    var title: String {
        switch self {
        case .freeUpStorage:       return "Find big photos, videos & screenshots to clear (you pick what goes)"
        case .organizeFiles:       return "Sort and clean up your files"
        case .openEchoSettings:    return "Open Settings to Echo's permissions"
        case .liveGuide(let goal): return "Walk you through it live: \(goal)"
        case .openLink(let title, _): return title
        case .remindLater(let what): return "Remind you later: \(what)"
        }
    }

    var icon: String {
        switch self {
        case .freeUpStorage:  return "internaldrive"
        case .organizeFiles:  return "folder.badge.gearshape"
        case .openEchoSettings: return "gear"
        case .liveGuide:      return "dot.radiowaves.left.and.right"
        case .openLink:       return "safari"
        case .remindLater:    return "bell"
        }
    }
}

nonisolated struct ErrorDiagnosis: Sendable, Equatable {
    var title: String
    var cause: String
    var steps: [String]
    var fixes: [FixAction]
    var source: String           // "Echo's knowledge", "Apple Intelligence", "Claude"…
    var errorText: String
}

nonisolated struct KnownError: Sendable {
    let id: String
    let anyOf: [String]          // any one of these phrases (lowercased) on screen
    let alsoNeeds: [String]      // and, if not empty, one of these too
    let title: String
    let cause: String
    let steps: [String]
    let fixes: [FixAction]

    func matches(_ screen: String) -> Bool {
        anyOf.contains(where: screen.contains) && (alsoNeeds.isEmpty || alsoNeeds.contains(where: screen.contains))
    }
}

nonisolated enum ErrorKnowledge {

    static func match(_ screenText: String) -> KnownError? {
        let screen = screenText.lowercased()
        return all.first { $0.matches(screen) }
    }

    static let all: [KnownError] = [
        KnownError(id: "storage-full", anyOf: ["storage almost full", "storage full", "not enough storage", "iphone storage", "cannot be downloaded because there is not enough", "out of space"], alsoNeeds: [],
                   title: "Your iPhone is out of space",
                   cause: "There isn't enough free storage for what you tried to do, so iOS stopped it.",
                   steps: ["Delete big videos and old screenshots you don't need.", "Empty Photos → Recently Deleted to free the space right away.", "Settings → General → iPhone Storage shows which apps use the most."],
                   fixes: [.freeUpStorage, .liveGuide(goal: "Open Settings → General → iPhone Storage and offload apps I don't use")]),
        KnownError(id: "untrusted-developer", anyOf: ["untrusted developer", "developer app certificate is not trusted", "untrusted enterprise developer"], alsoNeeds: [],
                   title: "The app's developer isn't trusted yet",
                   cause: "This app was installed from Xcode or a company profile, and iOS needs you to trust the developer once before it opens.",
                   steps: ["Open Settings → General → VPN & Device Management.", "Tap the developer's name under Developer App.", "Tap Trust, then open the app again."],
                   fixes: [.liveGuide(goal: "Trust the developer in Settings → General → VPN & Device Management")]),
        KnownError(id: "developer-mode", anyOf: ["developer mode required", "requires developer mode", "developer mode is disabled"], alsoNeeds: [],
                   title: "Developer Mode is off",
                   cause: "Apps installed from Xcode only run when Developer Mode is turned on.",
                   steps: ["Settings → Privacy & Security → Developer Mode.", "Turn it on and restart when asked.", "After restart, tap Turn On, then enter your passcode."],
                   fixes: [.liveGuide(goal: "Turn on Developer Mode in Settings → Privacy & Security")]),
        KnownError(id: "no-internet", anyOf: ["not connected to the internet", "no internet connection", "you are offline", "you're offline", "network connection was lost", "cannot connect to server", "the internet connection appears to be offline"], alsoNeeds: [],
                   title: "No internet connection",
                   cause: "Your iPhone can't reach the internet right now — Wi-Fi or cellular is off, weak, or blocked for this app.",
                   steps: ["Open Control Center and check Wi-Fi and Cellular are on and Airplane Mode is off.", "Try a different Wi-Fi network or move closer to the router.", "Settings → Cellular: make sure this app is allowed to use cellular data."],
                   fixes: [.liveGuide(goal: "Check Wi-Fi, Airplane Mode and Cellular data for this app")]),
        KnownError(id: "wifi-password", anyOf: ["incorrect password", "unable to join the network", "unable to join"], alsoNeeds: ["wi-fi", "wifi", "network", "join"],
                   title: "Couldn't join the Wi-Fi network",
                   cause: "The Wi-Fi password was wrong or the router rejected the connection.",
                   steps: ["Re-type the password carefully (it's case-sensitive).", "Tap the (i) next to the network → Forget This Network, then join again.", "Restart the router if other devices can't connect either."],
                   fixes: [.liveGuide(goal: "Forget this Wi-Fi network and join it again")]),
        KnownError(id: "server-identity", anyOf: ["cannot verify server identity", "this connection is not private", "certificate is not valid", "not secure"], alsoNeeds: [],
                   title: "The connection might not be safe",
                   cause: "The website or mail server's security certificate didn't check out. This can be a wrong date/time on your phone, a public Wi-Fi login page, or a fake site.",
                   steps: ["Don't enter passwords or card numbers on this page.", "Check Settings → General → Date & Time is set automatically.", "If you're on public Wi-Fi, open any website to finish the Wi-Fi sign-in, then try again."],
                   fixes: [.liveGuide(goal: "Turn on Set Automatically in Settings → General → Date & Time")]),
        KnownError(id: "apple-id-verify", anyOf: ["verification failed", "apple account verification", "apple id verification", "your apple account has been locked", "your apple id has been locked", "this apple account has been disabled"], alsoNeeds: [],
                   title: "Apple Account sign-in problem",
                   cause: "Apple couldn't verify your account — often a changed password, a security lock after too many tries, or a network hiccup.",
                   steps: ["Go to Settings → your name and sign in again.", "If it says locked, reset your password at account.apple.com.", "Never give your code to someone who calls or texts you — Apple won't ask."],
                   fixes: [.openLink(title: "Open account.apple.com to unlock or reset", url: "https://account.apple.com"), .liveGuide(goal: "Sign in again in Settings → my name")]),
        KnownError(id: "payment", anyOf: ["payment method was declined", "billing problem", "payment declined", "card was declined", "unable to complete purchase", "there is a billing problem"], alsoNeeds: [],
                   title: "A payment didn't go through",
                   cause: "The card on your account was declined or expired, so App Store or subscription charges failed.",
                   steps: ["Settings → your name → Payment & Shipping, then update or add a card.", "Check that the card's address and expiration date are right.", "Echo never buys or pays for anything — you stay in control of every purchase."],
                   fixes: [.liveGuide(goal: "Open Settings → my name → Payment & Shipping")]),
        KnownError(id: "update-failed", anyOf: ["unable to install update", "software update failed", "unable to check for update", "update requested", "an error occurred installing ios"], alsoNeeds: [],
                   title: "The iOS update didn't install",
                   cause: "Usually not enough free space, a weak connection, or low battery during the update.",
                   steps: ["Free up at least 6–8 GB of storage.", "Connect to Wi-Fi and plug in your charger.", "Settings → General → Software Update and try again."],
                   fixes: [.freeUpStorage, .liveGuide(goal: "Retry Settings → General → Software Update")]),
        KnownError(id: "permission-denied", anyOf: ["doesn't have access", "does not have access", "permission denied", "access denied", "allow access", "turn on in settings", "would like to access"], alsoNeeds: ["photos", "camera", "microphone", "contacts", "location", "speech", "calendar", "reminders"],
                   title: "An app is missing a permission",
                   cause: "The app was told “Don't Allow” for something it needs, like Photos, Camera or the microphone.",
                   steps: ["Open Settings, scroll to the app, and turn the permission on.", "Then go back to the app and try again."],
                   fixes: [.openEchoSettings, .liveGuide(goal: "Find this app in Settings and turn on the permission it needs")]),
        KnownError(id: "app-crash", anyOf: ["has stopped working", "unexpectedly quit", "keeps crashing", "something went wrong", "an unexpected error"], alsoNeeds: [],
                   title: "The app ran into a problem",
                   cause: "A temporary glitch, an out-of-date app, or bad cached data made it fail.",
                   steps: ["Swipe the app away from the app switcher and open it again.", "Update it in the App Store.", "If it keeps happening, restart your iPhone."],
                   fixes: [.openLink(title: "Open App Store updates", url: "itms-apps://apps.apple.com/account/updates")]),
        KnownError(id: "sim", anyOf: ["no sim", "sim not supported", "invalid sim", "sim failure", "sos only"], alsoNeeds: [],
                   title: "Problem with your SIM / cellular service",
                   cause: "Your iPhone can't find a working SIM or carrier signal.",
                   steps: ["Turn Airplane Mode on for 10 seconds, then off.", "Restart your iPhone.", "Settings → Cellular: check your line is on. If it still fails, contact your carrier."],
                   fixes: [.liveGuide(goal: "Check my cellular line in Settings → Cellular")]),
        KnownError(id: "icloud-full", anyOf: ["icloud storage is full", "not enough icloud storage", "icloud storage full", "cannot be backed up"], alsoNeeds: [],
                   title: "iCloud is full",
                   cause: "Your iCloud plan has no room left, so backups and photo syncing stopped.",
                   steps: ["Settings → your name → iCloud → Manage Storage.", "Delete old backups or big items you don't need.", "Or choose a bigger iCloud plan (only you can buy one)."],
                   fixes: [.freeUpStorage, .liveGuide(goal: "Open Settings → my name → iCloud → Manage Storage")]),
        KnownError(id: "bluetooth", anyOf: ["pairing unsuccessful", "connection unsuccessful", "unable to pair", "bluetooth pairing"], alsoNeeds: [],
                   title: "Bluetooth couldn't connect",
                   cause: "The accessory isn't in pairing mode, is connected to another device, or the old pairing is stuck.",
                   steps: ["Put the accessory in pairing mode (see its manual).", "Settings → Bluetooth → (i) → Forget This Device, then pair again.", "Turn Bluetooth off and on."],
                   fixes: [.liveGuide(goal: "Forget and re-pair this Bluetooth device")]),
        KnownError(id: "face-id", anyOf: ["face id is not available", "face id has been disabled", "unable to activate face id"], alsoNeeds: [],
                   title: "Face ID isn't working",
                   cause: "The TrueDepth camera is covered, blocked, or Face ID needs to be set up again.",
                   steps: ["Clean the top of the screen and remove anything covering it.", "Restart your iPhone.", "Settings → Face ID & Passcode → Reset Face ID and set it up again."],
                   fixes: [.liveGuide(goal: "Reset and set up Face ID again")]),
        KnownError(id: "mail", anyOf: ["cannot get mail", "cannot send mail", "the user name or password", "is incorrect"], alsoNeeds: ["mail", "imap", "smtp", "account"],
                   title: "Mail can't sign in to your account",
                   cause: "The email password changed, or the provider needs an app password.",
                   steps: ["Settings → Apps → Mail → Mail Accounts, choose the account and re-enter the password.", "Gmail/Outlook: remove and add the account again to sign in fresh."],
                   fixes: [.liveGuide(goal: "Re-enter my email password in Settings → Apps → Mail → Mail Accounts")]),
        KnownError(id: "not-available-region", anyOf: ["not available in your country", "not available in your region", "isn't available in your country"], alsoNeeds: [],
                   title: "Not available where you are",
                   cause: "The app or feature is limited by country, based on your Apple Account region.",
                   steps: ["Check Settings → your name → Media & Purchases → View Account → Country/Region.", "Look for an alternative app available in your region."],
                   fixes: []),
        KnownError(id: "screen-time", anyOf: ["time limit", "you've reached your limit", "content restrictions", "screen time"], alsoNeeds: ["limit", "restrict", "ask for more"],
                   title: "Screen Time is blocking this",
                   cause: "A Screen Time limit or content restriction is on for this app or website.",
                   steps: ["Tap Ask for More Time or enter the Screen Time passcode.", "Settings → Screen Time → App Limits to change it."],
                   fixes: [.liveGuide(goal: "Change the limit in Settings → Screen Time → App Limits")]),
        KnownError(id: "xcode-signing", anyOf: ["signing for", "requires a development team", "provisioning profile", "no profiles for", "code signing"], alsoNeeds: [],
                   title: "Xcode code-signing error",
                   cause: "The app target doesn't have a signing team or matching provisioning profile.",
                   steps: ["In Xcode select the target → Signing & Capabilities.", "Turn on Automatically manage signing and pick your Team.", "Make sure the Bundle Identifier is unique, then build again."],
                   fixes: []),
        KnownError(id: "http-401", anyOf: ["401", "unauthorized", "invalid api key", "invalid x-api-key", "authentication failed"], alsoNeeds: ["error", "key", "unauthorized", "auth"],
                   title: "Sign-in or API key rejected",
                   cause: "The server didn't accept the login or API key — it's wrong, expired, or was reset.",
                   steps: ["Sign out and sign back in, or paste a fresh API key.", "Check there are no extra spaces in the key.", "If it's your own server, update the key in its settings/secrets and redeploy."],
                   fixes: []),
    ]
}
