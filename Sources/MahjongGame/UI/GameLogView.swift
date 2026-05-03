import SwiftUI

/// 游戏日志侧边栏
struct GameLogView: View {
    let logs: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("游戏记录")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("\(logs.count) 条")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 8)
            
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                        LogRowView(index: index + 1, text: log)
                            .id(index)
                    }
                }
                .listStyle(.plain)
                .onChange(of: logs.count) { _ in
                    if let last = logs.indices.last {
                        withAnimation {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 200, idealWidth: 250)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// 单条日志行
struct LogRowView: View {
    let index: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(index)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: 22, alignment: .trailing)
                .monospacedDigit()
            
            // 左侧装饰竖线
            Rectangle()
                .fill(lineColor.opacity(0.4))
                .frame(width: 1.5)
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 1)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            index % 2 == 0 ? Color.clear : Color.black.opacity(0.02)
        )
    }
    
    private var lineColor: Color {
        if text.contains("胡") || text.contains("获胜") {
            return Color(red: 0.9, green: 0.2, blue: 0.2)
        } else if text.contains("杠") {
            return Color(red: 0.6, green: 0.2, blue: 0.7)
        } else if text.contains("碰") {
            return Color(red: 0.2, green: 0.45, blue: 0.85)
        } else if text.contains("吃") {
            return Color(red: 0.85, green: 0.5, blue: 0.1)
        } else if text.contains("摸") {
            return Color(red: 0.2, green: 0.65, blue: 0.35)
        }
        return Color.gray
    }
}

/// 分数面板
struct ScoreBoardView: View {
    @ObservedObject var engine: GameEngine
    
    var body: some View {
        // 引用触发器确保 SwiftUI 在分数变化时强制刷新
        let _ = engine.uiRefreshTrigger
        
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "chart.bar")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("得分榜")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 8)
            
            ForEach(Array(engine.players.enumerated()), id: \.offset) { index, player in
                ScoreRowView(player: player, isHuman: index == 0)
            }
            
            Spacer()
        }
        .frame(minWidth: 160, idealWidth: 190)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ScoreRowView: View {
    @ObservedObject var player: Player
    let isHuman: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(player.isDealer ? Color.yellow : Color.clear, lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                
                if player.isDealer {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.yellow)
                } else {
                    Circle()
                        .fill(isHuman ? Color.green.opacity(0.3) : Color.blue.opacity(0.15))
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(player.name)
                .font(.system(size: 12, weight: isHuman ? .bold : .regular))
            
            Spacer()
            
            Text("\(player.score)")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundColor(player.score >= 0 ? Color(red: 0.2, green: 0.7, blue: 0.3) : Color(red: 0.8, green: 0.2, blue: 0.2))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isHuman ? Color.green.opacity(0.05) : Color.clear
        )
        .overlay(
            HStack {
                Rectangle()
                    .fill(isHuman ? Color.green.opacity(0.3) : Color.clear)
                    .frame(width: 2)
                Spacer()
            }
        )
    }
}
