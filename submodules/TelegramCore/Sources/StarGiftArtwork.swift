import Foundation
import Postbox
import SwiftSignalKit

extension StarGift {
    public var artworkFiles: [TelegramMediaFile] {
        switch self {
        case let .generic(gift):
            return [gift.file]
        case let .unique(unique):
            return unique.artworkFiles
        }
    }
    
    public func withRestoredArtwork(transaction: Transaction) -> StarGift {
        switch self {
        case .generic:
            return self
        case let .unique(unique):
            return .unique(unique.withRestoredArtwork(transaction: transaction))
        }
    }
}

extension StarGift.UniqueGift {
    public var artworkFiles: [TelegramMediaFile] {
        var files: [TelegramMediaFile] = []
        for attribute in self.attributes {
            switch attribute {
            case let .model(_, file, _, _):
                files.append(file)
            case let .pattern(_, file, _):
                files.append(file)
            default:
                break
            }
        }
        return files
    }
    
    public var hasRenderableArtwork: Bool {
        guard let file = self.itemFile else {
            return false
        }
        return isRenderableStarGiftFile(file)
    }
    
    public func withRestoredArtwork(transaction: Transaction) -> StarGift.UniqueGift {
        let attributes = self.attributes.map { attribute -> StarGift.UniqueGift.Attribute in
            switch attribute {
            case let .model(name, file, rarity, crafted):
                return .model(name: name, file: restoredStarGiftMediaFile(file, transaction: transaction), rarity: rarity, crafted: crafted)
            case let .pattern(name, file, rarity):
                return .pattern(name: name, file: restoredStarGiftMediaFile(file, transaction: transaction), rarity: rarity)
            default:
                return attribute
            }
        }
        return StarGift.UniqueGift(
            id: self.id,
            giftId: self.giftId,
            title: self.title,
            number: self.number,
            slug: self.slug,
            owner: self.owner,
            attributes: attributes,
            availability: self.availability,
            giftAddress: self.giftAddress,
            resellAmounts: self.resellAmounts,
            resellForTonOnly: self.resellForTonOnly,
            releasedBy: self.releasedBy,
            valueAmount: self.valueAmount,
            valueCurrency: self.valueCurrency,
            valueUsdAmount: self.valueUsdAmount,
            flags: self.flags,
            themePeerId: self.themePeerId,
            peerColor: self.peerColor,
            hostPeerId: self.hostPeerId,
            minOfferStars: self.minOfferStars,
            craftChancePermille: self.craftChancePermille
        )
    }
    
    public func serializedPostboxData() -> Data {
        let encoder = PostboxEncoder()
        self.encode(encoder)
        return encoder.makeData()
    }
    
    public static func fromPostboxData(_ data: Data) -> StarGift.UniqueGift? {
        let gift = StarGift.UniqueGift(decoder: PostboxDecoder(buffer: MemoryBuffer(data: data)))
        return gift.hasRenderableArtwork ? gift : nil
    }
}

public func isRenderableStarGiftFile(_ file: TelegramMediaFile) -> Bool {
    guard let resource = file.resource as? CloudDocumentMediaResource else {
        return false
    }
    return resource.fileId != 0 && resource.accessHash != 0
}

public func restoredStarGiftMediaFile(_ file: TelegramMediaFile, transaction: Transaction) -> TelegramMediaFile {
    if isRenderableStarGiftFile(file) {
        transaction.storeMediaIfNotPresent(media: file)
        return file
    }
    if let stored = transaction.getMedia(file.fileId) as? TelegramMediaFile, isRenderableStarGiftFile(stored) {
        return stored
    }
    transaction.storeMediaIfNotPresent(media: file)
    return file
}

public func storeStarGiftArtwork(transaction: Transaction, files: [TelegramMediaFile]) {
    for file in files {
        transaction.storeMediaIfNotPresent(media: file)
    }
}

public func fetchStarGiftArtwork(account: Account, files: [TelegramMediaFile]) -> Disposable {
    let disposable = DisposableSet()
    var seen = Set<MediaId>()
    for file in files {
        guard isRenderableStarGiftFile(file), !seen.contains(file.fileId) else {
            continue
        }
        seen.insert(file.fileId)
        disposable.add((fetchedMediaResource(
            mediaBox: account.postbox.mediaBox,
            userLocation: .other,
            userContentType: .sticker,
            reference: FileMediaReference.forGiftFile(file).resourceReference(file.resource)
        )
        |> map { _ in }
        |> `catch` { _ -> Signal<Void, NoError> in
            return .complete()
        }).start())
    }
    return disposable
}

public func prepareStarGiftArtwork(account: Account, files: [TelegramMediaFile]) -> Disposable {
    let disposable = DisposableSet()
    disposable.add(account.postbox.transaction({ transaction in
        storeStarGiftArtwork(transaction: transaction, files: files)
    }).start())
    disposable.add(fetchStarGiftArtwork(account: account, files: files))
    return disposable
}

public func prepareStarGiftArtwork(account: Account, gifts: [StarGift]) -> Disposable {
    return prepareStarGiftArtwork(account: account, files: gifts.flatMap(\.artworkFiles))
}
