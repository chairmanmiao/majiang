import SwiftUI

/// 主游戏桌视图 - 几何线条艺术风格
struct GameTableView: View {
    @ObservedObject var engine: GameEngine
    @State private var selectedTile: Tile?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 牌桌背景层
                tableBackground
                
                // 几何线条装饰层
                geometricDecorations
                
                VStack(spacing: 0) {
                    // 顶部区域
                    topBar
                    
                    // 中间区域
                    HStack(spacing: 0) {
                        // 西家
                        sidePlayerPanel(playerIndex: 2, position: .west)
                        
                        // 中央牌桌
                        centralTableArea
                            .padding(.horizontal, 8)
                        
                        // 东家
                        sidePlayerPanel(playerIndex: 1, position: .east)
                    }
                    
                    Spacer(minLength: 6)
                    
                    // 底部区域：人类玩家
                    bottomPlayerArea
                }
                
                // 暂停遮罩
                if engine.isPaused {
                    pauseOverlay
                }
                
                // Toast 提示层
                if let toast = engine.toastMessage {
                    VStack {
                        ToastView(message: toast) {
                            engine.toastMessage = nil
                        }
                        .padding(.top, 40)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 720)
    }
    
    // MARK: - 牌桌背景
    private var tableBackground: some View {
        ZStack {
            // 深墨绿底色
            Color(red: 0.1, green: 0.35, blue: 0.18)
                .ignoresSafeArea()
            
            //  subtle radial gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.13, green: 0.4, blue: 0.22),
                    Color(red: 0.08, green: 0.3, blue: 0.15)
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 600
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - 几何线条装饰
    private var geometricDecorations: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            
            // 中央八角形装饰线
            let octSize: CGFloat = min(w, h) * 0.22
            let octPoints = (0..<8).map { i -> CGPoint in
                let angle = Double(i) * .pi / 4 - .pi / 8
                return CGPoint(
                    x: cx + octSize * cos(angle),
                    y: cy + octSize * sin(angle)
                )
            }
            var octagon = Path()
            octagon.move(to: octPoints[0])
            for i in 1..<octPoints.count {
                octagon.addLine(to: octPoints[i])
            }
            octagon.closeSubpath()
            context.stroke(octagon, with: .color(Color.white.opacity(0.06)), lineWidth: 1)
            
            // 内层方形装饰线
            let rectSize = octSize * 0.6
            var innerRect = Path()
            innerRect.addRect(CGRect(x: cx - rectSize, y: cy - rectSize, width: rectSize*2, height: rectSize*2))
            context.stroke(innerRect, with: .color(Color.white.opacity(0.04)), lineWidth: 0.8)
            
            // 对角线装饰
            let diagInset: CGFloat = 60
            var diag1 = Path()
            diag1.move(to: CGPoint(x: diagInset, y: diagInset))
            diag1.addLine(to: CGPoint(x: w - diagInset, y: h - diagInset))
            context.stroke(diag1, with: .color(Color.white.opacity(0.03)), lineWidth: 0.5)
            
            var diag2 = Path()
            diag2.move(to: CGPoint(x: w - diagInset, y: diagInset))
            diag2.addLine(to: CGPoint(x: diagInset, y: h - diagInset))
            context.stroke(diag2, with: .color(Color.white.opacity(0.03)), lineWidth: 0.5)
            
            // 顶部/底部横线装饰
            for y in [h * 0.15, h * 0.85] {
                var line = Path()
                line.move(to: CGPoint(x: w * 0.25, y: y))
                line.addLine(to: CGPoint(x: w * 0.75, y: y))
                context.stroke(line, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)
            }
            
            // 四角小三角装饰
            let triSize: CGFloat = 20
            let corners = [
                (CGPoint(x: 0, y: 0), CGPoint(x: triSize, y: 0), CGPoint(x: 0, y: triSize)),
                (CGPoint(x: w, y: 0), CGPoint(x: w - triSize, y: 0), CGPoint(x: w, y: triSize)),
                (CGPoint(x: 0, y: h), CGPoint(x: triSize, y: h), CGPoint(x: 0, y: h - triSize)),
                (CGPoint(x: w, y: h), CGPoint(x: w - triSize, y: h), CGPoint(x: w, y: h - triSize))
            ]
            for (a, b, c) in corners {
                var tri = Path()
                tri.move(to: a)
                tri.addLine(to: b)
                tri.addLine(to: c)
                tri.closeSubpath()
                context.stroke(tri, with: .color(Color.white.opacity(0.06)), lineWidth: 0.8)
            }
        }
    }
    
    // MARK: - 顶部栏
    private var topBar: some View {
        HStack {
            if let northPlayer = engine.players[safe: 3] {
                CompactPlayerView(player: northPlayer, position: .north)
                    .frame(width: 170)
            } else {
                Color.clear.frame(width: 170)
            }
            
            Spacer()
            
            // 状态信息
            VStack(spacing: 5) {
                Text("第 \(engine.currentRound) 局")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Text("\(engine.roundWind.shortName)风场")
                        .font(.system(size: 11, weight: .medium))
                    Text("·")
                        .foregroundColor(.white.opacity(0.5))
                    Text("牌墙 \(engine.wallCount)")
                        .font(.system(size: 11))
                }
                .foregroundColor(.white.opacity(0.75))
                
                if let dora = engine.doraIndicator {
                    HStack(spacing: 4) {
                        Text("宝牌")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        TileView(tile: dora, scale: 0.48)
                    }
                }
                
                if let current = engine.currentPlayer {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(current.isAI ? Color.orange : Color.green)
                            .frame(width: 6, height: 6)
                        Text(current.isAI ? "\(current.name) 思考中..." : "你的回合")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(current.isAI ? Color.orange.opacity(0.9) : Color.green.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                }
            }
            
            Spacer()
            
            // 暂停按钮
            Button(action: {
                engine.togglePause()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(engine.isPaused ? "继续" : "暂停")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.35))
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    }
                )
            }
            .buttonStyle(.plain)
            .frame(width: 170, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - 暂停遮罩
    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("游戏暂停")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                
                Text("点击任意处继续")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                
                Button(action: {
                    engine.togglePause()
                }) {
                    Text("继续游戏")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.2, green: 0.55, blue: 0.3))
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .onTapGesture {
            engine.togglePause()
        }
    }
    
    // MARK: - 侧边玩家面板
    private func sidePlayerPanel(playerIndex: Int, position: PlayerPosition) -> some View {
        Group {
            if let player = engine.players[safe: playerIndex] {
                CompactPlayerView(player: player, position: position)
                    .frame(width: 170)
                    .padding(.horizontal, 6)
            } else {
                Color.clear.frame(width: 170).padding(.horizontal, 6)
            }
        }
    }
    
    // MARK: - 中央牌桌区域
    private var centralTableArea: some View {
        ZStack {
            // 牌桌台面
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.1, green: 0.32, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 5)
            
            // 内部几何线条边框
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .padding(8)
            
            VStack(spacing: 6) {
                // 北家牌河
                if let north = engine.players[safe: 3] {
                    DiscardPileView(tiles: north.discardPile, columns: 10, scale: 0.55, highlightLast: true)
                        .rotationEffect(.degrees(180))
                }
                
                HStack(spacing: 16) {
                    // 西家牌河
                    if let west = engine.players[safe: 2] {
                        DiscardPileView(tiles: west.discardPile, columns: 8, scale: 0.55, highlightLast: true)
                            .rotationEffect(.degrees(90))
                    }
                    
                    // 中央信息区
                    centralInfoArea
                        .frame(width: 150, height: 130)
                    
                    // 东家牌河
                    if let east = engine.players[safe: 1] {
                        DiscardPileView(tiles: east.discardPile, columns: 8, scale: 0.55, highlightLast: true)
                            .rotationEffect(.degrees(-90))
                    }
                }
                
                // 南家（人类）牌河
                if let south = engine.players.first {
                    DiscardPileView(tiles: south.discardPile, columns: 10, scale: 0.6, highlightLast: true)
                }
            }
            .padding(12)
        }
    }
    
    // MARK: - 中央信息区
    private var centralInfoArea: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
            
            if engine.phase == .roundEnd, let result = engine.result {
                RoundResultView(result: result, players: engine.players) {
                    engine.nextRound()
                }
                .padding(8)
            } else if engine.wallCount == 0 && engine.phase != .roundEnd {
                Text("流局")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            } else {
                VStack(spacing: 6) {
                    if let lastTile = engine.lastDiscardedTile {
                        Text("\(engine.players[safe: engine.lastDiscardPlayerIndex]?.name ?? "") 打出")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        TileView(tile: lastTile, scale: 1.15, isLastDiscarded: true)
                            .shadow(color: .yellow.opacity(0.5), radius: 12)
                    } else {
                        // 默认装饰图案
                        decorativeDice
                    }
                }
            }
        }
    }
    
    // MARK: - 装饰骰子图案
    private var decorativeDice: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2
            
            // 两个骰子的轮廓
            let diceSize: CGFloat = 22
            let positions = [(cx - 18, cy), (cx + 18, cy)]
            for (dx, dy) in positions {
                var dice = Path()
                dice.addRoundedRect(in: CGRect(x: dx - diceSize/2, y: dy - diceSize/2, width: diceSize, height: diceSize), cornerSize: CGSize(width: 4, height: 4))
                context.stroke(dice, with: .color(Color.white.opacity(0.12)), lineWidth: 1.2)
                
                // 骰子点
                var dot = Path()
                dot.addEllipse(in: CGRect(x: dx - 3, y: dy - 3, width: 6, height: 6))
                context.fill(dot, with: .color(Color.white.opacity(0.1)))
            }
        }
        .frame(width: 80, height: 60)
    }
    
    // MARK: - 底部人类玩家区域
    private var bottomPlayerArea: some View {
        VStack(spacing: 6) {
            // 吃碰杠选择面板（当有动作可选时）
            if engine.isPausedForClaim {
                let humanActions = engine.availableActions.filter { $0.targetPlayerIndex == 0 }
                if !humanActions.isEmpty {
                    ClaimSelectionPanel(
                        actions: humanActions,
                        onAction: { action in
                            engine.executeClaim(action: action, playerIndex: 0)
                        },
                        onPass: {
                            engine.passClaim()
                        }
                    )
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // 自摸/暗杠/加杠选择面板（人类玩家回合）
            if engine.isHumanTurn && engine.phase == .discarding {
                let selfActions = engine.availableActions.filter { $0.targetPlayerIndex == 0 }
                if !selfActions.isEmpty {
                    SelfActionPanel(
                        actions: selfActions,
                        onAction: { action in
                            handleSelfAction(action)
                        },
                        onDiscard: {
                            engine.skipSelfActionsAndDiscard()
                        }
                    )
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // 听牌按钮
            if let player = engine.players.first,
               engine.isHumanTurn && engine.phase == .discarding,
               !player.isReadyHand,
               engine.isReadyHand(player: player) {
                Button(action: {
                    player.isReadyHand = true
                    engine.showToast("已宣告听牌！", type: .success, duration: 2.0)
                    engine.log("\(player.name) 宣告听牌")
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "ear")
                            .font(.system(size: 12, weight: .bold))
                        Text("听牌")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.9, green: 0.3, blue: 0.3))
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        }
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 倒计时条
            if engine.isTimerActive {
                countdownBar
                    .padding(.horizontal)
                    .transition(.opacity)
            }
            
            // 副露区
            if let player = engine.players.first, !player.melds.isEmpty {
                HStack(spacing: 8) {
                    ForEach(player.melds) { meld in
                        MeldView(meld: meld, scale: 0.78)
                    }
                }
                .padding(.horizontal)
            }
            
            // 手牌区
            if let player = engine.players.first {
                let suggestedTile = engine.isTimerActive ? engine.suggestedDiscardTile(player: player) : nil
                HStack(spacing: 5) {
                    ForEach(player.hand) { tile in
                        TileView(
                            tile: tile,
                            isSelected: selectedTile?.id == tile.id,
                            isDisabled: !canDiscard(tile: tile),
                            scale: 1.05,
                            isSuggested: suggestedTile?.id == tile.id && selectedTile?.id != tile.id
                        )
                        .onTapGesture {
                            if canDiscard(tile: tile) {
                                if selectedTile?.id == tile.id {
                                    engine.discardTile(tile)
                                    selectedTile = nil
                                } else {
                                    selectedTile = tile
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.25))
                        
                        // 手牌区域线条边框
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        
                        // 底部装饰线
                        Canvas { context, size in
                            let w = size.width
                            let h = size.height
                            var line = Path()
                            line.move(to: CGPoint(x: 20, y: h - 2))
                            line.addLine(to: CGPoint(x: w - 20, y: h - 2))
                            context.stroke(line, with: .color(Color.white.opacity(0.08)), lineWidth: 1)
                        }
                    }
                )
                .overlay(
                    canDiscardAny() ?
                    Text("点击选牌，再次点击打出")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .offset(y: -42)
                    : nil
                )
            }
            
            // 动作按钮区
            ActionPanelView(engine: engine)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }
    
    // MARK: - 倒计时进度条
    private var countdownBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.system(size: 12))
                .foregroundColor(countdownColor)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.4))
                    
                    // 进度
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [countdownColor.opacity(0.8), countdownColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * engine.countdownProgress))
                        .animation(.linear(duration: 0.1), value: engine.countdownProgress)
                    
                    // 内部线条纹理
                    Canvas { context, size in
                        let w = size.width
                        let h = size.height
                        for x in stride(from: 4.0, to: Double(w), by: 8.0) {
                            var line = Path()
                            line.move(to: CGPoint(x: x, y: 1))
                            line.addLine(to: CGPoint(x: x, y: h - 1))
                            context.stroke(line, with: .color(Color.white.opacity(0.08)), lineWidth: 0.5)
                        }
                    }
                }
            }
            .frame(height: 12)
            
            Text("\(Int(ceil(engine.timeRemaining)))s")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundColor(countdownColor)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.4))
                RoundedRectangle(cornerRadius: 8)
                    .stroke(countdownColor.opacity(0.3), lineWidth: 1)
            }
        )
    }
    
    private var countdownColor: Color {
        if engine.countdownProgress > 0.5 {
            return Color(red: 0.3, green: 0.85, blue: 0.4)
        } else if engine.countdownProgress > 0.25 {
            return Color(red: 0.95, green: 0.7, blue: 0.1)
        } else {
            return Color(red: 0.9, green: 0.2, blue: 0.2)
        }
    }
    
    private func handleSelfAction(_ action: AvailableAction) {
        switch action.action {
        case .win:
            engine.executeClaim(action: action, playerIndex: 0)
        case .concealedKong:
            if let tile = action.tiles.first {
                let player = engine.players[0]
                let sameTiles = player.hand.filter { $0.displayName == tile.displayName && !$0.isJoker }
                let jokers = player.hand.filter(\.isJoker)
                var kongTiles = sameTiles
                while kongTiles.count < 4, !jokers.isEmpty {
                    let idx = kongTiles.count - sameTiles.count
                    if idx < jokers.count {
                        kongTiles.append(jokers[idx])
                    } else { break }
                }
                let meld = Meld(type: .concealedKong, tiles: kongTiles, fromPlayerIndex: 0, claimedTile: tile)
                player.addMeld(meld)
                engine.applyConcealedKongScore(kongPlayerIndex: 0)
                engine.log("\(player.name) 暗杠 \(tile.displayName)")
                engine.showToast("暗杠 \(tile.displayName)！", type: .info)
                if let kingTile = engine.deadWall.popLast() {
                    player.drawTile(kingTile)
                    engine.log("\(player.name) 摸岭上牌")
                }
                engine.availableActions = []
                engine.checkSelfActionsAfterDraw(tile: player.hand.last!)
            }
        case .addKong:
            if let meld = action.meld, let newTile = action.tiles.first {
                engine.players[0].upgradePongToKong(meld: meld, newTile: newTile)
                engine.applyConcealedKongScore(kongPlayerIndex: 0)
                engine.log("\(engine.players[0].name) 加杠 \(meld.tiles.first?.displayName ?? "")")
                engine.showToast("加杠 \(meld.tiles.first?.displayName ?? "")！", type: .info)
                if let kingTile = engine.deadWall.popLast() {
                    engine.players[0].drawTile(kingTile)
                    engine.log("\(engine.players[0].name) 摸岭上牌")
                }
                engine.availableActions = []
                engine.checkSelfActionsAfterDraw(tile: engine.players[0].hand.last!)
            }
        default:
            break
        }
    }
    
    private func canDiscard(tile: Tile) -> Bool {
        guard let player = engine.currentPlayer else { return false }
        guard player.id == engine.players[0].id else { return false }
        guard engine.phase == .discarding else { return false }
        return true
    }
    
    private func canDiscardAny() -> Bool {
        guard let player = engine.currentPlayer else { return false }
        guard player.id == engine.players[0].id else { return false }
        guard engine.phase == .discarding else { return false }
        return true
    }
}

/// 自摸/暗杠/加杠选择面板
struct SelfActionPanel: View {
    let actions: [AvailableAction]
    let onAction: (AvailableAction) -> Void
    let onDiscard: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "hand.point.up.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text("可选动作")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            
            ForEach(actions) { action in
                ClaimActionButton(action: action) {
                    onAction(action)
                }
            }
            
            Button(action: onDiscard) {
                Text("直接打牌")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
}

/// 对局结果弹窗
struct RoundResultView: View {
    let result: RoundResult
    let players: [Player]
    let onNextRound: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // 顶部装饰线
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.yellow.opacity(0.6))
                .frame(width: 50, height: 3)
            
            Text(result.message)
                .font(.system(size: 17, weight: .black))
                .foregroundColor(.yellow)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            if let winner = result.winnerIndex {
                VStack(spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(players[winner].name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    if !result.fanNames.isEmpty {
                        Text(result.fanNames.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text("+\(result.handScore) 点")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(Color(red: 0.3, green: 0.9, blue: 0.4))
                }
            } else {
                Text("流局")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Button(action: onNextRound) {
                HStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11))
                    Text("下一局")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 8)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.2, green: 0.5, blue: 0.9))
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    }
                )
                .shadow(color: Color(red: 0.2, green: 0.5, blue: 0.9).opacity(0.4), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(minWidth: 180, minHeight: 140)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// 安全数组访问
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
