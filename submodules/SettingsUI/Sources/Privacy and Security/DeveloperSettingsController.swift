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
    let addFriendSpoofing: () -> Void
    let removeFriendSpoofing: (Int) -> Void
    let toggleMessageSimulation: (Bool) -> Void
    let updateMessageSimulationTarget: (String) -> Void
    let updateMessageSimulationText: (String) -> Void
    let sendSimulatedText: () -> Void
    let sendSimulatedPicture: () -> Void
    let sendSimulatedGift: () -> Void
    let openSimulatedConversation: () -> Void
    let updateManualFirstName: (String) -> Void
    let updateManualLastName: (String) -> Void
    let setManualPhoto: () -> Void
    let clearManualPhoto: () -> Void
    let updateManualAnonymousNumber: (String) -> Void
    let updateManualUsernameDraft: (String) -> Void
    let addManualUsername: () -> Void
    let removeManualUsername: (Int) -> Void
    let toggleManualHoldVerification: (Bool) -> Void
    let toggleManualMajorVerification: (Bool) -> Void
    let updateManualGiftName: (String) -> Void
    let updateManualGiftNumber: (String) -> Void
    let addManualGift: () -> Void
    let pinManualGift: (Int) -> Void
    let wearManualGift: (Int) -> Void
    let removeManualGift: (Int) -> Void
    
    init(toggleSpoofing: @escaping (Bool) -> Void, updateTarget: @escaping (String) -> Void, toggleChannelSpoofing: @escaping (Bool) -> Void, updateMyChannel: @escaping (String) -> Void, updateSpoofChannelAs: @escaping (String) -> Void, toggleFriendSpoofing: @escaping (Bool) -> Void, updateFriendTarget: @escaping (String) -> Void, updateFriendSource: @escaping (String) -> Void, addFriendSpoofing: @escaping () -> Void, removeFriendSpoofing: @escaping (Int) -> Void, toggleMessageSimulation: @escaping (Bool) -> Void, updateMessageSimulationTarget: @escaping (String) -> Void, updateMessageSimulationText: @escaping (String) -> Void, sendSimulatedText: @escaping () -> Void, sendSimulatedPicture: @escaping () -> Void, sendSimulatedGift: @escaping () -> Void, openSimulatedConversation: @escaping () -> Void, updateManualFirstName: @escaping (String) -> Void, updateManualLastName: @escaping (String) -> Void, setManualPhoto: @escaping () -> Void, clearManualPhoto: @escaping () -> Void, updateManualAnonymousNumber: @escaping (String) -> Void, updateManualUsernameDraft: @escaping (String) -> Void, addManualUsername: @escaping () -> Void, removeManualUsername: @escaping (Int) -> Void, toggleManualHoldVerification: @escaping (Bool) -> Void, toggleManualMajorVerification: @escaping (Bool) -> Void, updateManualGiftName: @escaping (String) -> Void, updateManualGiftNumber: @escaping (String) -> Void, addManualGift: @escaping () -> Void, pinManualGift: @escaping (Int) -> Void, wearManualGift: @escaping (Int) -> Void, removeManualGift: @escaping (Int) -> Void) {
        self.toggleSpoofing = toggleSpoofing
        self.updateTarget = updateTarget
        self.toggleChannelSpoofing = toggleChannelSpoofing
        self.updateMyChannel = updateMyChannel
        self.updateSpoofChannelAs = updateSpoofChannelAs
        self.toggleFriendSpoofing = toggleFriendSpoofing
        self.updateFriendTarget = updateFriendTarget
        self.updateFriendSource = updateFriendSource
        self.addFriendSpoofing = addFriendSpoofing
        self.removeFriendSpoofing = removeFriendSpoofing
        self.toggleMessageSimulation = toggleMessageSimulation
        self.updateMessageSimulationTarget = updateMessageSimulationTarget
        self.updateMessageSimulationText = updateMessageSimulationText
        self.sendSimulatedText = sendSimulatedText
        self.sendSimulatedPicture = sendSimulatedPicture
        self.sendSimulatedGift = sendSimulatedGift
        self.openSimulatedConversation = openSimulatedConversation
        self.updateManualFirstName = updateManualFirstName
        self.updateManualLastName = updateManualLastName
        self.setManualPhoto = setManualPhoto
        self.clearManualPhoto = clearManualPhoto
        self.updateManualAnonymousNumber = updateManualAnonymousNumber
        self.updateManualUsernameDraft = updateManualUsernameDraft
        self.addManualUsername = addManualUsername
        self.removeManualUsername = removeManualUsername
        self.toggleManualHoldVerification = toggleManualHoldVerification
        self.toggleManualMajorVerification = toggleManualMajorVerification
        self.updateManualGiftName = updateManualGiftName
        self.updateManualGiftNumber = updateManualGiftNumber
        self.addManualGift = addManualGift
        self.pinManualGift = pinManualGift
        self.wearManualGift = wearManualGift
        self.removeManualGift = removeManualGift
    }
}

private enum DeveloperSettingsSection: Int32 {
    case manual
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
    case friendSpoofingAdd(String)
    case friendSpoofingMapping(Int, String)
    case friendSpoofingInfo(String)
    case messageSimulationHeader(String)
    case messageSimulationEnabled(String, Bool)
    case messageSimulationTarget(String, String)
    case messageSimulationText(String, String)
    case messageSimulationSendText(String)
    case messageSimulationSendPicture(String)
    case messageSimulationSendGift(String)
    case messageSimulationOpen(String)
    case messageSimulationInfo(String)
    case manualHeader(String)
    case manualFirstName(String, String)
    case manualLastName(String, String)
    case manualPhotoSet(String)
    case manualPhotoClear(String)
    case manualAnonymousNumber(String, String)
    case manualUsernameDraft(String, String)
    case manualAddUsername(String)
    case manualUsername(Int, String)
    case manualHoldVerification(String, Bool)
    case manualMajorVerification(String, Bool)
    case manualGiftName(String, String)
    case manualGiftNumber(String, String)
    case manualAddGift(String)
    case manualGiftPin(Int, String)
    case manualGiftWear(Int, String)
    case manualGiftRemove(Int, String)
    case manualInfo(String)
    
    var section: ItemListSectionId {
        switch self {
        case .spoofingHeader, .spoofingEnabled, .spoofingTarget, .spoofingInfo:
            return DeveloperSettingsSection.spoofing.rawValue
        case .channelSpoofingHeader, .channelSpoofingEnabled, .channelSpoofingMyChannel, .channelSpoofingAs, .channelSpoofingInfo:
            return DeveloperSettingsSection.channelSpoofing.rawValue
        case .friendSpoofingHeader, .friendSpoofingEnabled, .friendSpoofingTarget, .friendSpoofingSource, .friendSpoofingAdd, .friendSpoofingMapping, .friendSpoofingInfo:
            return DeveloperSettingsSection.friendSpoofing.rawValue
        case .messageSimulationHeader, .messageSimulationEnabled, .messageSimulationTarget, .messageSimulationText, .messageSimulationSendText, .messageSimulationSendPicture, .messageSimulationSendGift, .messageSimulationOpen, .messageSimulationInfo:
            return DeveloperSettingsSection.messageSimulation.rawValue
        case .manualHeader, .manualFirstName, .manualLastName, .manualPhotoSet, .manualPhotoClear, .manualAnonymousNumber, .manualUsernameDraft, .manualAddUsername, .manualUsername, .manualHoldVerification, .manualMajorVerification, .manualGiftName, .manualGiftNumber, .manualAddGift, .manualGiftPin, .manualGiftWear, .manualGiftRemove, .manualInfo:
            return DeveloperSettingsSection.manual.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .manualHeader:
            return 0
        case .manualFirstName:
            return 1
        case .manualLastName:
            return 2
        case .manualPhotoSet:
            return 3
        case .manualPhotoClear:
            return 4
        case .manualAnonymousNumber:
            return 5
        case .manualUsernameDraft:
            return 6
        case .manualAddUsername:
            return 7
        case let .manualUsername(index, _):
            return 20 + Int32(index)
        case .manualHoldVerification:
            return 80
        case .manualMajorVerification:
            return 81
        case .manualGiftName:
            return 82
        case .manualGiftNumber:
            return 83
        case .manualAddGift:
            return 84
        case let .manualGiftPin(index, _):
            return 100 + Int32(index) * 4
        case let .manualGiftWear(index, _):
            return 101 + Int32(index) * 4
        case let .manualGiftRemove(index, _):
            return 102 + Int32(index) * 4
        case .manualInfo:
            return 199
        case .spoofingHeader:
            return 200
        case .spoofingEnabled:
            return 201
        case .spoofingTarget:
            return 202
        case .spoofingInfo:
            return 203
        case .channelSpoofingHeader:
            return 204
        case .channelSpoofingEnabled:
            return 205
        case .channelSpoofingMyChannel:
            return 206
        case .channelSpoofingAs:
            return 207
        case .channelSpoofingInfo:
            return 208
        case .friendSpoofingHeader:
            return 209
        case .friendSpoofingEnabled:
            return 210
        case .friendSpoofingTarget:
            return 211
        case .friendSpoofingSource:
            return 212
        case .friendSpoofingAdd:
            return 213
        case let .friendSpoofingMapping(index, _):
            return 300 + Int32(index)
        case .friendSpoofingInfo:
            return 380
        case .messageSimulationHeader:
            return 400
        case .messageSimulationEnabled:
            return 401
        case .messageSimulationTarget:
            return 402
        case .messageSimulationText:
            return 403
        case .messageSimulationSendText:
            return 404
        case .messageSimulationSendPicture:
            return 405
        case .messageSimulationSendGift:
            return 406
        case .messageSimulationOpen:
            return 407
        case .messageSimulationInfo:
            return 408
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
        case let .friendSpoofingAdd(lhsText):
            if case let .friendSpoofingAdd(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .friendSpoofingMapping(lhsIndex, lhsText):
            if case let .friendSpoofingMapping(rhsIndex, rhsText) = rhs, lhsIndex == rhsIndex, lhsText == rhsText { return true } else { return false }
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
        case let .messageSimulationSendGift(lhsText):
            if case let .messageSimulationSendGift(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .messageSimulationOpen(lhsText):
            if case let .messageSimulationOpen(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .messageSimulationInfo(lhsText):
            if case let .messageSimulationInfo(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .manualHeader(lhsText):
            if case let .manualHeader(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .manualFirstName(lhsPlaceholder, lhsValue):
            if case let .manualFirstName(rhsPlaceholder, rhsValue) = rhs, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue { return true } else { return false }
        case let .manualLastName(lhsPlaceholder, lhsValue):
            if case let .manualLastName(rhsPlaceholder, rhsValue) = rhs, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue { return true } else { return false }
        case let .manualPhotoSet(lhsText):
            if case let .manualPhotoSet(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .manualPhotoClear(lhsText):
            if case let .manualPhotoClear(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .manualAnonymousNumber(lhsPlaceholder, lhsValue):
            if case let .manualAnonymousNumber(rhsPlaceholder, rhsValue) = rhs, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue { return true } else { return false }
        case let .manualUsernameDraft(lhsPlaceholder, lhsValue):
            if case let .manualUsernameDraft(rhsPlaceholder, rhsValue) = rhs, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue { return true } else { return false }
        case let .manualAddUsername(lhsText):
            if case let .manualAddUsername(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .manualUsername(lhsIndex, lhsText):
            if case let .manualUsername(rhsIndex, rhsText) = rhs, lhsIndex == rhsIndex, lhsText == rhsText { return true } else { return false }
        case let .manualHoldVerification(lhsText, lhsValue):
            if case let .manualHoldVerification(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .manualMajorVerification(lhsText, lhsValue):
            if case let .manualMajorVerification(rhsText, rhsValue) = rhs, lhsText == rhsText, lhsValue == rhsValue { return true } else { return false }
        case let .manualGiftName(lhsPlaceholder, lhsValue):
            if case let .manualGiftName(rhsPlaceholder, rhsValue) = rhs, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue { return true } else { return false }
        case let .manualGiftNumber(lhsPlaceholder, lhsValue):
            if case let .manualGiftNumber(rhsPlaceholder, rhsValue) = rhs, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue { return true } else { return false }
        case let .manualAddGift(lhsText):
            if case let .manualAddGift(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        case let .manualGiftPin(lhsIndex, lhsText):
            if case let .manualGiftPin(rhsIndex, rhsText) = rhs, lhsIndex == rhsIndex, lhsText == rhsText { return true } else { return false }
        case let .manualGiftWear(lhsIndex, lhsText):
            if case let .manualGiftWear(rhsIndex, rhsText) = rhs, lhsIndex == rhsIndex, lhsText == rhsText { return true } else { return false }
        case let .manualGiftRemove(lhsIndex, lhsText):
            if case let .manualGiftRemove(rhsIndex, rhsText) = rhs, lhsIndex == rhsIndex, lhsText == rhsText { return true } else { return false }
        case let .manualInfo(lhsText):
            if case let .manualInfo(rhsText) = rhs, lhsText == rhsText { return true } else { return false }
        }
    }
    
    static func <(lhs: DeveloperSettingsEntry, rhs: DeveloperSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DeveloperSettingsControllerArguments
        switch self {
        case let .spoofingHeader(text), let .channelSpoofingHeader(text), let .friendSpoofingHeader(text), let .messageSimulationHeader(text), let .manualHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .spoofingEnabled(text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleSpoofing(updatedValue)
            })
        case let .spoofingTarget(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateTarget(updatedText)
            }, action: {})
        case let .spoofingInfo(text), let .channelSpoofingInfo(text), let .friendSpoofingInfo(text), let .messageSimulationInfo(text), let .manualInfo(text):
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
        case let .friendSpoofingAdd(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addFriendSpoofing()
            })
        case let .friendSpoofingMapping(index, text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.removeFriendSpoofing(index)
            })
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
        case let .messageSimulationSendGift(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.sendSimulatedGift()
            })
        case let .messageSimulationOpen(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openSimulatedConversation()
            })
        case let .manualFirstName(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: true, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateManualFirstName(updatedText)
            }, action: {})
        case let .manualLastName(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: true, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateManualLastName(updatedText)
            }, action: {})
        case let .manualPhotoSet(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.setManualPhoto()
            })
        case let .manualPhotoClear(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearManualPhoto()
            })
        case let .manualAnonymousNumber(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateManualAnonymousNumber(updatedText)
            }, action: {})
        case let .manualUsernameDraft(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateManualUsernameDraft(updatedText)
            }, action: {})
        case let .manualAddUsername(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addManualUsername()
            })
        case let .manualUsername(index, text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.removeManualUsername(index)
            })
        case let .manualHoldVerification(text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleManualHoldVerification(updatedValue)
            })
        case let .manualMajorVerification(text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.toggleManualMajorVerification(updatedValue)
            })
        case let .manualGiftName(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateManualGiftName(updatedText)
            }, action: {})
        case let .manualGiftNumber(placeholder, value):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(string: ""), text: value, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), spacing: 0.0, clearType: .always, sectionId: self.section, textUpdated: { updatedText in
                arguments.updateManualGiftNumber(updatedText)
            }, action: {})
        case let .manualAddGift(text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addManualGift()
            })
        case let .manualGiftPin(index, text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.pinManualGift(index)
            })
        case let .manualGiftWear(index, text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.wearManualGift(index)
            })
        case let .manualGiftRemove(index, text):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.removeManualGift(index)
            })
        }
    }
}

private func developerSettingsControllerEntries(settings: ProfileSpoofingSettings, friendSettings: FriendSpoofingSettings, simulation: MessageSimulationSettings, manual: ManualProfileSettings) -> [DeveloperSettingsEntry] {
    var entries: [DeveloperSettingsEntry] = []
    entries.append(.manualHeader("Manual Profile"))
    entries.append(.manualFirstName("First name", manual.firstName))
    entries.append(.manualLastName("Last name", manual.lastName))
    entries.append(.manualPhotoSet(manual.hasPhotoOverride ? "Change profile picture" : "Set profile picture"))
    if manual.hasPhotoOverride {
        entries.append(.manualPhotoClear("Remove profile picture"))
    }
    entries.append(.manualAnonymousNumber("Anonymous number +888", manual.anonymousNumber))
    entries.append(.manualUsernameDraft("Username", manual.usernameDraft))
    entries.append(.manualAddUsername("Add username"))
    for (index, username) in manual.normalizedUsernames.enumerated() {
        entries.append(.manualUsername(index, "Remove @\(username)"))
    }
    entries.append(.manualHoldVerification("Hold Verification", manual.holdVerification))
    entries.append(.manualMajorVerification("Major Verification", manual.majorVerification))
    entries.append(.manualGiftName("Gift name or t.me/nft slug", manual.giftNameDraft))
    entries.append(.manualGiftNumber("Gift number #", manual.giftNumberDraft))
    entries.append(.manualAddGift("Add gift"))
    for (index, gift) in manual.gifts.enumerated() {
        let title = gift.displayTitle
        entries.append(.manualGiftPin(index, gift.pinnedToTop ? "Unpin \(title)" : "Pin \(title)"))
        entries.append(.manualGiftWear(index, gift.wear ? "Unwear \(title)" : "Wear \(title)"))
        entries.append(.manualGiftRemove(index, "Remove \(title)"))
    }
    entries.append(.manualInfo("Each field applies independently to your profile on this device using Telegram's existing profile UI. Gifts are resolved from Telegram collectible data and shown in the normal Gifts tab, including artwork, model, backdrop, symbol, number, pinning and wearing. Empty fields leave the real or spoofed value unchanged. Nothing is written to your Telegram account."))
    
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
    entries.append(.friendSpoofingAdd("Add spoofed person"))
    for (index, mapping) in friendSettings.mappings.enumerated() {
        let target = FriendSpoofingSettings.normalizedIdentifier(mapping.target)
        let source = FriendSpoofingSettings.normalizedIdentifier(mapping.source)
        entries.append(.friendSpoofingMapping(index, "Remove \(target) → \(source)"))
    }
    entries.append(.friendSpoofingInfo("Each spoof is stored independently by user ID or username and applies only to that conversation and profile, including photo, gifts, badges, bio, username and other visible details. Add as many people as you want. Settings stay on this device after you close the app. Real Telegram accounts and servers are not changed."))
    
    entries.append(.messageSimulationHeader("Message Simulation"))
    entries.append(.messageSimulationEnabled("Enabled", simulation.isEnabled))
    entries.append(.messageSimulationTarget("Username or ID", simulation.target))
    entries.append(.messageSimulationText("Message text", simulation.composeText))
    entries.append(.messageSimulationSendText("Send simulated message"))
    entries.append(.messageSimulationSendPicture("Send simulated picture"))
    entries.append(.messageSimulationSendGift("Send simulated gift"))
    entries.append(.messageSimulationOpen("Open conversation"))
    entries.append(.messageSimulationInfo("Creates a local-only chat that looks like a normal Telegram conversation with the specified profile, including photo, bio, Premium, verification, rating, gifts and other visible details. Incoming text, emoji, pictures and gifts are simulated on this device. You can reply in the chat; the simulated user receives, reads and replies locally. Gift bubbles use the same chat gift UI as Telegram. Messages persist until you delete them. No real Telegram accounts, messages or servers are changed."))
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

private func storeManualProfilePhoto(from image: UIImage, account: Account) -> (fileId: Int64, width: Int32, height: Int32)? {
    guard let data = image.jpegData(compressionQuality: 0.86) else {
        return nil
    }
    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: Int64(data.count))
    account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
    ManualProfileSettings.persistPhotoData(data)
    let scale = image.scale == 0.0 ? 1.0 : image.scale
    let width = Int32(image.size.width * scale)
    let height = Int32(image.size.height * scale)
    return (resource.fileId, width, height)
}

public func developerSettingsController(context: AccountContext) -> ViewController {
    let updateDisposable = MetaDisposable()
    let actionDisposable = MetaDisposable()
    var pickerHolder: Any?
    
    let settings = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.profileSpoofingSettings)
    )
    |> map { entry -> ProfileSpoofingSettings in
        return ProfileSpoofingSettings.fromPreference(entry)
    }
    
    let simulation = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.messageSimulationSettings)
    )
    |> map { entry -> MessageSimulationSettings in
        return MessageSimulationSettings.fromPreference(entry)
    }
    
    let friendSettings = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.friendSpoofingSettings)
    )
    |> map { entry -> FriendSpoofingSettings in
        return FriendSpoofingSettings.fromPreference(entry)
    }
    
    let manual = Signal<ManualProfileSettings, NoError> { subscriber in
        subscriber.putNext(ManualProfileSettings.defaultSettings)
        return context.engine.data.subscribe(
            TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.manualProfileSettings)
        ).start(next: { entry in
            subscriber.putNext(ManualProfileSettings.fromPreference(entry))
        })
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
    }, addFriendSpoofing: {
        updateDisposable.set(updateFriendSpoofingSettings(engine: context.engine, { current in
            var current = current
            current.upsertDraftMapping()
            return current
        }).start())
    }, removeFriendSpoofing: { index in
        updateDisposable.set(updateFriendSpoofingSettings(engine: context.engine, { current in
            var current = current
            current.removeMapping(at: index)
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
        _ = pickerHolder
        pickerController = mainController
        if let mainController {
            presentControllerImpl?(mainController, nil)
        }
    }, sendSimulatedGift: {
        actionDisposable.set((simulation |> take(1) |> mapToSignal { settings -> Signal<Never, NoError> in
            guard settings.isEnabled, let raw = settings.simulatedPeerId else {
                return .complete()
            }
            let text = settings.composeText.trimmingCharacters(in: .whitespacesAndNewlines)
            return MessageSimulationOverlay.insertIncomingGift(account: context.account, peerId: PeerId(raw), text: text.isEmpty ? nil : text, notify: true)
            |> ignoreValues
        }).start())
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
    }, updateManualFirstName: { text in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.firstName = text
            return current
        }).start())
    }, updateManualLastName: { text in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.lastName = text
            return current
        }).start())
    }, setManualPhoto: {
        var pickerController: ViewController?
        let (mainController, holder) = context.sharedContext.makeAvatarMediaPickerScreen(context: context, peerType: .user(isBot: false), getSourceRect: { return nil }, canDelete: false, performDelete: {}, completion: { result, _, _, transitionImage, _, _, _ in
            pickerHolder = nil
            pickerController?.dismiss()
            let image = (result as? UIImage) ?? transitionImage
            guard let image, let stored = storeManualProfilePhoto(from: image, account: context.account) else {
                return
            }
            updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
                var current = current
                current.photoFileId = stored.fileId
                current.photoWidth = stored.width
                current.photoHeight = stored.height
                return current
            }).start())
        }, dismissed: {
            pickerHolder = nil
        })
        pickerHolder = holder
        _ = pickerHolder
        pickerController = mainController
        if let mainController {
            presentControllerImpl?(mainController, nil)
        }
    }, clearManualPhoto: {
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.clearPhoto()
            return current
        }).start())
    }, updateManualAnonymousNumber: { text in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.anonymousNumber = text
            return current
        }).start())
    }, updateManualUsernameDraft: { text in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.usernameDraft = text
            return current
        }).start())
    }, addManualUsername: {
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.addUsernameFromDraft()
            return current
        }).start())
    }, removeManualUsername: { index in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.removeUsername(at: index)
            return current
        }).start())
    }, toggleManualHoldVerification: { value in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.holdVerification = value
            if value {
                if current.holdVerificationInfo == nil || current.holdVerificationInfo?.isPlaceholderOrganizationVerification == true || current.holdVerificationInfo?.iconFileId == 0 {
                    current.holdVerificationInfo = ManualProfileOverlay.fallbackHoldVerification(botId: current.holdVerificationInfo?.botId)
                }
            } else {
                current.holdVerificationInfo = nil
            }
            return current
        }).start())
    }, toggleManualMajorVerification: { value in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.majorVerification = value
            return current
        }).start())
    }, updateManualGiftName: { text in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.giftNameDraft = text
            return current
        }).start())
    }, updateManualGiftNumber: { text in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.giftNumberDraft = text
            return current
        }).start())
    }, addManualGift: {
        actionDisposable.set((manual |> take(1) |> mapToSignal { settings -> Signal<Never, NoError> in
            guard let slug = ManualProfileOverlay.slug(fromName: settings.giftNameDraft, number: settings.giftNumberDraft) else {
                return .complete()
            }
            return context.engine.payments.getUniqueStarGift(slug: slug)
            |> mapToSignal { uniqueGift -> Signal<Never, GetUniqueStarGiftError> in
                guard uniqueGift.hasRenderableArtwork else {
                    return .complete()
                }
                let owned = uniqueGift.withOwner(.peerId(context.account.peerId))
                let entry = ManualStarGiftEntry(
                    slug: owned.slug,
                    title: owned.title,
                    number: owned.number,
                    pinnedToTop: false,
                    savedToProfile: true,
                    wear: false,
                    date: Int32(Date().timeIntervalSince1970),
                    uniqueGift: owned
                )
                return updateManualProfileSettings(engine: context.engine, { current in
                    var current = current
                    current.upsertGift(entry)
                    return current
                })
                |> castError(GetUniqueStarGiftError.self)
            }
            |> `catch` { _ -> Signal<Never, NoError> in
                return .complete()
            }
        }).start())
    }, pinManualGift: { index in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            guard index >= 0, index < current.gifts.count else {
                return current
            }
            current.setGiftPinned(at: index, pinned: !current.gifts[index].pinnedToTop)
            return current
        }).start())
    }, wearManualGift: { index in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            guard index >= 0, index < current.gifts.count else {
                return current
            }
            current.setGiftWear(at: index, wear: !current.gifts[index].wear)
            return current
        }).start())
    }, removeManualGift: { index in
        updateDisposable.set(updateManualProfileSettings(engine: context.engine, { current in
            var current = current
            current.removeGift(at: index)
            return current
        }).start())
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, settings, friendSettings, simulation, manual)
    |> map { presentationData, settings, friendSettings, simulation, manual -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Manual Profile"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: developerSettingsControllerEntries(settings: settings, friendSettings: friendSettings, simulation: simulation, manual: manual), style: .blocks, animateChanges: false)
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
