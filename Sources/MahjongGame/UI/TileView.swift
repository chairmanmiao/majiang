import SwiftUI

/// 单张麻将牌的视图 - 二维线段艺术风格
struct TileView: View {
    let tile: Tile
    var isSelected: Bool = false
    var isDisabled: Bool = false
    var scale: CGFloat = 1.0
    var showBack: Bool = false
    var isLastDiscarded: Bool = false
    var isSuggested: Bool = false
    
    private var baseWidth: CGFloat { 44 * scale }
    private var baseHeight: CGFloat { 62 * scale }
    
    var body: some View {
        ZStack {
            // 牌体阴影
            RoundedRectangle(cornerRadius: 5 * scale)
                .fill(Color.black.opacity(0.2))
                .frame(width: baseWidth + 2, height: baseHeight + 2)
                .offset(x: 1, y: 1)
            
            if showBack {
                tileBackView
            } else {
                tileFaceView
            }
        }
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 5 * scale)
                    .stroke(isSelected ? Color(red: 0.2, green: 0.6, blue: 1.0) : (isLastDiscarded ? Color.yellow : Color.clear),
                            lineWidth: isSelected ? 3 * scale : 2 * scale)
                
                if isSuggested {
                    // 外围柔和发光（无位移、无缩放）
                    RoundedRectangle(cornerRadius: 5 * scale)
                        .stroke(Color(red: 1.0, green: 0.8, blue: 0.2), lineWidth: 2.0 * scale)
                        .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.0).opacity(0.6), radius: 4 * scale)
                    
                    // 牌面上的箭头指示
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9 * scale, weight: .heavy))
                        .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.0))
                        .shadow(color: Color.black.opacity(0.6), radius: 1, x: 0, y: 0.5)
                        .offset(y: baseHeight * 0.22)
                }
            }
        )
        .opacity(isDisabled ? 0.45 : 1.0)
        .offset(y: isSelected ? -10 * scale : 0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
        .scaleEffect(isLastDiscarded ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isLastDiscarded)
    }
    
    // MARK: - 牌背
    private var tileBackView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5 * scale)
                .fill(Color(red: 0.18, green: 0.38, blue: 0.58))
            
            // 牌背网格线条纹理
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let inset: CGFloat = 4 * scale
                
                // 外边框线
                var border = Path()
                border.addRoundedRect(in: CGRect(x: inset, y: inset, width: w - inset*2, height: h - inset*2),
                                      cornerSize: CGSize(width: 3*scale, height: 3*scale))
                context.stroke(border, with: .color(Color(red: 0.4, green: 0.6, blue: 0.8)), lineWidth: 1.5)
                
                // 内部斜线网格
                let step: CGFloat = 6 * scale
                for i in stride(from: -h, to: w + h, by: step) {
                    var line = Path()
                    line.move(to: CGPoint(x: i, y: 0))
                    line.addLine(to: CGPoint(x: i + h, y: h))
                    context.stroke(line, with: .color(Color(red: 0.3, green: 0.5, blue: 0.7).opacity(0.4)), lineWidth: 0.5)
                }
                
                // 中心圆形装饰
                var centerCircle = Path()
                centerCircle.addEllipse(in: CGRect(x: w/2 - 6*scale, y: h/2 - 6*scale, width: 12*scale, height: 12*scale))
                context.stroke(centerCircle, with: .color(Color(red: 0.5, green: 0.7, blue: 0.9).opacity(0.6)), lineWidth: 1.5)
                
                var innerCircle = Path()
                innerCircle.addEllipse(in: CGRect(x: w/2 - 3*scale, y: h/2 - 3*scale, width: 6*scale, height: 6*scale))
                context.stroke(innerCircle, with: .color(Color(red: 0.5, green: 0.7, blue: 0.9).opacity(0.4)), lineWidth: 0.8)
            }
            .frame(width: baseWidth, height: baseHeight)
        }
        .frame(width: baseWidth, height: baseHeight)
        .clipShape(RoundedRectangle(cornerRadius: 5 * scale))
    }
    
    // MARK: - 牌面
    private var tileFaceView: some View {
        ZStack {
            // 底色
            RoundedRectangle(cornerRadius: 5 * scale)
                .fill(Color(red: 0.97, green: 0.95, blue: 0.92))
            
            // 内部线条纹理
            Canvas { context, size in
                let w = size.width
                let h = size.height
                
                // 极细的背景网格
                let gridStep: CGFloat = 8 * scale
                for x in stride(from: gridStep, to: w, by: gridStep) {
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 2))
                    line.addLine(to: CGPoint(x: x, y: h - 2))
                    context.stroke(line, with: .color(Color.black.opacity(0.03)), lineWidth: 0.3)
                }
                for y in stride(from: gridStep, to: h, by: gridStep) {
                    var line = Path()
                    line.move(to: CGPoint(x: 2, y: y))
                    line.addLine(to: CGPoint(x: w - 2, y: y))
                    context.stroke(line, with: .color(Color.black.opacity(0.03)), lineWidth: 0.3)
                }
            }
            .frame(width: baseWidth, height: baseHeight)
            
            // 双层边框
            RoundedRectangle(cornerRadius: 5 * scale)
                .stroke(Color(red: 0.7, green: 0.65, blue: 0.6), lineWidth: 1.2)
                .frame(width: baseWidth - 1, height: baseHeight - 1)
            
            RoundedRectangle(cornerRadius: 4 * scale)
                .stroke(Color(red: 0.85, green: 0.8, blue: 0.75), lineWidth: 0.6)
                .frame(width: baseWidth - 4, height: baseHeight - 4)
            
            // 牌面内容
            VStack(spacing: 0) {
                // 上方文字
                Text(tile.displayName)
                    .font(.system(size: 16 * scale, weight: .black, design: .rounded))
                    .foregroundColor(tileColor)
                    .shadow(color: tileColor.opacity(0.3), radius: 0.5 * scale, x: 0, y: 0.5 * scale)
                
                // 下方几何图案
                tilePattern
                    .frame(width: 20 * scale, height: 18 * scale)
            }
            .frame(width: baseWidth - 6, height: baseHeight - 6)
        }
        .frame(width: baseWidth, height: baseHeight)
        .clipShape(RoundedRectangle(cornerRadius: 5 * scale))
    }
    
    // MARK: - 牌面几何图案（二维线段绘制）
    @ViewBuilder
    private var tilePattern: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let c = CGPoint(x: w/2, y: h/2)
            
            switch tile.suit {
            case .wan:
                drawWanPattern(context: context, center: c, size: min(w, h), color: tileColor)
            case .tong:
                drawTongPattern(context: context, center: c, size: min(w, h), color: tileColor)
            case .tiao:
                drawTiaoPattern(context: context, center: c, size: min(w, h), color: tileColor)
            case .wind:
                drawWindPattern(context: context, center: c, size: min(w, h), color: tileColor)
            case .dragon:
                drawDragonPattern(context: context, center: c, size: min(w, h), color: tileColor)
            }
        }
    }
    
    private func drawWanPattern(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        let s = size * 0.35
        // 绘制"万"字符号的简化版 - 屋顶线条
        var roof = Path()
        roof.move(to: CGPoint(x: center.x - s, y: center.y - s*0.3))
        roof.addLine(to: CGPoint(x: center.x + s, y: center.y - s*0.3))
        context.stroke(roof, with: .color(color), lineWidth: 1.2)
        
        var left = Path()
        left.move(to: CGPoint(x: center.x - s*0.5, y: center.y - s*0.3))
        left.addLine(to: CGPoint(x: center.x - s*0.5, y: center.y + s*0.6))
        context.stroke(left, with: .color(color), lineWidth: 1.0)
        
        var right = Path()
        right.move(to: CGPoint(x: center.x + s*0.5, y: center.y - s*0.3))
        right.addLine(to: CGPoint(x: center.x + s*0.5, y: center.y + s*0.6))
        context.stroke(right, with: .color(color), lineWidth: 1.0)
        
        var bottom = Path()
        bottom.move(to: CGPoint(x: center.x - s*0.5, y: center.y + s*0.3))
        bottom.addLine(to: CGPoint(x: center.x + s*0.5, y: center.y + s*0.3))
        context.stroke(bottom, with: .color(color), lineWidth: 1.0)
    }
    
    private func drawTongPattern(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        let s = size * 0.38
        // 同心圆线条
        for r in stride(from: s, to: 0, by: -s/3) {
            var circle = Path()
            circle.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r*2, height: r*2))
            context.stroke(circle, with: .color(color.opacity(r == s ? 1.0 : 0.6)), lineWidth: r == s ? 1.5 : 0.8)
        }
    }
    
    private func drawTiaoPattern(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        let s = size * 0.4
        // 竹节线条
        let segments: [(CGFloat, CGFloat)] = [(-0.6, -0.2), (-0.2, 0.2), (0.2, 0.6)]
        for (start, end) in segments {
            var line = Path()
            line.move(to: CGPoint(x: center.x - s*0.3, y: center.y + s*start))
            line.addLine(to: CGPoint(x: center.x + s*0.3, y: center.y + s*start))
            context.stroke(line, with: .color(color), lineWidth: 1.0)
            
            var line2 = Path()
            line2.move(to: CGPoint(x: center.x - s*0.3, y: center.y + s*end))
            line2.addLine(to: CGPoint(x: center.x + s*0.3, y: center.y + s*end))
            context.stroke(line2, with: .color(color), lineWidth: 1.0)
            
            var vline = Path()
            vline.move(to: CGPoint(x: center.x, y: center.y + s*start))
            vline.addLine(to: CGPoint(x: center.x, y: center.y + s*end))
            context.stroke(vline, with: .color(color), lineWidth: 0.8)
        }
    }
    
    private func drawWindPattern(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        let s = size * 0.35
        // 风向箭头 - 几何线条
        let directions: [(CGFloat, CGFloat)] = [
            (0, -1),   // 东/其他
            (0.8, -0.6),
            (-0.8, -0.6),
            (0, 1)
        ]
        let dir = directions[min(tile.rank - 1, 3)]
        
        var arrow = Path()
        let start = CGPoint(x: center.x - dir.0 * s, y: center.y - dir.1 * s)
        let end = CGPoint(x: center.x + dir.0 * s, y: center.y + dir.1 * s)
        arrow.move(to: start)
        arrow.addLine(to: end)
        context.stroke(arrow, with: .color(color), lineWidth: 1.8)
        
        // 箭头两翼
        var wing1 = Path()
        wing1.move(to: end)
        wing1.addLine(to: CGPoint(x: end.x - dir.0*s*0.4 - dir.1*s*0.3, y: end.y - dir.1*s*0.4 + dir.0*s*0.3))
        context.stroke(wing1, with: .color(color), lineWidth: 1.2)
        
        var wing2 = Path()
        wing2.move(to: end)
        wing2.addLine(to: CGPoint(x: end.x - dir.0*s*0.4 + dir.1*s*0.3, y: end.y - dir.1*s*0.4 - dir.0*s*0.3))
        context.stroke(wing2, with: .color(color), lineWidth: 1.2)
    }
    
    private func drawDragonPattern(context: GraphicsContext, center: CGPoint, size: CGFloat, color: Color) {
        let s = size * 0.35
        switch tile.rank {
        case 1: // 中 - 十字线条
            var hLine = Path()
            hLine.move(to: CGPoint(x: center.x - s, y: center.y))
            hLine.addLine(to: CGPoint(x: center.x + s, y: center.y))
            context.stroke(hLine, with: .color(color), lineWidth: 1.8)
            
            var vLine = Path()
            vLine.move(to: CGPoint(x: center.x, y: center.y - s))
            vLine.addLine(to: CGPoint(x: center.x, y: center.y + s))
            context.stroke(vLine, with: .color(color), lineWidth: 1.8)
            
            var rect = Path()
            rect.addRect(CGRect(x: center.x - s*0.5, y: center.y - s*0.5, width: s, height: s))
            context.stroke(rect, with: .color(color), lineWidth: 0.8)
            
        case 2: // 发 - 菱形+线条
            var diamond = Path()
            diamond.move(to: CGPoint(x: center.x, y: center.y - s))
            diamond.addLine(to: CGPoint(x: center.x + s*0.7, y: center.y))
            diamond.addLine(to: CGPoint(x: center.x, y: center.y + s))
            diamond.addLine(to: CGPoint(x: center.x - s*0.7, y: center.y))
            diamond.closeSubpath()
            context.stroke(diamond, with: .color(color), lineWidth: 1.5)
            
            var line = Path()
            line.move(to: CGPoint(x: center.x - s*0.3, y: center.y))
            line.addLine(to: CGPoint(x: center.x + s*0.3, y: center.y))
            context.stroke(line, with: .color(color), lineWidth: 1.0)
            
        case 3: // 白 - 方形边框线条
            var rect = Path()
            rect.addRect(CGRect(x: center.x - s*0.6, y: center.y - s*0.6, width: s*1.2, height: s*1.2))
            context.stroke(rect, with: .color(color.opacity(0.6)), lineWidth: 1.5)
            
            var inner = Path()
            inner.addRect(CGRect(x: center.x - s*0.3, y: center.y - s*0.3, width: s*0.6, height: s*0.6))
            context.stroke(inner, with: .color(color.opacity(0.3)), lineWidth: 0.8)
            
        default:
            break
        }
    }
    
    private var tileColor: Color {
        switch tile.suit {
        case .wan:
            return Color(red: 0.75, green: 0.1, blue: 0.1)
        case .tong:
            return Color(red: 0.08, green: 0.4, blue: 0.75)
        case .tiao:
            return Color(red: 0.1, green: 0.5, blue: 0.15)
        case .wind:
            return Color(red: 0.45, green: 0.2, blue: 0.65)
        case .dragon:
            if tile.rank == 1 { return Color(red: 0.75, green: 0.1, blue: 0.1) }
            if tile.rank == 2 { return Color(red: 0.1, green: 0.5, blue: 0.15) }
            return Color(red: 0.5, green: 0.5, blue: 0.5)
        }
    }
}

/// 副露牌的横向排列视图
struct MeldView: View {
    let meld: Meld
    var scale: CGFloat = 0.8
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(meld.tiles) { tile in
                TileView(
                    tile: tile,
                    scale: scale,
                    showBack: false
                )
                .overlay(
                    tile.id == meld.claimedTile.id ?
                    RoundedRectangle(cornerRadius: 5 * scale)
                        .stroke(Color.orange, lineWidth: 2 * scale)
                    : nil
                )
                .rotationEffect(
                    tile.id == meld.claimedTile.id ?
                    Angle(degrees: meldRotation) : .zero
                )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }
    
    private var meldRotation: Double {
        let from = meld.fromPlayerIndex
        if from == 0 || from == 3 { return 0 }
        return from == 1 ? -90 : 90
    }
}

/// 牌河视图（某玩家打出的牌）
struct DiscardPileView: View {
    let tiles: [Tile]
    var columns: Int = 12
    var scale: CGFloat = 0.65
    var highlightLast: Bool = false
    
    var body: some View {
        let rows = tiles.chunked(into: columns)
        
        VStack(spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 2) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIdx, tile in
                        let isLast = highlightLast && rowIdx == rows.count - 1 && colIdx == row.count - 1
                        TileView(tile: tile, scale: scale, isLastDiscarded: isLast)
                    }
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

/// 小尺寸玩家信息视图（用于显示其他玩家）
struct CompactPlayerView: View {
    let player: Player
    var position: PlayerPosition
    
    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                ZStack {
                    Circle()
                        .stroke(player.isDealer ? Color.yellow : Color.blue.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(player.isDealer ? Color.yellow.opacity(0.3) : Color.blue.opacity(0.15))
                        .frame(width: 10, height: 10)
                }
                Text(player.name)
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                if player.isReadyHand {
                    Text("听")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.orange)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.yellow.opacity(0.5), lineWidth: 0.5)
                                )
                        )
                }
            }
            
            HStack(spacing: 6) {
                Label("\(player.handCount)", systemImage: "rectangle.stack")
                    .font(.caption2)
                Label("\(player.score)", systemImage: "dollarsign.circle")
                    .font(.caption2)
                    .foregroundColor(player.score >= 0 ? Color(red: 0.2, green: 0.7, blue: 0.3) : Color(red: 0.8, green: 0.2, blue: 0.2))
            }
            
            // 副露
            HStack(spacing: 2) {
                ForEach(player.melds) { meld in
                    MeldView(meld: meld, scale: 0.5)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
