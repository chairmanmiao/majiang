import SwiftUI

@main
struct MahjongGameApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 820)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandMenu("游戏") {
                Button("新游戏") {
                    NotificationCenter.default.post(name: .newGame, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("下一局") {
                    NotificationCenter.default.post(name: .nextRound, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Divider()
                
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let newGame = Notification.Name("newGame")
    static let nextRound = Notification.Name("nextRound")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.minSize = NSSize(width: 960, height: 820)
            window.title = "macOS 麻将"
            window.setContentSize(NSSize(width: 1280, height: 900))
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

/// 主内容视图
struct ContentView: View {
    @StateObject private var engine = GameEngine()
    @State private var screen: AppScreen = .menu
    @State private var settings = GameSettings.load()
    @State private var showScorePanel = true
    
    var body: some View {
        Group {
            switch screen {
            case .menu:
                MenuView(engine: engine, screen: $screen, settings: $settings)
            case .game:
                gameView
            case .settings:
                SettingsView(screen: $screen, settings: $settings)
            case .loadGame:
                LoadGameView(engine: engine, screen: $screen)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newGame)) { _ in
            engine.setupGame(humanName: settings.playerName)
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextRound)) { _ in
            if engine.phase == .roundEnd {
                engine.nextRound()
            }
        }
    }
    
    private var gameView: some View {
        HStack(spacing: 0) {
            // 左侧分数面板
            if showScorePanel {
                ScoreBoardView(engine: engine)
                    .frame(width: 190)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1)
            }
            
            // 中间游戏区域
            VStack(spacing: 0) {
                toolbar
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 1)
                
                GameTableView(engine: engine)
            }
        }
    }
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Button(action: { showScorePanel.toggle() }) {
                    Image(systemName: showScorePanel ? "sidebar.leading" : "sidebar.leading.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.7))
                }
                .buttonStyle(.borderless)
                .help("显示/隐藏得分榜")
                
                Divider()
                    .frame(height: 14)
                
                Button(action: {
                    engine.setupGame(humanName: settings.playerName)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10))
                        Text("新游戏")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.primary.opacity(0.8))
                
                Button(action: {
                    if engine.phase == .roundEnd {
                        engine.nextRound()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 10))
                        Text("下一局")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.borderless)
                .foregroundColor(engine.phase == .roundEnd ? .primary.opacity(0.8) : .primary.opacity(0.3))
                .disabled(engine.phase != .roundEnd)
                
                Divider()
                    .frame(height: 14)
                
                Button(action: {
                    _ = engine.saveCurrentGame()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 10))
                        Text("保存")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.primary.opacity(0.7))
                
                Button(action: {
                    screen = .menu
                    engine.stopCountdown()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "house")
                            .font(.system(size: 10))
                        Text("主菜单")
                            .font(.system(size: 11))
                    }
                }
                .buttonStyle(.borderless)
                .foregroundColor(.primary.opacity(0.7))
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 20, height: 1)
                Text("🀄 麻将")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary.opacity(0.6))
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 20, height: 1)
            }
            
            Spacer()
            
            Button(action: {
                engine.togglePause()
            }) {
                Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .buttonStyle(.borderless)
            .help("暂停/继续")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
