import Foundation

/// 玩家
class Player: ObservableObject, Codable, Identifiable {
    let id: UUID
    let name: String
    let position: PlayerPosition
    let isAI: Bool
    
    @Published var hand: [Tile] = []
    @Published var melds: [Meld] = []
    @Published var discardPile: [Tile] = []
    @Published var isDealer: Bool = false
    @Published var score: Int = 0
    @Published var isReadyHand: Bool = false  // 是否听牌
    
    enum CodingKeys: String, CodingKey {
        case id, name, position, isAI, hand, melds, discardPile, isDealer, score, isReadyHand
    }
    
    init(name: String, position: PlayerPosition, isAI: Bool) {
        self.id = UUID()
        self.name = name
        self.position = position
        self.isAI = isAI
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(position, forKey: .position)
        try container.encode(isAI, forKey: .isAI)
        try container.encode(hand, forKey: .hand)
        try container.encode(melds, forKey: .melds)
        try container.encode(discardPile, forKey: .discardPile)
        try container.encode(isDealer, forKey: .isDealer)
        try container.encode(score, forKey: .score)
        try container.encode(isReadyHand, forKey: .isReadyHand)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        position = try container.decode(PlayerPosition.self, forKey: .position)
        isAI = try container.decode(Bool.self, forKey: .isAI)
        hand = try container.decode([Tile].self, forKey: .hand)
        melds = try container.decode([Meld].self, forKey: .melds)
        discardPile = try container.decode([Tile].self, forKey: .discardPile)
        isDealer = try container.decode(Bool.self, forKey: .isDealer)
        score = try container.decode(Int.self, forKey: .score)
        isReadyHand = try container.decode(Bool.self, forKey: .isReadyHand)
    }
    
    /// 手牌张数
    var handCount: Int {
        hand.count
    }
    
    /// 排序手牌
    func sortHand() {
        hand.sort { $0.sortValue < $1.sortValue }
    }
    
    /// 添加一张牌到手牌
    func drawTile(_ tile: Tile) {
        hand.append(tile)
        sortHand()
    }
    
    /// 打出一张牌
    func discardTile(_ tile: Tile) -> Bool {
        guard let index = hand.firstIndex(where: { $0.id == tile.id }) else { return false }
        hand.remove(at: index)
        discardPile.append(tile)
        return true
    }
    
    /// 从手牌中移除指定牌（用于吃碰杠）
    func removeTiles(_ tiles: [Tile]) {
        for tile in tiles {
            if let index = hand.firstIndex(where: { $0.id == tile.id }) {
                hand.remove(at: index)
            }
        }
    }
    
    /// 添加副露
    func addMeld(_ meld: Meld) {
        melds.append(meld)
        if meld.type == .concealedKong {
            // 暗杠：4张牌全部在自己手牌中，全部移除
            removeTiles(meld.tiles)
        } else {
            // 从手牌中移除组成副露的牌（除了吃碰杠来的那张）
            let tilesToRemove = meld.tiles.filter { $0.id != meld.claimedTile.id }
            removeTiles(tilesToRemove)
        }
    }
    
    /// 将碰升级为杠（加杠）
    func upgradePongToKong(meld: Meld, newTile: Tile) {
        guard let index = melds.firstIndex(where: { $0.id == meld.id }) else { return }
        var newTiles = meld.tiles
        newTiles.append(newTile)
        let newMeld = Meld(type: .kong, tiles: newTiles, fromPlayerIndex: 0, claimedTile: newTile)
        melds[index] = newMeld
        // 从手牌中移除新加的那张牌
        if let handIndex = hand.firstIndex(where: { $0.id == newTile.id }) {
            hand.remove(at: handIndex)
        }
    }
    
    /// 是否可以暗杠（支持红中当混：某牌+红中>=4张）
    func canConcealedKong() -> [Tile] {
        let jokers = hand.filter(\.isJoker)
        let nonJokers = hand.filter { !$0.isJoker }
        let grouped = Dictionary(grouping: nonJokers) { $0.displayName }
        var result: [Tile] = []
        
        // 4张相同非红中牌
        for (_, tiles) in grouped {
            if tiles.count == 4, let first = tiles.first {
                result.append(first)
            }
        }
        
        // 3张相同 + 1红中
        if !jokers.isEmpty {
            for (_, tiles) in grouped {
                if tiles.count == 3, let first = tiles.first {
                    result.append(first)
                }
            }
        }
        
        // 2张相同 + 2红中
        if jokers.count >= 2 {
            for (_, tiles) in grouped {
                if tiles.count == 2, let first = tiles.first {
                    result.append(first)
                }
            }
        }
        
        // 1张 + 3红中
        if jokers.count >= 3 {
            for (_, tiles) in grouped {
                if tiles.count == 1, let first = tiles.first {
                    result.append(first)
                }
            }
        }
        
        // 4张红中
        if jokers.count == 4, let first = jokers.first {
            result.append(first)
        }
        
        return result
    }
    
    /// 是否可以加杠（支持红中当混：新摸红中可加任何碰）
    func canAddKong(newTile: Tile) -> [Meld] {
        melds.filter { meld in
            guard meld.type == .pong else { return false }
            if newTile.displayName == meld.tiles.first?.displayName { return true }
            if newTile.isJoker { return true }  // 红中可以当任何牌加杠
            return false
        }
    }
    
    /// 重置玩家状态
    func reset() {
        hand = []
        melds = []
        discardPile = []
        isReadyHand = false
    }
}
