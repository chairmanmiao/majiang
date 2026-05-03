import SwiftUI

/// 动作按钮面板
struct ActionPanelView: View {
    @ObservedObject var engine: GameEngine
    
    var body: some View {
        HStack(spacing: 12) {
            // 游戏状态指示器
            statusIndicator
            
            Spacer()
            
            // 快捷操作按钮
            HStack(spacing: 8) {
                Button(action: {
                    engine.setupGame()
                }) {
                    Label("新游戏", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundColor(.white.opacity(0.7))
                .disabled(engine.phase == .dealing)
                
                Button(action: {
                    if engine.phase == .roundEnd {
                        engine.nextRound()
                    }
                }) {
                    Label("下一局", systemImage: "forward.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundColor(engine.phase == .roundEnd ? .white : .white.opacity(0.3))
                .disabled(engine.phase != .roundEnd)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                
                // 顶部高光线
                VStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                    Spacer()
                }
                
                // 左侧状态色条
                HStack {
                    Rectangle()
                        .fill(statusColor.opacity(0.6))
                        .frame(width: 3)
                    Spacer()
                }
            }
        )
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(statusColor.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }
            
            Text(statusMessage)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch engine.phase {
        case .roundEnd: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .discarding where engine.currentPlayer?.isAI == false: return Color(red: 0.3, green: 0.85, blue: 0.4)
        case .claiming: return Color(red: 0.9, green: 0.6, blue: 0.1)
        default: return Color(red: 0.8, green: 0.5, blue: 0.2)
        }
    }
    
    private var statusMessage: String {
        switch engine.phase {
        case .roundEnd:
            return "局终 · 等待开始"
        case .discarding:
            if let player = engine.currentPlayer {
                return player.isAI ? "\(player.name) 出牌中..." : "你的回合 · 请选择手牌打出"
            }
            return "出牌中"
        case .claiming:
            return "鸣牌中..."
        case .playing:
            return "摸牌中..."
        default:
            return engine.phase.rawValue
        }
    }
}
