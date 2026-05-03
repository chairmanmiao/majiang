import SwiftUI

/// Toast 提示视图
struct ToastView: View {
    let message: ToastMessage
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Text(message.text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
                
                // 顶部高光线
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                
                // 左侧装饰线
                HStack {
                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 3)
                    Spacer()
                }
            }
        )
        .shadow(color: backgroundColor.opacity(0.4), radius: 8, x: 0, y: 4)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + message.duration) {
                isVisible = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        switch message.type {
        case .info:
            return Color(red: 0.2, green: 0.5, blue: 0.8)
        case .success:
            return Color(red: 0.2, green: 0.65, blue: 0.35)
        case .warning:
            return Color(red: 0.85, green: 0.55, blue: 0.1)
        case .error:
            return Color(red: 0.8, green: 0.2, blue: 0.2)
        }
    }
    
    private var iconName: String {
        switch message.type {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

/// 吃碰杠选择面板
struct ClaimSelectionPanel: View {
    let actions: [AvailableAction]
    let onAction: (AvailableAction) -> Void
    let onPass: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                Text("可以选择动作")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 10) {
                ForEach(actions) { action in
                    ClaimActionButton(action: action) {
                        onAction(action)
                    }
                }
                
                PassButton {
                    onPass()
                }
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.75))
                
                // 几何线条装饰
                Canvas { context, size in
                    let w = size.width
                    let h = size.height
                    
                    // 外边框
                    var border = Path()
                    border.addRoundedRect(in: CGRect(x: 1, y: 1, width: w-2, height: h-2), cornerSize: CGSize(width: 11, height: 11))
                    context.stroke(border, with: .color(Color.white.opacity(0.2)), lineWidth: 1)
                    
                    // 顶部装饰线
                    var topLine = Path()
                    topLine.move(to: CGPoint(x: w*0.2, y: 0))
                    topLine.addLine(to: CGPoint(x: w*0.8, y: 0))
                    context.stroke(topLine, with: .color(Color.yellow.opacity(0.4)), lineWidth: 2)
                }
            }
        )
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}

/// 鸣牌动作按钮（带牌预览）
struct ClaimActionButton: View {
    let action: AvailableAction
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(action.action.rawValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                // 预览涉及的牌
                HStack(spacing: 1) {
                    ForEach(action.tiles.prefix(4)) { tile in
                        TileView(tile: tile, scale: 0.45)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(buttonColor.opacity(0.9))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    
                    // 内部线条纹理
                    Canvas { context, size in
                        let w = size.width
                        let h = size.height
                        for y in stride(from: 4.0, to: Double(h), by: 6.0) {
                            var line = Path()
                            line.move(to: CGPoint(x: 4, y: y))
                            line.addLine(to: CGPoint(x: w - 4, y: y))
                            context.stroke(line, with: .color(Color.white.opacity(0.05)), lineWidth: 0.5)
                        }
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: 0.15), value: action.id)
    }
    
    private var buttonColor: Color {
        switch action.action {
        case .win: return Color(red: 0.85, green: 0.15, blue: 0.15)
        case .kong, .concealedKong, .addKong: return Color(red: 0.6, green: 0.2, blue: 0.7)
        case .pong: return Color(red: 0.15, green: 0.45, blue: 0.8)
        case .chow: return Color(red: 0.85, green: 0.5, blue: 0.1)
        default: return Color.gray
        }
    }
}

/// 过牌按钮
struct PassButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("过")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.6))
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
            )
        }
        .buttonStyle(.plain)
    }
}
