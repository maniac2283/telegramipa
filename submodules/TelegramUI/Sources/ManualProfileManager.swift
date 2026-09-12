import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences
import AccountContext

final class ManualProfileManager {
    private let context: AccountContext
    private let disposable = DisposableSet()
    private let giftArtworkDisposable = MetaDisposable()
    private let verificationIconDisposable = MetaDisposable()
    
    init(context: AccountContext) {
        self.context = context
        
        let engine = context.engine
        let account = context.account
        let accountPeerId = account.peerId
        
        let settings = engine.data.subscribe(
            TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ApplicationSpecificPreferencesKeys.manualProfileSettings)
        )
        |> map { entry -> ManualProfileSettings in
            return ManualProfileSettings.fromPreference(entry)
        }
        |> distinctUntilChanged
        
        self.disposable.add((settings
        |> mapToSignal { settings -> Signal<ManualProfileOverlayState?, NoError> in
            ManualProfileManager.restorePhotoIfNeeded(account: account, settings: settings)
            return ManualProfileManager.resolveGifts(engine: engine, settings: settings)
            |> mapToSignal { settings in
                return ManualProfileManager.resolveHoldVerification(context: context, engine: engine, settings: settings)
            }
            |> map { settings in
                return ManualProfileManager.makeState(accountPeerId: accountPeerId, settings: settings)
            }
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] state in
            ManualProfileOverlay.set(state)
            if let state {
                self?.prefetchGiftArtwork(state.gifts)
                self?.prefetchVerificationIcon(state.holdVerification)
            } else {
                self?.giftArtworkDisposable.set(nil)
                self?.verificationIconDisposable.set(nil)
            }
        }))
        
        self.disposable.add((ManualProfileOverlay.giftsUpdated
        |> deliverOnMainQueue).start(next: { gifts in
            let _ = updateManualProfileSettings(engine: engine, { current in
                var current = current
                current.gifts = gifts.map { ManualStarGiftEntry(from: $0) }
                return current
            }).start()
        }))
    }
    
    deinit {
        self.disposable.dispose()
        self.giftArtworkDisposable.dispose()
        self.verificationIconDisposable.dispose()
    }
    
    private static func makeState(accountPeerId: PeerId, settings: ManualProfileSettings) -> ManualProfileOverlayState? {
        var firstName: String?
        var lastName: String?
        if settings.hasDisplayNameOverride {
            firstName = settings.trimmedFirstName.isEmpty ? nil : settings.trimmedFirstName
            lastName = settings.trimmedLastName.isEmpty ? nil : settings.trimmedLastName
        }
        
        var photo: [TelegramMediaImageRepresentation] = []
        if let fileId = settings.photoFileId, let width = settings.photoWidth, let height = settings.photoHeight {
            let size = ManualProfileSettings.storedPhotoData()?.count
            photo = ManualProfileOverlay.makeLocalPhoto(fileId: fileId, width: width, height: height, size: size.flatMap(Int64.init))
        }
        
        let gifts = settings.gifts.compactMap { $0.overlayGift() }
        let holdVerification: PeerVerification?
        if settings.holdVerification, let info = settings.holdVerificationInfo, info.iconFileId != 0 {
            holdVerification = info
        } else {
            holdVerification = nil
        }
        let state = ManualProfileOverlayState(
            accountPeerId: accountPeerId,
            firstName: firstName,
            lastName: lastName,
            phone: settings.normalizedAnonymousNumber,
            usernames: ManualProfileOverlay.makePeerUsernames(settings.normalizedUsernames),
            holdVerification: holdVerification,
            majorVerification: settings.majorVerification,
            photo: photo,
            gifts: gifts
        )
        return state.hasAnyOverride ? state : nil
    }
    
    private func prefetchGiftArtwork(_ gifts: [ManualOverlayGift]) {
        self.giftArtworkDisposable.set(prepareStarGiftArtwork(account: self.context.account, gifts: gifts.map { .unique($0.uniqueGift) }))
    }
    
    private func prefetchVerificationIcon(_ verification: PeerVerification?) {
        guard let verification, verification.iconFileId != 0 else {
            self.verificationIconDisposable.set(nil)
            return
        }
        self.verificationIconDisposable.set(self.context.engine.stickers.resolveInlineStickers(fileIds: [verification.iconFileId]).start())
    }
    
    private static func resolveGifts(engine: TelegramEngine, settings: ManualProfileSettings) -> Signal<ManualProfileSettings, NoError> {
        let missingSlugs = settings.gifts.filter(\.needsGiftResolve).map(\.slug)
        if missingSlugs.isEmpty {
            return .single(settings)
        }
        let resolved = missingSlugs.map { slug in
            engine.payments.getUniqueStarGift(slug: slug)
            |> map { gift -> (String, StarGift.UniqueGift?) in
                return (slug, gift)
            }
            |> `catch` { _ -> Signal<(String, StarGift.UniqueGift?), NoError> in
                return .single((slug, nil))
            }
        }
        return combineLatest(resolved)
        |> map { pairs -> ManualProfileSettings in
            var resolvedBySlug: [String: StarGift.UniqueGift] = [:]
            for (slug, gift) in pairs {
                if let gift, gift.hasRenderableArtwork {
                    resolvedBySlug[slug] = gift
                }
            }
            if !resolvedBySlug.isEmpty {
                let _ = updateManualProfileSettings(engine: engine, { current in
                    var current = current
                    current.gifts = current.gifts.map { entry in
                        var entry = entry
                        if entry.needsGiftResolve, let gift = resolvedBySlug[entry.slug], gift.hasRenderableArtwork {
                            entry.uniqueGift = gift
                            entry.title = gift.title
                            entry.number = gift.number
                        }
                        return entry
                    }
                    return current
                }).start()
            }
            var settings = settings
            settings.gifts = settings.gifts.map { entry in
                var entry = entry
                if entry.needsGiftResolve, let gift = resolvedBySlug[entry.slug], gift.hasRenderableArtwork {
                    entry.uniqueGift = gift
                    entry.title = gift.title
                    entry.number = gift.number
                }
                return entry
            }
            return settings
        }
    }
    
    private static func resolveHoldVerification(context: AccountContext, engine: TelegramEngine, settings: ManualProfileSettings) -> Signal<ManualProfileSettings, NoError> {
        if !settings.holdVerification {
            var settings = settings
            settings.holdVerificationInfo = nil
            return .single(settings)
        }
        self.upgradeHoldVerification(context: context, engine: engine, settings: settings)
        return .single(settings)
    }
    
    private static func upgradeHoldVerification(context: AccountContext, engine: TelegramEngine, settings: ManualProfileSettings) {
        let _ = (self.loadHoldVerification(context: context)
        |> take(1)
        |> timeout(20.0, queue: Queue.mainQueue(), alternate: .single(nil))).start(next: { verification in
            guard let verification, !verification.isPlaceholderOrganizationVerification, verification.iconFileId != 0 else {
                return
            }
            if settings.holdVerificationInfo == verification {
                return
            }
            let _ = updateManualProfileSettings(engine: engine, { current in
                var current = current
                if current.holdVerification {
                    current.holdVerificationInfo = verification
                }
                return current
            }).start()
        })
    }
    
    private static func loadHoldVerification(context: AccountContext) -> Signal<PeerVerification?, NoError> {
        return self.loadHoldVerification(context: context, username: "hold_verify")
        |> mapToSignal { verification -> Signal<PeerVerification?, NoError> in
            if let verification, !verification.isPlaceholderOrganizationVerification, verification.iconFileId != 0 {
                return .single(verification)
            }
            return self.loadHoldVerification(context: context, username: ManualProfileOverlay.holdVerifierUsername)
            |> map { fallback in
                if let fallback, !fallback.isPlaceholderOrganizationVerification, fallback.iconFileId != 0 {
                    return fallback
                }
                return verification
            }
        }
    }
    
    private static func loadHoldVerification(context: AccountContext, username: String) -> Signal<PeerVerification?, NoError> {
        return self.resolvePeerByName(context: context, name: username)
        |> mapToSignal { peer -> Signal<PeerVerification?, NoError> in
            guard let peer else {
                return .single(nil)
            }
            context.account.viewTracker.forceUpdateCachedPeerData(peerId: peer.id)
            return context.account.viewTracker.peerView(peer.id, updateData: true)
            |> map { view -> PeerVerification? in
                return self.verification(from: view, peer: peer, context: context)
            }
            |> filter { verification in
                return verification?.iconFileId != 0 && !(verification?.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            }
            |> take(1)
            |> timeout(8.0, queue: Queue.mainQueue(), alternate: .single(nil))
        }
    }
    
    private static func verification(from view: PeerView, peer: EnginePeer, context: AccountContext) -> PeerVerification? {
        if let verification = (view.cachedData as? CachedUserData)?.verification ?? (view.cachedData as? CachedChannelData)?.verification, verification.iconFileId != 0, !verification.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return verification
        }
        switch peer {
        case let .user(user):
            if let settings = (view.cachedData as? CachedUserData)?.botInfo?.verifierSettings, settings.iconFileId != 0 {
                let company = settings.companyName.isEmpty ? "Hold" : settings.companyName
                let localized = context.sharedContext.currentPresentationData.with { $0 }.strings.BotVerification_Verify_Placeholder(company).string
                return ManualProfileOverlay.organizationVerification(botId: user.id, settings: settings, fallbackDescription: localized)
            }
        default:
            break
        }
        if let iconFileId = peer.verificationIconFileId, iconFileId != 0 {
            return PeerVerification(botId: peer.id, iconFileId: iconFileId, description: ManualProfileOverlay.holdVerificationDescription)
        }
        return nil
    }
    
    private static func resolvePeerByName(context: AccountContext, name: String) -> Signal<EnginePeer?, NoError> {
        return context.engine.peers.resolvePeerByName(name: name, referrer: nil)
        |> filter { result in
            if case .progress = result {
                return false
            } else {
                return true
            }
        }
        |> map { result -> EnginePeer? in
            switch result {
            case let .result(peer):
                return peer
            case .progress:
                return nil
            }
        }
    }
    
    private static func restorePhotoIfNeeded(account: Account, settings: ManualProfileSettings) {
        guard let fileId = settings.photoFileId, let data = ManualProfileSettings.storedPhotoData() else {
            return
        }
        let resource = LocalFileMediaResource(fileId: fileId, size: Int64(data.count))
        account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
    }
}
