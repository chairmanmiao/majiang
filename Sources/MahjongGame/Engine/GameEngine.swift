import Foundation
import Combine

/// 麻将游戏引擎
class GameEngine: ObservableObject {
    @Published var players: [Player] = []
    @Published var wall: [Tile] = []           // 牌墙
    @Published var deadWall: [Tile] = []       // 王牌/岭上
    @Published var currentPlayerIndex: Int = 0
    @Published var phase: GamePhase = .waiting
    @Published var lastDiscardedTile: Tile?
    @Published var lastDiscardPlayerIndex: Int = -1
    @Published var currentRound: Int = 1
    @Published var roundWind: PlayerPosition = .east
    @Published var doraIndicator: Tile?
    @Published var result: RoundResult?
    @Published var actionLog: [String] = []
    @Published var availableActions: [AvailableAction] = []
    @Published var isPausedForClaim: Bool = false
    @Published var toastMessage: ToastMessage?
    @Published var timeRemaining: Double = 15.0
    @Published var isTimerActive: Bool = false
    @Published var isPaused: Bool = false
    @Published var uiRefreshTrigger: Int = 0  // 强制 SwiftUI 刷新的触发器
    
    private var claimWaitTimer: Timer?
    private var countdownTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let turnTimeLimit: Double = 15.0
    
    /// 当前玩家
    var currentPlayer: Player? {
        guard players.indices.contains(currentPlayerIndex) else { return nil }
        return players[currentPlayerIndex]
    }
    
    /// 当前操作玩家是否为人类
    var isHumanTurn: Bool {
        currentPlayer?.isAI == false && phase != .claiming
    }
    
    /// 牌墙剩余张数
    var wallCount: Int {
        wall.count
    }
    
    /// 倒计时进度 0.0~1.0
    var countdownProgress: Double {
        guard turnTimeLimit > 0 else { return 0 }
        return max(0, min(1, timeRemaining / turnTimeLimit))
    }
    
    /// 初始化游戏
    func setupGame(humanName: String = "玩家") {
        players = [
            Player(name: humanName, position: .east, isAI: false),
            Player(name: "电脑-南", position: .south, isAI: true),
            Player(name: "电脑-西", position: .west, isAI: true),
            Player(name: "电脑-北", position: .north, isAI: true)
        ]
        currentRound = 1
        roundWind = .east
        startNewRound()
    }
    
    /// 开始新的一局
    func startNewRound() {
        stopCountdown()
        phase = .dealing
        result = nil
        availableActions = []
        isPausedForClaim = false
        lastDiscardedTile = nil
        lastDiscardPlayerIndex = -1
        actionLog = ["第\(currentRound)局开始，本局场风：\(roundWind.shortName)风"]
        showToast("第\(currentRound)局开始！", type: .info)
        
        // 重置玩家
        for player in players {
            player.reset()
        }
        
        // 创建并洗牌
        var deck = StandardTiles.createDeck()
        deck.shuffle()
        
        // 留王牌（8张）
        deadWall = Array(deck.suffix(8))
        wall = Array(deck.dropLast(8))
        
        // 设置庄家
        let dealerIndex = (currentRound - 1) % 4
        for (i, player) in players.enumerated() {
            player.isDealer = (i == dealerIndex)
        }
        currentPlayerIndex = dealerIndex
        
        // 发牌：每人13张
        for _ in 0..<13 {
            for i in 0..<4 {
                if let tile = wall.popLast() {
                    players[i].drawTile(tile)
                }
            }
        }
        
        // 设置宝牌指示牌（王牌第一张）
        doraIndicator = deadWall.first
        
        phase = .playing
        log("发牌完毕，庄家：\(players[dealerIndex].name)")
        
        // 庄家先摸牌
        drawForCurrentPlayer()
    }
    
    /// 当前玩家摸牌
    func drawForCurrentPlayer() {
        guard phase == .playing || phase == .discarding else { return }
        guard let player = currentPlayer else { return }
        
        if wall.isEmpty {
            // 流局
            endRound(winner: nil, loser: nil, winType: nil)
            return
        }
        
        let tile = wall.popLast()!
        player.drawTile(tile)
        phase = .discarding
        
        log("\(player.name) 摸了一张牌")
        
        // 检查自摸、暗杠、加杠
        checkSelfActionsAfterDraw(tile: tile)
    }
    
    // MARK: - 倒计时
    
    /// 启动出牌倒计时
    func startDiscardTimer() {
        guard let player = currentPlayer, !player.isAI else { return }
        guard phase == .discarding else { return }
        guard !isPaused else { return }
        stopCountdown()
        timeRemaining = turnTimeLimit
        isTimerActive = true
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tickCountdown()
        }
    }
    
    /// 倒计时滴答
    private func tickCountdown() {
        guard isTimerActive, !isPaused else { return }
        timeRemaining -= 0.1
        if timeRemaining <= 0 {
            timeRemaining = 0
            isTimerActive = false
            countdownTimer?.invalidate()
            countdownTimer = nil
            autoDiscardOnTimeout()
        }
    }
    
    /// 切换暂停状态
    func togglePause() {
        isPaused.toggle()
        if isPaused {
            showToast("⏸ 游戏已暂停", type: .info, duration: 2.0)
        } else {
            showToast("▶ 游戏继续", type: .success, duration: 1.5)
        }
    }
    
    /// 停止倒计时
    func stopCountdown() {
        isTimerActive = false
        countdownTimer?.invalidate()
        countdownTimer = nil
        timeRemaining = turnTimeLimit
    }
    
    /// 超时自动打牌
    private func autoDiscardOnTimeout() {
        guard let player = currentPlayer, !player.isAI, phase == .discarding else { return }
        let tile = suggestedDiscardTile(player: player)
        showToast("⏰ 时间到！自动打出 \(tile.displayName)", type: .warning, duration: 2.0)
        discardTile(tile)
    }
    
    /// 人类玩家跳过自摸/暗杠，直接打牌
    func skipSelfActionsAndDiscard() {
        availableActions = []
        startDiscardTimer()
    }
    
    /// 摸牌后检查可执行动作
    func checkSelfActionsAfterDraw(tile: Tile) {
        guard let player = currentPlayer else { return }
        availableActions = []
        
        // 检查自摸胡牌
        if canWin(tiles: player.hand) {
            availableActions.append(AvailableAction(
                action: .win,
                tiles: player.hand,
                meld: nil,
                description: "\(player.name) 自摸胡牌",
                winType: .selfDraw,
                targetPlayerIndex: currentPlayerIndex
            ))
        }
        
        // 检查暗杠
        let concealedKongTiles = player.canConcealedKong()
        for t in concealedKongTiles {
            availableActions.append(AvailableAction(
                action: .concealedKong,
                tiles: [t],
                meld: nil,
                description: "\(player.name) 暗杠 \(t.displayName)",
                winType: nil,
                targetPlayerIndex: currentPlayerIndex
            ))
        }
        
        // 检查加杠
        let addKongMelds = player.canAddKong(newTile: tile)
        for meld in addKongMelds {
            availableActions.append(AvailableAction(
                action: .addKong,
                tiles: [tile],
                meld: meld,
                description: "\(player.name) 加杠 \(tile.displayName)",
                winType: nil,
                targetPlayerIndex: currentPlayerIndex
            ))
        }
        
        // 如果没有特殊动作，必须打牌
        if availableActions.isEmpty {
            if player.isAI {
                // AI自动打牌
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.aiDiscard()
                }
            } else {
                // 人类玩家开始倒计时
                startDiscardTimer()
            }
        } else {
            // 有可选动作，AI自动选择
            if player.isAI {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    self?.aiChooseActionAfterDraw()
                }
            } else {
                // 人类玩家有可选项，显示提示
                if availableActions.contains(where: { $0.action == .win }) {
                    showToast("🎉 恭喜！可以自摸胡牌！", type: .success, duration: 3.0)
                }
            }
        }
    }
    
    /// 玩家打牌
    func discardTile(_ tile: Tile) {
        guard phase == .discarding else { return }
        guard let player = currentPlayer else { return }
        guard player.discardTile(tile) else { return }
        
        stopCountdown()
        lastDiscardedTile = tile
        lastDiscardPlayerIndex = currentPlayerIndex
        phase = .claiming
        availableActions = []
        
        log("\(player.name) 打出 \(tile.displayName)")
        showToast("\(player.name) 打出 \(tile.displayName)", type: .info, duration: 1.5)
        
        // 检查其他玩家是否可以吃碰杠胡
        checkClaimActions(discardedTile: tile)
    }
    
    /// 检查其他玩家对打出的牌的动作（支持红中当混）
    func checkClaimActions(discardedTile: Tile) {
        var anyCanClaim = false
        var allActions: [AvailableAction] = []
        
        for i in 0..<4 {
            if i == lastDiscardPlayerIndex { continue }
            let player = players[i]
            let distance = (i - lastDiscardPlayerIndex + 4) % 4
            let handJokers = player.hand.filter(\.isJoker)
            
            // 检查胡牌（所有人都可以）
            let testHand = player.hand + [discardedTile]
            if canWin(tiles: testHand) {
                anyCanClaim = true
                allActions.append(AvailableAction(
                    action: .win,
                    tiles: testHand,
                    meld: nil,
                    description: "\(player.name) 胡 \(discardedTile.displayName)",
                    winType: .claim,
                    targetPlayerIndex: i
                ))
            }
            
            // 检查碰（支持红中当混）
            let pongNormal = player.hand.filter { $0.displayName == discardedTile.displayName && !$0.isJoker }
            let canPong = pongNormal.count + handJokers.count >= 2
            if canPong {
                anyCanClaim = true
                var meldTiles: [Tile] = []
                for t in pongNormal.prefix(2) { meldTiles.append(t) }
                while meldTiles.count < 2, !handJokers.isEmpty {
                    meldTiles.append(handJokers[meldTiles.count - pongNormal.count])
                }
                meldTiles.append(discardedTile)
                allActions.append(AvailableAction(
                    action: .pong,
                    tiles: meldTiles,
                    meld: Meld(type: .pong, tiles: meldTiles, fromPlayerIndex: lastDiscardPlayerIndex, claimedTile: discardedTile),
                    description: "\(player.name) 碰 \(discardedTile.displayName)",
                    winType: nil,
                    targetPlayerIndex: i
                ))
            }
            
            // 检查杠（支持红中当混）
            let canKong = pongNormal.count + handJokers.count >= 3
            if canKong {
                anyCanClaim = true
                var meldTiles: [Tile] = []
                for t in pongNormal.prefix(3) { meldTiles.append(t) }
                while meldTiles.count < 3, !handJokers.isEmpty {
                    meldTiles.append(handJokers[meldTiles.count - pongNormal.count])
                }
                meldTiles.append(discardedTile)
                allActions.append(AvailableAction(
                    action: .kong,
                    tiles: meldTiles,
                    meld: Meld(type: .kong, tiles: meldTiles, fromPlayerIndex: lastDiscardPlayerIndex, claimedTile: discardedTile),
                    description: "\(player.name) 杠 \(discardedTile.displayName)",
                    winType: nil,
                    targetPlayerIndex: i
                ))
            }
            
            // 检查吃（只有下家可以，支持红中当混）
            if distance == 1 {
                let chowOptions = findChowOptions(hand: player.hand, tile: discardedTile)
                for option in chowOptions {
                    anyCanClaim = true
                    let meldTiles = option + [discardedTile]
                    allActions.append(AvailableAction(
                        action: .chow,
                        tiles: meldTiles,
                        meld: Meld(type: .chow, tiles: meldTiles, fromPlayerIndex: lastDiscardPlayerIndex, claimedTile: discardedTile),
                        description: "\(player.name) 吃 \(discardedTile.displayName)",
                        winType: nil,
                        targetPlayerIndex: i
                    ))
                }
            }
        }
        
        if anyCanClaim {
            isPausedForClaim = true
            availableActions = allActions
            
            // 检查优先级：胡 > 杠/碰 > 吃
            processPriorityClaims()
        } else {
            // 无人要牌，轮到下家
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.nextTurn()
            }
        }
    }
    
    /// 处理优先级（胡牌优先）
    private func processPriorityClaims() {
        // 检查是否有人可以胡牌
        let winActions = availableActions.filter { $0.action == .win }
        if !winActions.isEmpty {
            // 有胡牌时，优先处理胡牌
            // 按座位顺序处理
            if let winAction = winActions.sorted(by: { 
                ($0.targetPlayerIndex ?? 0) < ($1.targetPlayerIndex ?? 0)
            }).first {
                if let playerIndex = winAction.targetPlayerIndex {
                    if players[playerIndex].isAI {
                        // AI自动胡
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                            self?.executeClaim(action: winAction, playerIndex: playerIndex)
                        }
                    } else {
                        showToast("🎉 可以胡牌！", type: .success, duration: 3.0)
                    }
                }
            }
            return
        }
        
        // 没有胡牌时，AI自动选择碰杠吃
        for i in 0..<4 {
            if i == lastDiscardPlayerIndex { continue }
            let playerActions = availableActions.filter {
                $0.targetPlayerIndex == i
            }
            if !playerActions.isEmpty, players[i].isAI {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.aiChooseClaimAction(playerIndex: i, actions: playerActions)
                }
                return // 只处理第一个有动作的AI
            }
        }
        
        // 如果只剩下人类玩家的动作，等待用户选择
        let humanActions = availableActions.filter { $0.targetPlayerIndex == 0 }
        if !humanActions.isEmpty {
            let actionNames = humanActions.map { $0.action.rawValue }.joined(separator: "/")
            showToast("可以 \(actionNames)！请选择", type: .warning, duration: 4.0)
        }
    }
    
    /// 执行鸣牌动作
    func executeClaim(action: AvailableAction, playerIndex: Int) {
        let player = players[playerIndex]
        
        switch action.action {
        case .win:
            let winType = action.winType ?? .claim
            endRound(winner: playerIndex, loser: lastDiscardPlayerIndex, winType: winType)
            
        case .pong, .chow, .kong:
            if let meld = action.meld {
                player.addMeld(meld)
                log(action.description)
                showToast(action.description, type: .info, duration: 2.0)
                
                // 明杠计分：被杠家给1分给明杠家
                if action.action == .kong {
                    applyMingKongScore(kongPlayerIndex: playerIndex, fromPlayerIndex: meld.fromPlayerIndex)
                }
                
                currentPlayerIndex = playerIndex
                phase = .discarding
                isPausedForClaim = false
                availableActions = []
                
                if player.isAI {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                        self?.aiDiscard()
                    }
                } else {
                    startDiscardTimer()
                }
            }
            
        default:
            break
        }
    }
    
    /// 人类玩家选择过牌
    func passClaim() {
        // 移除当前人类玩家的可选动作
        availableActions = availableActions.filter {
            !($0.targetPlayerIndex == 0 && ($0.action == .chow || $0.action == .pong || $0.action == .kong))
        }
        
        showToast("选择过牌", type: .info, duration: 1.0)
        
        // 如果还有AI动作，继续处理
        if !availableActions.isEmpty {
            processPriorityClaims()
        } else {
            isPausedForClaim = false
            nextTurn()
        }
    }
    
    /// 轮到下一家
    func nextTurn() {
        stopCountdown()
        isPausedForClaim = false
        availableActions = []
        currentPlayerIndex = (currentPlayerIndex + 1) % 4
        phase = .playing
        drawForCurrentPlayer()
    }
    
    /// 结束一局
    func endRound(winner: Int?, loser: Int?, winType: WinType?) {
        stopCountdown()
        isPausedForClaim = false
        availableActions = []
        phase = .roundEnd
        
        var message = ""
        var handScore = 0
        var fanCount = 0
        var fanNames: [String] = []
        
        if let winner = winner {
            let wt = winType ?? .claim
            message = "\(players[winner].name) \(wt.rawValue) 获胜！"
            
            // 计分：赢家+6，其他三家各-2
            let winPoints = 6
            let losePoints = 2
            
            if wt == .selfDraw {
                fanCount = 1
                fanNames = ["自摸"]
            } else {
                fanCount = 1
                fanNames = ["点炮"]
            }
            
            // 赢家得分
            players[winner].score += winPoints
            // 其他三家失分
            for i in 0..<4 {
                if i != winner {
                    players[i].score -= losePoints
                }
            }
            
            handScore = winPoints
            showToast(message, type: .success, duration: 5.0)
        } else {
            message = "流局，无人胡牌"
            showToast(message, type: .warning, duration: 3.0)
        }
        
        // 触发 SwiftUI 更新
        uiRefreshTrigger += 1
        players = players
        
        result = RoundResult(
            winnerIndex: winner,
            loserIndex: loser,
            winType: winType,
            handScore: handScore,
            fanCount: fanCount,
            fanNames: fanNames,
            message: message
        )
        
        log(message)
    }
    
    /// 开始下一局
    func nextRound() {
        currentRound += 1
        roundWind = PlayerPosition(rawValue: (currentRound - 1) % 4)!
        startNewRound()
    }
    
    /// 记录日志
    func log(_ message: String) {
        actionLog.append(message)
    }
    
    /// 显示提示
    func showToast(_ text: String, type: ToastType = .info, duration: Double = 2.0) {
        toastMessage = ToastMessage(text: text, type: type, duration: duration)
    }
    
    // MARK: - 胡牌算法
    
    // MARK: - 胡牌算法（支持红中当混）
    
    /// 判断一组牌是否胡牌（红中可当任意牌）
    func canWin(tiles: [Tile]) -> Bool {
        guard tiles.count == 14 || tiles.count % 3 == 2 else { return false }
        
        let jokers = tiles.filter(\.isJoker).count
        let normalTiles = tiles.filter { !$0.isJoker }.sorted { $0.sortValue < $1.sortValue }
        let meldsNeeded = (normalTiles.count + jokers - 2) / 3
        
        return canFormHand(normalTiles: normalTiles, jokers: jokers, needsPair: true, meldsNeeded: meldsNeeded)
    }
    
    /// 递归判断能否组成完整手牌
    private func canFormHand(normalTiles: [Tile], jokers: Int, needsPair: Bool, meldsNeeded: Int) -> Bool {
        if normalTiles.isEmpty {
            if needsPair {
                if jokers >= 2 {
                    let remainingJokers = jokers - 2
                    return remainingJokers % 3 == 0 && remainingJokers / 3 == meldsNeeded
                }
                return false
            } else {
                return jokers % 3 == 0 && jokers / 3 == meldsNeeded
            }
        }
        
        if !needsPair {
            return canFormMelds(normalTiles: normalTiles, jokers: jokers, meldsNeeded: meldsNeeded)
        }
        
        // 收集所有不同的牌名（用于遍历所有可能的对子）
        var seenNames = Set<String>()
        var uniqueTiles: [Tile] = []
        for tile in normalTiles {
            if !seenNames.contains(tile.displayName) {
                seenNames.insert(tile.displayName)
                uniqueTiles.append(tile)
            }
        }
        
        // 尝试所有"两张相同牌"做对子
        for tile in uniqueTiles {
            let name = tile.displayName
            let sameCount = normalTiles.filter { $0.displayName == name }.count
            if sameCount >= 2 {
                var remaining = normalTiles
                for _ in 0..<2 {
                    if let idx = remaining.firstIndex(where: { $0.displayName == name }) {
                        remaining.remove(at: idx)
                    }
                }
                if canFormMelds(normalTiles: remaining, jokers: jokers, meldsNeeded: meldsNeeded) {
                    return true
                }
            }
        }
        
        // 尝试"一张牌 + 一张joker"做对子
        if jokers >= 1 {
            for tile in uniqueTiles {
                let name = tile.displayName
                var remaining = normalTiles
                if let idx = remaining.firstIndex(where: { $0.displayName == name }) {
                    remaining.remove(at: idx)
                }
                if canFormMelds(normalTiles: remaining, jokers: jokers - 1, meldsNeeded: meldsNeeded) {
                    return true
                }
            }
        }
        
        // 用两张joker做将
        if jokers >= 2 {
            if canFormMelds(normalTiles: normalTiles, jokers: jokers - 2, meldsNeeded: meldsNeeded) {
                return true
            }
        }
        
        return false
    }
    
    /// 递归判断剩余牌+joker能否组成指定数量的面子
    private func canFormMelds(normalTiles: [Tile], jokers: Int, meldsNeeded: Int) -> Bool {
        if meldsNeeded == 0 {
            return normalTiles.isEmpty && jokers == 0
        }
        
        guard !normalTiles.isEmpty || jokers > 0 else { return false }
        
        if normalTiles.isEmpty {
            return jokers >= 3 && canFormMelds(normalTiles: [], jokers: jokers - 3, meldsNeeded: meldsNeeded - 1)
        }
        
        let first = normalTiles[0]
        
        // 尝试组成刻子
        let sameCount = normalTiles.filter { $0.displayName == first.displayName }.count
        let neededForPong = max(0, 3 - sameCount)
        if jokers >= neededForPong {
            var remaining = normalTiles
            for _ in 0..<min(sameCount, 3) {
                if let idx = remaining.firstIndex(where: { $0.displayName == first.displayName }) {
                    remaining.remove(at: idx)
                }
            }
            if canFormMelds(normalTiles: remaining, jokers: jokers - neededForPong, meldsNeeded: meldsNeeded - 1) {
                return true
            }
        }
        
        // 尝试组成顺子（只对数字牌，且不能是8或9开头）
        if !first.suit.isHonor && first.rank <= 7 {
            let r1 = first.rank + 1
            let r2 = first.rank + 2
            let hasR1 = normalTiles.contains { $0.suit == first.suit && $0.rank == r1 }
            let hasR2 = normalTiles.contains { $0.suit == first.suit && $0.rank == r2 }
            
            var neededJokers = 0
            if !hasR1 { neededJokers += 1 }
            if !hasR2 { neededJokers += 1 }
            
            if jokers >= neededJokers {
                var remaining = normalTiles
                if let idx = remaining.firstIndex(where: { $0.id == first.id }) {
                    remaining.remove(at: idx)
                }
                if hasR1 {
                    if let idx = remaining.firstIndex(where: { $0.suit == first.suit && $0.rank == r1 }) {
                        remaining.remove(at: idx)
                    }
                }
                if hasR2 {
                    if let idx = remaining.firstIndex(where: { $0.suit == first.suit && $0.rank == r2 }) {
                        remaining.remove(at: idx)
                    }
                }
                if canFormMelds(normalTiles: remaining, jokers: jokers - neededJokers, meldsNeeded: meldsNeeded - 1) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - 顺子查找
    
    /// 找出所有可以吃这张牌的顺子组合（支持红中当混填补）
    func findChowOptions(hand: [Tile], tile: Tile) -> [[Tile]] {
        guard !tile.suit.isHonor else { return [] }
        
        var options: [[Tile]] = []
        let suitTiles = hand.filter { $0.suit == tile.suit && !$0.isJoker }
        let jokers = hand.filter(\.isJoker)
        let jokerCount = jokers.count
        
        // 三种顺子位置，检查是否可以用红中填补
        let patterns: [(Int, Int)] = [
            (1, 2),   // tile 是第一张，需要 +1, +2
            (-1, 1),  // tile 是第二张，需要 -1, +1
            (-2, -1)  // tile 是第三张，需要 -2, -1
        ]
        
        for (offset1, offset2) in patterns {
            let needRank1 = tile.rank + offset1
            let needRank2 = tile.rank + offset2
            guard needRank1 >= 1 && needRank1 <= 9 && needRank2 >= 1 && needRank2 <= 9 else { continue }
            
            let t1 = suitTiles.first { $0.rank == needRank1 }
            let t2 = suitTiles.first { $0.rank == needRank2 }
            
            var neededJokers = 0
            if t1 == nil { neededJokers += 1 }
            if t2 == nil { neededJokers += 1 }
            
            if jokerCount >= neededJokers {
                var option: [Tile] = []
                if let t1 = t1 { option.append(t1) }
                else if !jokers.isEmpty { option.append(jokers[0]) }
                if let t2 = t2 { option.append(t2) }
                else if jokers.count > neededJokers - 1 { option.append(jokers[neededJokers > 0 && t1 == nil ? 1 : 0]) }
                
                if option.count == 2 {
                    options.append(option)
                }
            }
        }
        
        return options
    }
    
    // MARK: - AI Actions
    
    /// AI 摸牌后选择动作
    private func aiChooseActionAfterDraw() {
        guard let player = currentPlayer, player.isAI else { return }
        
        // AI 优先胡牌
        if let winAction = availableActions.first(where: { $0.action == .win }) {
            let playerIndex = currentPlayerIndex
            executeClaim(action: winAction, playerIndex: playerIndex)
            return
        }
        
        // 其次暗杠/加杠（简化：30%概率杠）
        let kongActions = availableActions.filter { $0.action == .concealedKong || $0.action == .addKong }
        if let kongAction = kongActions.first, Int.random(in: 0..<10) < 3 {
            if kongAction.action == .concealedKong {
                // 执行暗杠（包含红中凑4张）
                if let tile = kongAction.tiles.first {
                    let sameTiles = player.hand.filter { $0.displayName == tile.displayName && !$0.isJoker }
                    let jokers = player.hand.filter(\.isJoker)
                    var kongTiles = sameTiles
                    while kongTiles.count < 4, !jokers.isEmpty {
                        let idx = kongTiles.count - sameTiles.count
                        if idx < jokers.count {
                            kongTiles.append(jokers[idx])
                        } else { break }
                    }
                    let meld = Meld(type: .concealedKong, tiles: kongTiles, fromPlayerIndex: currentPlayerIndex, claimedTile: tile)
                    player.addMeld(meld)
                    // 暗杠计分：另外三家各给1分
                    applyConcealedKongScore(kongPlayerIndex: currentPlayerIndex)
                    log("\(player.name) 暗杠 \(tile.displayName)")
                    showToast("\(player.name) 暗杠 \(tile.displayName)", type: .info, duration: 2.0)
                    // 暗杠后摸岭上牌
                    if let kingTile = deadWall.popLast() {
                        player.drawTile(kingTile)
                        log("\(player.name) 摸岭上牌")
                    }
                    // 检查摸岭上牌后是否胡牌
                    checkSelfActionsAfterDraw(tile: player.hand.last!)
                }
            } else if let meld = kongAction.meld {
                // 加杠（按暗杠计分：三家各给1分）
                player.addMeld(meld)
                applyConcealedKongScore(kongPlayerIndex: currentPlayerIndex)
                log("\(player.name) 加杠")
                showToast("\(player.name) 加杠", type: .info, duration: 2.0)
                // 加杠后摸岭上牌
                if let kingTile = deadWall.popLast() {
                    player.drawTile(kingTile)
                    log("\(player.name) 摸岭上牌")
                }
                checkSelfActionsAfterDraw(tile: player.hand.last!)
            }
            return
        }
        
        // 否则打牌
        aiDiscard()
    }
    
    // MARK: - 计分辅助方法
    
    /// 暗杠/加杠计分：杠者+3，其他三家各-1
    func applyConcealedKongScore(kongPlayerIndex: Int) {
        players[kongPlayerIndex].score += 3
        for i in 0..<4 {
            if i != kongPlayerIndex {
                players[i].score -= 1
            }
        }
        uiRefreshTrigger += 1
        players = players
        log("\(players[kongPlayerIndex].name) 暗杠得分 +3")
    }
    
    /// 明杠计分：杠者+1，被杠家-1
    func applyMingKongScore(kongPlayerIndex: Int, fromPlayerIndex: Int) {
        guard kongPlayerIndex != fromPlayerIndex else { return }
        players[kongPlayerIndex].score += 1
        players[fromPlayerIndex].score -= 1
        uiRefreshTrigger += 1
        players = players
        log("\(players[kongPlayerIndex].name) 明杠得分 +1（来自 \(players[fromPlayerIndex].name)）")
    }
    
    /// AI 打牌
    private func aiDiscard() {
        guard let player = currentPlayer, player.isAI else { return }
        guard phase == .discarding else { return }
        
        let tileToDiscard = suggestedDiscardTile(player: player)
        discardTile(tileToDiscard)
    }
    
    // MARK: - 智能选牌（基于手牌完成度评估）
    
    /// 建议打哪张牌（AI/玩家共用策略）
    /// 核心思想：评估每张牌的保留价值，优先打出价值最低的牌
    /// 绝不拆散已有的完整面子（顺子/刻子）
    func suggestedDiscardTile(player: Player) -> Tile {
        let hand = player.hand
        
        // 绝不出红中（万能牌价值极高）
        let candidates = hand.filter { !$0.isJoker }
        guard !candidates.isEmpty else {
            return hand.first { $0.isJoker } ?? hand.randomElement()!
        }
        
        var bestTile = candidates[0]
        var lowestValue = Int.max
        
        for tile in candidates {
            let value = evaluateTileRetentionValue(tile: tile, hand: hand)
            if value < lowestValue {
                lowestValue = value
                bestTile = tile
            }
        }
        
        return bestTile
    }
    
    /// 评估单张牌在手牌中的保留价值（越高越不该打）
    private func evaluateTileRetentionValue(tile: Tile, hand: [Tile]) -> Int {
        let normals = hand.filter { !$0.isJoker }
        let sameNameCount = normals.filter { $0.displayName == tile.displayName }.count
        let suitRanks = Set(normals.filter { $0.suit == tile.suit && !$0.suit.isHonor }.map { $0.rank })
        
        var value = 0
        
        // 1. 完整刻子（3张相同）→ 极高价值，绝不拆
        if sameNameCount >= 3 {
            value += 5000
        }
        
        // 2. 完整顺子（3张连续）→ 极高价值，绝不拆
        if !tile.suit.isHonor {
            let r = tile.rank
            // 该牌作为顺子第一张 (r, r+1, r+2)
            if suitRanks.contains(r) && suitRanks.contains(r + 1) && suitRanks.contains(r + 2) {
                value += 5000
            }
            // 该牌作为顺子中间一张 (r-1, r, r+1)
            else if suitRanks.contains(r - 1) && suitRanks.contains(r) && suitRanks.contains(r + 1) {
                value += 5000
            }
            // 该牌作为顺子最后一张 (r-2, r-1, r)
            else if suitRanks.contains(r - 2) && suitRanks.contains(r - 1) && suitRanks.contains(r) {
                value += 5000
            }
        }
        
        // 3. 对子
        if sameNameCount == 2 {
            value += 200
        }
        
        // 4. 搭子（不属于完整面子的搭子）
        if !tile.suit.isHonor {
            let r = tile.rank
            let hasNext = suitRanks.contains(r + 1)
            let hasPrev = suitRanks.contains(r - 1)
            let hasSkip = suitRanks.contains(r + 2)
            let hasPrevSkip = suitRanks.contains(r - 2)
            
            if hasNext || hasPrev {
                value += 150   // 两面搭子
            } else if hasSkip || hasPrevSkip {
                value += 80    // 坎张搭子
            }
        }
        
        // 5. 孤张基础价值（中张 > 边张 > 字牌）
        if tile.suit.isHonor {
            value += 10
        } else if tile.rank == 1 || tile.rank == 9 {
            value += 20
        } else {
            value += 30
        }
        
        return value
    }
    
    /// 评估手牌完成度（分数越高越好）
    /// 参考日麻向听数算法：面子 > 对子 > 搭子 > 孤张
    private func evaluateHandCompleteness(tiles: [Tile]) -> Int {
        let jokers = tiles.filter(\.isJoker)
        let jokerCount = jokers.count
        let normals = tiles.filter { !$0.isJoker }.sorted { $0.sortValue < $1.sortValue }
        
        var score = jokerCount * 80  // 红中万能牌，极高价值
        
        // 1. 刻子检测
        let grouped = Dictionary(grouping: normals) { $0.displayName }
        var usedForMeld = Set<UUID>()
        
        for (_, group) in grouped.sorted(by: { $0.value.count > $1.value.count }) {
            if group.count >= 3 {
                score += 100
                for t in group.prefix(3) { usedForMeld.insert(t.id) }
            }
        }
        
        // 2. 顺子检测（贪心）
        var remaining = normals.filter { !usedForMeld.contains($0.id) }.sorted { $0.sortValue < $1.sortValue }
        var i = 0
        while i < remaining.count {
            let t = remaining[i]
            if t.suit.isHonor { i += 1; continue }
            
            if let a = remaining.firstIndex(where: { $0.suit == t.suit && $0.rank == t.rank + 1 && !usedForMeld.contains($0.id) && $0.id != t.id }),
               let b = remaining.firstIndex(where: { $0.suit == t.suit && $0.rank == t.rank + 2 && !usedForMeld.contains($0.id) && $0.id != t.id && $0.id != remaining[a].id }) {
                score += 100
                usedForMeld.insert(t.id)
                usedForMeld.insert(remaining[a].id)
                usedForMeld.insert(remaining[b].id)
                remaining = normals.filter { !usedForMeld.contains($0.id) }.sorted { $0.sortValue < $1.sortValue }
                i = 0
            } else {
                i += 1
            }
        }
        
        // 3. 对子检测（只需要1个对子作将，额外对子也有碰的价值）
        remaining = normals.filter { !usedForMeld.contains($0.id) }
        var pairFound = false
        for (_, group) in grouped {
            let available = group.filter { !usedForMeld.contains($0.id) }
            if available.count >= 2 {
                if !pairFound {
                    score += 45  // 作将的对子
                    pairFound = true
                } else {
                    score += 25  // 额外对子（可碰）
                }
                for t in available.prefix(2) { usedForMeld.insert(t.id) }
            }
        }
        
        // 4. 搭子检测（差1张完成的面子）
        remaining = normals.filter { !usedForMeld.contains($0.id) }.sorted { $0.sortValue < $1.sortValue }
        var taiziUsed = Set<UUID>()
        
        for tile in remaining {
            if tile.suit.isHonor || taiziUsed.contains(tile.id) { continue }
            
            // 两面搭子（如4-5，进张最多：3/6）
            if let next = remaining.first(where: { $0.suit == tile.suit && $0.rank == tile.rank + 1 && !taiziUsed.contains($0.id) }) {
                score += 35
                taiziUsed.insert(tile.id)
                taiziUsed.insert(next.id)
            }
            // 坎张搭子（如4-6，等5）
            else if let skip = remaining.first(where: { $0.suit == tile.suit && $0.rank == tile.rank + 2 && !taiziUsed.contains($0.id) }) {
                score += 18
                taiziUsed.insert(tile.id)
                taiziUsed.insert(skip.id)
            }
            // 边张搭子（如1-2等3，8-9等7）
            else if let prev = remaining.first(where: { $0.suit == tile.suit && $0.rank == tile.rank - 1 && !taiziUsed.contains($0.id) }),
                    (tile.rank == 2 || tile.rank == 9) {
                score += 12
                taiziUsed.insert(tile.id)
                taiziUsed.insert(prev.id)
            }
        }
        
        // 5. 红中补缺加成
        // 每张红中可以把一个孤张变成搭子，或把搭子变成面子
        let remainingAfterTaizi = remaining.filter { !taiziUsed.contains($0.id) }
        let potentialBoost = min(jokerCount, remainingAfterTaizi.count / 2 + 1)
        score += potentialBoost * 25
        
        // 6. 孤张惩罚（完全孤立的牌）
        for tile in remainingAfterTaizi.filter({ !taiziUsed.contains($0.id) }) {
            let same = grouped[tile.displayName]?.filter { !usedForMeld.contains($0.id) && !taiziUsed.contains($0.id) }.count ?? 0
            var neighborCount = 0
            if !tile.suit.isHonor {
                neighborCount = remainingAfterTaizi.filter {
                    $0.suit == tile.suit && abs($0.rank - tile.rank) <= 2 && $0.id != tile.id && !taiziUsed.contains($0.id)
                }.count
            }
            
            if same == 0 && neighborCount == 0 {
                // 完全孤张，优先打出
                if tile.isHonor {
                    score -= 45  // 字牌孤张最没用
                } else if tile.isTerminal {
                    score -= 30  // 幺九孤张次之
                } else if tile.rank == 2 || tile.rank == 8 {
                    score -= 20  // 边张孤张
                } else {
                    score -= 15  // 中张孤张相对较好
                }
            }
        }
        
        return score
    }
    
    /// AI 选择鸣牌动作
    private func aiChooseClaimAction(playerIndex: Int, actions: [AvailableAction]) {
        // 胡牌优先
        if let winAction = actions.first(where: { $0.action == .win }) {
            executeClaim(action: winAction, playerIndex: playerIndex)
            return
        }
        
        // 杠其次（20%概率）
        let kongActions = actions.filter { $0.action == .kong }
        if let kongAction = kongActions.first, Int.random(in: 0..<10) < 2 {
            executeClaim(action: kongAction, playerIndex: playerIndex)
            return
        }
        
        // 碰（40%概率）
        let pongActions = actions.filter { $0.action == .pong }
        if let pongAction = pongActions.first, Int.random(in: 0..<10) < 4 {
            executeClaim(action: pongAction, playerIndex: playerIndex)
            return
        }
        
        // 吃（30%概率，且尽量吃靠近中张的）
        let chowActions = actions.filter { $0.action == .chow }
        if let chowAction = chowActions.first, Int.random(in: 0..<10) < 3 {
            executeClaim(action: chowAction, playerIndex: playerIndex)
            return
        }
        
        // 不鸣牌，移除该玩家的动作
        availableActions = availableActions.filter { action in
            !actions.contains(where: { $0.id == action.id })
        }
        
        if availableActions.isEmpty {
            isPausedForClaim = false
            nextTurn()
        } else {
            processPriorityClaims()
        }
    }
    
    // MARK: - 存档管理
    
    private var savesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("MahjongSaves", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    /// 保存当前游戏
    func saveCurrentGame() -> Bool {
        stopCountdown()
        let save = GameSave(
            id: UUID(),
            date: Date(),
            saveName: "第\(currentRound)局 \(roundWind.shortName)风场",
            players: players,
            wall: wall,
            deadWall: deadWall,
            currentPlayerIndex: currentPlayerIndex,
            phase: phase,
            currentRound: currentRound,
            roundWind: roundWind,
            doraIndicator: doraIndicator,
            lastDiscardedTile: lastDiscardedTile,
            lastDiscardPlayerIndex: lastDiscardPlayerIndex,
            actionLog: actionLog,
            isPausedForClaim: isPausedForClaim,
            timeRemaining: timeRemaining,
            isTimerActive: isTimerActive,
            isPaused: isPaused
        )
        
        let url = savesDirectory.appendingPathComponent("\(save.id.uuidString).save")
        do {
            let data = try JSONEncoder().encode(save)
            try data.write(to: url)
            showToast("游戏已保存", type: .success, duration: 2.0)
            return true
        } catch {
            showToast("保存失败: \(error.localizedDescription)", type: .error, duration: 3.0)
            return false
        }
    }
    
    /// 加载游戏存档
    func loadGame(save: GameSave) -> Bool {
        stopCountdown()
        claimWaitTimer?.invalidate()
        claimWaitTimer = nil
        
        players = save.players
        wall = save.wall
        deadWall = save.deadWall
        currentPlayerIndex = save.currentPlayerIndex
        phase = save.phase
        currentRound = save.currentRound
        roundWind = save.roundWind
        doraIndicator = save.doraIndicator
        lastDiscardedTile = save.lastDiscardedTile
        lastDiscardPlayerIndex = save.lastDiscardPlayerIndex
        actionLog = save.actionLog
        isPausedForClaim = save.isPausedForClaim
        timeRemaining = save.timeRemaining
        isTimerActive = save.isTimerActive
        isPaused = save.isPaused
        result = nil
        toastMessage = nil
        availableActions = []
        uiRefreshTrigger += 1
        
        showToast("存档已加载", type: .success, duration: 2.0)
        return true
    }
    
    /// 列出所有存档
    func listSaves() -> [GameSave] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: savesDirectory, includingPropertiesForKeys: nil)
            let saves: [GameSave] = files
                .filter { $0.pathExtension == "save" }
                .compactMap { url -> GameSave? in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return try? JSONDecoder().decode(GameSave.self, from: data)
                }
                .sorted { $0.date > $1.date }
            return saves
        } catch {
            return []
        }
    }
    
    /// 删除存档
    func deleteSave(id: UUID) {
        let url = savesDirectory.appendingPathComponent("\(id.uuidString).save")
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - 听牌检测
    
    /// 检测玩家是否听牌（手牌差1张即可胡牌）
    func isReadyHand(player: Player) -> Bool {
        let hand = player.hand
        // 听牌定义：打出任意一张牌后，剩余牌可以胡牌
        // 简化检测：尝试从牌墙中摸入每一种可能的牌，看是否能胡
        let allPossibleTiles = StandardTiles.createDeck()
        let uniqueTiles = Array(Set(allPossibleTiles.map { $0.displayName }))
        
        for tileName in uniqueTiles {
            // 构造一个虚拟牌
            if let template = allPossibleTiles.first(where: { $0.displayName == tileName }) {
                let virtualTile = Tile(suit: template.suit, rank: template.rank)
                let testHand = hand + [virtualTile]
                if canWin(tiles: testHand) {
                    return true
                }
            }
        }
        return false
    }
}
