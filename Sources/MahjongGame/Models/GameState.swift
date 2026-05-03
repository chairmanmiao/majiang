import Foundation

/// 游戏阶段
enum GamePhase: String, Codable {
    case waiting = "等待中"
    case dealing = "发牌中"
    case playing = "进行中"
    case discarding = "出牌中"
    case claiming = "鸣牌中"
    case roundEnd = "局结束"
    case gameOver = "游戏结束"
}

/// 应用当前屏幕
enum AppScreen: String, Codable {
    case menu = "菜单"
    case game = "游戏"
    case settings = "设置"
    case loadGame = "读取游戏"
}

/// 动作类型
enum GameAction: String, Codable {
    case draw = "摸牌"
    case discard = "打牌"
    case chow = "吃"
    case pong = "碰"
    case kong = "杠"
    case concealedKong = "暗杠"
    case addKong = "加杠"
    case win = "胡"
    case readyHand = "听牌"
}

/// 胡牌方式
enum WinType: String, Codable {
    case selfDraw = "自摸"
    case claim = "点炮"
}

/// 可用的动作选项
struct AvailableAction: Identifiable, Codable {
    var id = UUID()
    let action: GameAction
    let tiles: [Tile]
    let meld: Meld?
    let description: String
    let winType: WinType?  // 用于胡牌动作区分自摸/点炮
    let targetPlayerIndex: Int? // 该动作属于哪个玩家
}

/// 对局结果
struct RoundResult: Identifiable, Codable {
    var id = UUID()
    let winnerIndex: Int?
    let loserIndex: Int?
    let winType: WinType?
    let handScore: Int
    let fanCount: Int
    let fanNames: [String]
    let message: String
}

/// 提示消息
struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let type: ToastType
    let duration: Double
}

enum ToastType {
    case info
    case success
    case warning
    case error
    
    var color: String {
        switch self {
        case .info: return "info"
        case .success: return "success"
        case .warning: return "warning"
        case .error: return "error"
        }
    }
}

// MARK: - 游戏设置
struct GameSettings: Codable {
    var playerName: String = "玩家"
    var enableAnimation: Bool = true
    var enableSound: Bool = true
    var tableColor: TableColor = .green
    var turnTimeLimit: Double = 15.0
    
    enum TableColor: String, Codable, CaseIterable {
        case green = "墨绿"
        case blue = "深蓝"
        case brown = "棕木"
        
        var colorValue: (red: Double, green: Double, blue: Double) {
            switch self {
            case .green: return (0.1, 0.35, 0.18)
            case .blue: return (0.08, 0.2, 0.35)
            case .brown: return (0.25, 0.15, 0.08)
            }
        }
    }
    
    static let `default` = GameSettings()
    
    static func load() -> GameSettings {
        guard let data = UserDefaults.standard.data(forKey: "mahjong_settings") else {
            return .default
        }
        return (try? JSONDecoder().decode(GameSettings.self, from: data)) ?? .default
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "mahjong_settings")
        }
    }
}

// MARK: - 游戏存档
struct GameSave: Identifiable, Codable {
    let id: UUID
    let date: Date
    let saveName: String
    
    // 游戏状态
    let players: [Player]
    let wall: [Tile]
    let deadWall: [Tile]
    let currentPlayerIndex: Int
    let phase: GamePhase
    let currentRound: Int
    let roundWind: PlayerPosition
    let doraIndicator: Tile?
    let lastDiscardedTile: Tile?
    let lastDiscardPlayerIndex: Int
    let actionLog: [String]
    let isPausedForClaim: Bool
    let timeRemaining: Double
    let isTimerActive: Bool
    let isPaused: Bool
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}
