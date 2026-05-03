import Foundation

/// 麻将牌类型
enum TileSuit: String, CaseIterable, Codable {
    case wan = "万"   // 万子 1-9
    case tong = "筒"  // 筒子 1-9
    case tiao = "条"  // 条子 1-9
    case wind = "风"  // 东南西北
    case dragon = "箭" // 中发白
    
    var isHonor: Bool {
        self == .wind || self == .dragon
    }
}

/// 麻将牌
struct Tile: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let suit: TileSuit
    let rank: Int  // 数字牌 1-9，风牌 1-4(东南西北)，箭牌 1-3(中发白)
    
    init(suit: TileSuit, rank: Int) {
        self.id = UUID()
        self.suit = suit
        self.rank = rank
    }
    
    /// 牌的显示名称
    var displayName: String {
        switch suit {
        case .wan:
            return "\(rank)万"
        case .tong:
            return "\(rank)筒"
        case .tiao:
            return "\(rank)条"
        case .wind:
            let winds = ["", "东", "南", "西", "北"]
            return winds[rank]
        case .dragon:
            let dragons = ["", "中", "发", "白"]
            return dragons[rank]
        }
    }
    
    /// 牌的排序值（用于手牌排序）
    var sortValue: Int {
        let suitOrder: [TileSuit: Int] = [.wan: 0, .tong: 1, .tiao: 2, .wind: 3, .dragon: 4]
        return (suitOrder[suit] ?? 0) * 10 + rank
    }
    
    /// 是否为幺九牌（1或9）
    var isTerminal: Bool {
        !suit.isHonor && (rank == 1 || rank == 9)
    }
    
    /// 是否为字牌
    var isHonor: Bool {
        suit.isHonor
    }
    
    /// 是否为混牌（红中）
    var isJoker: Bool {
        suit == .dragon && rank == 1
    }
    
    /// 是否可以与另一张牌组成顺子（如 1,2 可与 3 组成顺子）
    func canSequenceWith(_ other: Tile) -> Bool {
        if suit != other.suit || suit.isHonor { return false }
        return abs(rank - other.rank) <= 2 && rank != other.rank
    }
}

/// 一组标准麻将牌（136张）
enum StandardTiles {
    static func createDeck() -> [Tile] {
        var tiles: [Tile] = []
        
        // 万子、筒子、条子（各1-9，每种4张）
        for suit in [TileSuit.wan, .tong, .tiao] {
            for rank in 1...9 {
                for _ in 0..<4 {
                    tiles.append(Tile(suit: suit, rank: rank))
                }
            }
        }
        
        // 风牌（东南西北，各4张）
        for rank in 1...4 {
            for _ in 0..<4 {
                tiles.append(Tile(suit: .wind, rank: rank))
            }
        }
        
        // 箭牌（中发白，各4张）
        for rank in 1...3 {
            for _ in 0..<4 {
                tiles.append(Tile(suit: .dragon, rank: rank))
            }
        }
        
        return tiles
    }
}

/// 牌组类型（吃碰杠）
enum MeldType: String, Codable {
    case chow = "吃"      // 顺子
    case pong = "碰"      // 刻子
    case kong = "杠"      // 杠子
    case concealedKong = "暗杠" // 暗杠
}

/// 副露（吃碰杠的组合）
struct Meld: Identifiable, Codable {
    let id: UUID
    let type: MeldType
    let tiles: [Tile]
    let fromPlayerIndex: Int  // 从哪个玩家处获得最后一张牌
    let claimedTile: Tile     // 吃碰杠的那张牌
    
    init(type: MeldType, tiles: [Tile], fromPlayerIndex: Int, claimedTile: Tile) {
        self.id = UUID()
        self.type = type
        self.tiles = tiles.sorted { $0.sortValue < $1.sortValue }
        self.fromPlayerIndex = fromPlayerIndex
        self.claimedTile = claimedTile
    }
}

/// 玩家位置
enum PlayerPosition: Int, CaseIterable, Codable {
    case east = 0
    case south = 1
    case west = 2
    case north = 3
    
    var displayName: String {
        ["东家", "南家", "西家", "北家"][rawValue]
    }
    
    var shortName: String {
        ["东", "南", "西", "北"][rawValue]
    }
}
