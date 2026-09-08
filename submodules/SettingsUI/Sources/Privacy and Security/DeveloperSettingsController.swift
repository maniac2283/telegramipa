import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import Postbox

private final class DeveloperSettingsControllerArguments {
    let toggleSpoofing: (Bool) -> Void
    let updateTarget: (String) -> Void
    let toggleChannelSpoofing: (Bool) -> Void
    let updateMyChannel: (String) -> Void
    let updateSpoofChannelAs: (String) -> Void
    let toggleFriendSpoofing: (Bool) -> Void
    let updateFriendTarget: (String) -> Void
    let updateFriendSource: (String) -> Void
    let toggleMessageSimulation: (Bool) -> Void
    let updateMessageSimulationTarget: (String) -> Void
    let updateMessageSimulationText: (String) -> Void
    let sendSimulatedText: () -> Void
    let sendSimulatedPicture: () -> Void
    let openSimulatedConversation: () -> Void
    
    init(toggleSpoofing: @escaping (Bool) -> Void, updateTarget: @escaping (String) -> Void, toggleChannelSpoofing: @escaping (Bool) -> Void, updateMyChannel: @escaping (String) -> Void, updateSpoofChannelAs: @escaping (String) -> Void, toggleFriendSpoofing: @escaping (Bool) -> Void, updateFriendTarget: @escaping (String) -> Void, updateFriendSource: @escaping (String) -> Void, toggleMessageSimulation: @escaping (Bool) -> Void, updateMessageSimulationTarget: @escaping (String) -> Void, updateMessageSimulationText: @escaping (String) -> Void, sendSimulatedText: @escaping () -> Void, sendSimulatedPicture: @escaping () -> Void, openSimulatedConversation: @escaping () -> Void) {
        self.toggleSpoofing = toggleSpoofing
        self.updateTarget = updateTarget
        self.toggleChannelSpoofing = toggleChannelSpoofing
        self.updateMyChannel = updateMyChannel
        self.updateSpoofChannelAs = updateSpoofChannelAs
        self.toggleFriendSpoofing = toggleFriendSpoofing
        self.updateFriendTarget = updateFriendTarget
        self.updateFriendSource = updateFriendSource
        self.toggleMessageSimulation = toggleMessageSimulation
        self.updateMessageSimulationTarget = updateMessageSimulationTarget
        self.updateMessageSimulationText = updateMessageSimulationText
        self.sendSimulatedText = sendSimulatedText
        self.sendSimulatedPicture = sendSimulatedPicture
        self.openSimulatedConversation = openSimulatedConversation
    }
}

private enum DeveloperSettingsSection: Int32 {
    case spoofing
    case channelSpoofing
    case friendSpoofing
    case messageSimulation
}

private enum DeveloperSettingsEntry: ItemListNodeEntry {
    case spoofingHeader(String)
    case spoofingEnabled(String, Bool)
    case spoofingTarget(String, String)
    case spoofingInfo(String)
    case channelSpoofingHeader(String)
    case channelSpoofingEnabled(String, Bool)
    case channelSpoofingMyChannel(String, String)
    case channelSpoofingAs(String, String)
    case channelSpoofingInfo(String)
    case friendSpoofingHeader(String)
    case friendSpoofingEnabled(String, Bool)
    case friendSpoofingTarget(String, String)
    case friendSpoofingSource(String, String)
    case friendSpoofingInfo(String)
    case messageSimulationHeader(String)
    case messageSimulationEnabled(String, Bool)
    case messageSimulationTarget(String, String)
    case messageSimulationText(String, String)
    case messageSimulationSendText(String)
    case messageSimulationSendPicture(String)
    case messageSimulationOpen(String)
    case messageSimulationInfo(String)
    
    var section: ItemListSectionId {
        switch self {
        case .spoofingHeader, .spoofingEnabled, .spoofingTarget, .spoofingInfo:
            return DeveloperSettingsSection.spoofing.rawValue
        case .channelSpoofingHeader, .channelSpoofingEnabled, .channelSpoofingMyChannel, .channelSpoofingAs, .channelSpoofingInfo:
            return DeveloperSettingsSection.channelSpoofing.rawValue
        case .friendSpoofingHeader, .friendSpoofingEnabled, .friendSpoofingTarget, .friendSpoofingSource, .friendSpoofingInfo:
            return DeveloperSettingsSection.friendSpoofing.rawValue
        case .messageSimulationHeader, .messageSimulationEnabled, .messageSimulationTarget, .messageSimulationText, .messageSimulationSendText, .messageSimulationSendPicture, .messageSimulationOpen, .messageSimulationInfo:
            return DeveloperSettingsSection.messageSimulation.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .spoofingHeader:
            return 0
        case .spoofingEnabled:
            return 1
        case .spoofingTarget:
            return 2
        case .spoofingInfo:
            return 3
        case .channelSpoofingHeader:
            return 4
        case .channelSpoofingEnabled:
            return 5
        case .channelSpoofingMyChannel:
            return 6
        case .channelSpoofingAs:
            return 7
        case .channelSpoofingInfo:
            return 8
        case .friendSpoofingHeader:
            return 9
        case .friendSpoofingEnabled:
            return 10
        case .friendSpoofingTarget:
            return 11
        case .friendSpoofingSource:
            return 12
        case .friendSpoofingInfo:
            return 13
        case .messageSimulationHeader:
            return 14
        case .messageSimulationEnabled:
            return 15
        case .messageSimulationTarget:
            return 16
        case .messageSimulationText:
            return 17
        case .messageSimulationSendText:
            return 18
        case .messageSimulationSendPicture:
            return 19
        case .messageSimulationOpen:
            return 20
        case .messageSimulationInfo:
            return 21
        }
    }
    
    static func ==(lhs: DeveloperSettingsEntry, rhs: DeveloperSettingsEntry) -> Bool {
        switch lhs {
        case let .spoofingHeader(lhsText):
            if case let .spoofingHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .spoofingEnabled(lhsText, lhsValue):
            if case let .spoofingEnabled(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .spoofingTarget(lhsText, lhsValue):
            if case let .spoofingTarget(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .spoofingInfo(lhsText):
            if case let .spoofingInfo(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .channelSpoofingHeader(lhsText):
            if case let .channelSpoofingHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .channelSpoofingEnabled(lhsText, lhsValue):
            if case let .channelSpoofingEnabled(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .channelSpoofingMyChannel(lhsText, lhsValue):
            if case let .channelSpoofingMyChannel(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .channelSpoofingAs(lhsText, lhsValue):
            if case let .channelSpoofingAs(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .channelSpoofingInfo(lhsText):
            if case let .channelSpoofingInfo(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .friendSpoofingHeader(lhsText):
            if case let .friendSpoofingHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .friendSpoofingEnabled(lhsText, lhsValue):
            if case let .friendSpoofingEnabled(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .friendSpoofingTarget(lhsText, lhsValue):
            if case let .friendSpoofingTarget(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .friendSpoofingSource(lhsText, lhsValue):
            if case let .friendSpoofingSource(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .friendSpoofingInfo(lhsText):
            if case let .friendSpoofingInfo(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .messageSimulationHeader(lhsText):
            if case let .messageSimulationHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .messageSimulationEnabled(lhsText, lhsValue):
            if case let .messageSimulationEnabled(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .messageSimulationTarget(lhsText, lhsValue):
            if case let .messageSimulationTarget(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .messageSimulationText(lhsText, lhsValue):
            if case let .messageSimulationText(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .messageSimulationSendText(lhsText):
            if case let .messageSimulationSendText(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .messageSimulationSendPicture(lhsText):
            if case let .messageSimulationSendPicture(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .messageSimulationOpen(lhsText):
            if case let .messageSimulationOpen(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .messageSimulationInfo(lhsText):
            if case let .messageSimulationInfo(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        }
    }
    
    static func <(lhs: DeveloperSettingsEntry, rhs: DeveloperSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DeveloperSettingsControllerArguments
        switch self {
        case let .spoofingHeader(text), let .channelSpoofingHeader(text), let .friendSpoofingHeader(text), let .messageSimulationHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .spoofingEnabled(text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleSpoofing(updatedValue)
            })
        case let .spoofingTarget(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateTarget(updatedText)
            }, action: {})
        case let .spoofingInfo(text), let .channelSpoofingInfo(text), let .friendSpoofingInfo(text), let .messageSimulationInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .channelSpoofingEnabled(text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleChannelSpoofing(updatedValue)
            })
        case let .channelSpoofingMyChannel(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateMyChannel(updatedText)
            }, action: {})
        case let .channelSpoofingAs(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateSpoofChannelAs(updatedText)
            }, action: {})
        case let .friendSpoofingEnabled(text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleFriendSpoofing(updatedValue)
            })
        case let .friendSpoofingTarget(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateFriendTarget(updatedText)
            }, action: {})
        case let .friendSpoofingSource(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateFriendSource(updatedText)
            }, action: {})
        case let .messageSimulationEnabled(text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleMessageSimulation(updatedValue)
            })
        case let .messageSimulationTarget(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateMessageSimulationTarget(updatedText)
            }, action: {})
        case let .messageSimulationText(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: true, autocorrection: true), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateMessageSimulationText(updatedText)
            }, action: {})
        case let .messageSimulationSendText(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.sendSimulatedText()
            })
        case let .messageSimulationSendPicture(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.sendSimulatedPicture()
            })
        case let .messageSimulationOpen(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openSimulatedConversation()
            })
        }
    }
}

private func developerSettingsControllerEntries(settings: ProfileSpoofingSettings, friendSettings: FriendSpoofingSettings, simulation: MessageSimulationSettings) -> [DeveloperSettingsEntry] {
    var entries: [DeveloperSettingsEntry] = []
    entries.append(.spoofingHeader("Spoofing"))
    entries.append(.spoofingEnabled("Enabled", settings.isEnabled))
    entries.append(.spoofingTarget("Username or ID", settings.target))
    entries.append(.spoofingInfo("When enabled, this client locally displays the specified user's profile in place of yours, including name, username, photo, bio, personal channel, Premium, verification, rating, gifts and other visible profile details. Your Telegram account is not changed."))
    
    entries.append(.channelSpoofingHeader("Channel Spoofing"))
    entries.append(.channelSpoofingEnabled("Enabled", settings.channelSpoofingEnabled))
    entries.append(.channelSpoofingMyChannel("Your channel link", settings.myChannel))
    entries.append(.channelSpoofingAs("Spoof as channel", settings.spoofChannelAs))
    entries.append(.channelSpoofingInfo("When enabled, this client locally displays the source channel's visible details on your channel, including name, username, photo, description, subscriber count, messages, reactions, gifts and other channel information. You can still post and manage the channel as the owner. Your real channel and Telegram's servers are not changed."))
    
    entries.append(.friendSpoofingHeader("Friend Spoofing"))
    entries.append(.friendSpoofingEnabled("Enabled", friendSettings.isEnabled))
    entries.append(.friendSpoofingTarget("Target user ID or username", friendSettings.target))
    entries.append(.friendSpoofingSource("Source profile ID or username", friendSettings.source))
    entries.append(.friendSpoofingInfo("When enabled, this client locally displays the source user's visible profile on the target user, including name, username, photo, bio, personal channel, Premium, verification, rating, gifts and other visible profile details. Real Telegram accounts and servers are not changed."))
    
    entries.append(.messageSimulationHeader("Message Simulation"))
    entries.append(.messageSimulationEnabled("Enabled", simulation.isEnabled))
    entries.append(.messageSimulationTarget("Username or ID", simulation.target))
    entries.append(.messageSimulationText("Message text", simulation.composeText))
    entries.append(.messageSimulationSendText("Send simulated message"))
    entries.append(.messageSimulationSendPicture("Send simulated picture"))
    entries.append(.messageSimulationOpen("Open conversation"))
    entries.append(.messageSimulationInfo("Creates a local-only chat that looks like a normal Telegram conversation with the specified profile, including photo, bio, Premium, verification, rating, gifts and other visible details. Incoming text, emoji and pictures are simulated on this device. You can reply in the chat; the simulated user receives, reads and replies locally. Messages persist until you delete them. No real Telegram accounts, messages or servers are changed."))
    return entries
}

private func simulatedMedia(from image: UIImage, account: Account) -> TelegramMediaImage? {
    guard let data = image.jpegData(compressionQuality: 0.86) else {
        return nil
    }
    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: Int64(data.count))
    account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
    let scale = image.scale == 0.0 ? 1.0 : image.scale
    let dimensions = PixelDimensions(width: Int32(image.size.width * scale), height: Int32(image.size.height * scale))
    return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: resource.fileId), representations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
}

public func developerSettingsController(context: AccountContext) -> ViewController {
    let updateDisposable = MetaDisposable()
    let actionDisposable = MetaDisposable()
    var pickerHolder: Any?
    
    let settings = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.profileSpoofingSettings)
    )
    |> map { entry -> ProfileSpoofingSettings in
        return entry?.get(ProfileSpoofingSettings.self) ?? .defaultSettings
    }
    
    let simulation = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.messageSimulationSettings)
    )
    |> map { entry -> MessageSimulationSettings in
        return entry?.get(MessageSimulationSettings.self) ?? .defaultSettings
    }
    
    let friendSettings = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.friendSpoofingSettings)
    )
    |> map { entry -> FriendSpoofingSettings in
        return entry?.get(FriendSpoofingSettings.self) ?? .defaultSettings
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var getNavigationControllerImpl: (() -> NavigationController?)?
    
    let arguments = DeveloperSettingsControllerArguments(toggleSpoofing: { value in
        updateDisposable.set(updateProfileSpoofingSettings(engine: context.engine, { current in
            var current = current
            current.isEnabled = value
            return current
        }).start())
    }, updateTarget: { text in
        updateDisposable.set(updateProfileSpoofingSettings(engine: context.engine, { current in
            var current = current
            current.target = text
            return current
        }).start())
    }, toggleChannelSpoofing: { value in
        updateDisposable.set(updateProfileSpoofingSettings(engine: context.engine, { current in
            var current = current
            current.channelSpoofingEnabled = value
            return current
        }).start())
    }, updateMyChannel: { text in
        updateDisposable.set(updateProfileSpoofingSettings(engine: context.engine, { current in
            var current = current
            current.myChannel = text
            return current
        }).start())
    }, updateSpoofChannelAs: { text in
        updateDisposable.set(updateProfileSpoofingSettings(engine: context.engine, { current in
            var current = current
            current.spoofChannelAs = text
            return current
        }).start())
    }, toggleFriendSpoofing: { value in
        updateDisposable.set(updateFriendSpoofingSettings(engine: context.engine, { current in
            var current = current
            current.isEnabled = value
            return current
        }).start())
    }, updateFriendTarget: { text in
        updateDisposable.set(updateFriendSpoofingSettings(engine: context.engine, { current in
            var current = current
            current.target = text
            return current
        }).start())
    }, updateFriendSource: { text in
        updateDisposable.set(updateFriendSpoofingSettings(engine: context.engine, { current in
            var current = current
            current.source = text
            return current
        }).start())
    }, toggleMessageSimulation: { value in
        updateDisposable.set(updateMessageSimulationSettings(engine: context.engine, { current in
            var current = current
            current.isEnabled = value
            return current
        }).start())
    }, updateMessageSimulationTarget: { text in
        updateDisposable.set(updateMessageSimulationSettings(engine: context.engine, { current in
            var current = current
            current.target = text
            return current
        }).start())
    }, updateMessageSimulationText: { text in
        updateDisposable.set(updateMessageSimulationSettings(engine: context.engine, { current in
            var current = current
            current.composeText = text
            return current
        }).start())
    }, sendSimulatedText: {
        actionDisposable.set((simulation |> take(1) |> mapToSignal { settings -> Signal<Never, NoError> in
            guard settings.isEnabled, let raw = settings.simulatedPeerId else {
                return .complete()
            }
            let text = settings.composeText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return .complete()
            }
            return MessageSimulationOverlay.insertIncomingMessage(account: context.account, peerId: PeerId(raw), text: text, media: [], notify: true)
            |> ignoreValues
        }).start())
    }, sendSimulatedPicture: {
        var pickerController: ViewController?
        let (mainController, holder) = context.sharedContext.makeAvatarMediaPickerScreen(context: context, peerType: .user(isBot: false), getSourceRect: { return nil }, canDelete: false, performDelete: {}, completion: { result, _, _, transitionImage, _, _, _ in
            pickerHolder = nil
            pickerController?.dismiss()
            let image = (result as? UIImage) ?? transitionImage
            guard let image else {
                return
            }
            actionDisposable.set((simulation |> take(1) |> mapToSignal { settings -> Signal<Never, NoError> in
                guard settings.isEnabled, let raw = settings.simulatedPeerId, let media = simulatedMedia(from: image, account: context.account) else {
                    return .complete()
                }
                let caption = settings.composeText.trimmingCharacters(in: .whitespacesAndNewlines)
                return MessageSimulationOverlay.insertIncomingMessage(account: context.account, peerId: PeerId(raw), text: caption, media: [media], notify: true)
                |> ignoreValues
            }).start())
        }, dismissed: {
            pickerHolder = nil
        })
        pickerHolder = holder
        pickerController = mainController
        if let mainController {
            presentControllerImpl?(mainController, nil)
        }
    }, openSimulatedConversation: {
        actionDisposable.set((simulation |> take(1) |> mapToSignal { settings -> Signal<EnginePeer?, NoError> in
            guard settings.isEnabled, let raw = settings.simulatedPeerId else {
                return .single(nil)
            }
            return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: PeerId(raw)))
        }
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer, let navigationController = getNavigationControllerImpl?() else {
                return
            }
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
        }))
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, settings, friendSettings, simulation)
    |> map { presentationData, settings, friendSettings, simulation -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Developer Settings"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: developerSettingsControllerEntries(settings: settings, friendSettings: friendSettings, simulation: simulation), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        updateDisposable.dispose()
        actionDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    getNavigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}
