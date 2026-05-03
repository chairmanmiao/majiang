import SwiftUI

/// 主菜单界面
struct MenuView: View {
    @ObservedObject var engine: GameEngine
    @Binding var screen: AppScreen
    @Binding var settings: GameSettings
    
    var body: some View {
        ZStack {
            // 背景
            Color(red: 0.08, green: 0.22, blue: 0.12)
                .ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.12, green: 0.32, blue: 0.18),
                    Color(red: 0.05, green: 0.15, blue: 0.08)
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 600
            )
            .ignoresSafeArea()
            
            VStack(spacing: 36) {
                Spacer()
                
                // Logo 区域
                VStack(spacing: 16) {
                    Image(systemName: "dice.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.1))
                    
                    Text("macOS 麻将")
                        .font(.system(size: 36, weight: .black))
                        .foregroundColor(.white)
                    
                    Text("经典四人麻将 · 红中万能")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // 菜单按钮
                VStack(spacing: 14) {
                    MenuButton(title: "开始游戏", icon: "play.fill", isPrimary: true) {
                        engine.setupGame(humanName: settings.playerName)
                        screen = .game
                    }
                    
                    MenuButton(title: "读取游戏", icon: "arrow.up.doc.fill") {
                        screen = .loadGame
                    }
                    
                    MenuButton(title: "游戏设置", icon: "gearshape.fill") {
                        screen = .settings
                    }
                    
                    MenuButton(title: "退出游戏", icon: "xmark.circle.fill") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .frame(maxWidth: 280)
                
                Spacer()
                
                Text("v1.5.1")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 16)
            }
        }
    }
}

/// 菜单按钮
struct MenuButton: View {
    let title: String
    let icon: String
    var isPrimary: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .foregroundColor(isPrimary ? .white : .white.opacity(0.85))
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPrimary ? Color(red: 0.85, green: 0.13, blue: 0.13) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(1.0)
    }
}

/// 读取游戏界面
struct LoadGameView: View {
    @ObservedObject var engine: GameEngine
    @Binding var screen: AppScreen
    
    @State private var saves: [GameSave] = []
    @State private var selectedSave: GameSave?
    @State private var showDeleteConfirm = false
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.22, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    Button(action: { screen = .menu }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回菜单")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text("读取游戏")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: loadSaves) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // 存档列表
                if saves.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.2))
                        Text("暂无存档")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(saves) { save in
                            SaveRow(save: save, isSelected: selectedSave?.id == save.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSave = save
                                }
                        }
                        .onDelete(perform: deleteSave)
                    }
                    .listStyle(.plain)
                    .background(Color.clear)
                }
                
                // 底部操作栏
                if let save = selectedSave {
                    HStack(spacing: 12) {
                        Button(action: {
                            showDeleteConfirm = true
                        }) {
                            Text("删除")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(action: {
                            if engine.loadGame(save: save) {
                                screen = .game
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                Text("读取并继续")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.2, green: 0.5, blue: 0.9))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Color.black.opacity(0.2)
                            .overlay(
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 1),
                                alignment: .top
                            )
                    )
                }
            }
        }
        .onAppear {
            loadSaves()
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let save = selectedSave {
                    engine.deleteSave(id: save.id)
                    loadSaves()
                    selectedSave = nil
                }
            }
        } message: {
            Text("确定要删除这个存档吗？此操作不可撤销。")
        }
    }
    
    private func loadSaves() {
        saves = engine.listSaves()
    }
    
    private func deleteSave(at offsets: IndexSet) {
        for index in offsets {
            let save = saves[index]
            engine.deleteSave(id: save.id)
        }
        loadSaves()
        selectedSave = nil
    }
}

struct SaveRow: View {
    let save: GameSave
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 20))
                .foregroundColor(isSelected ? Color(red: 0.2, green: 0.6, blue: 1.0) : .white.opacity(0.4))
            
            VStack(alignment: .leading, spacing: 3) {
                Text("第 \(save.currentRound) 局 · \(save.roundWind.shortName)风场")
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text(save.displayDate)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("牌墙 \(save.wall.count) 张")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
        )
    }
}

/// 设置界面
struct SettingsView: View {
    @Binding var screen: AppScreen
    @Binding var settings: GameSettings
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.22, blue: 0.12)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部栏
                HStack {
                    Button(action: { screen = .menu }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回菜单")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text("游戏设置")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        settings.save()
                        screen = .menu
                    }) {
                        Text("保存")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(red: 0.3, green: 0.85, blue: 0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // 设置项
                Form {
                    Section(header: Text("玩家信息").foregroundColor(.white.opacity(0.6))) {
                        HStack {
                            Text("玩家名称")
                                .foregroundColor(.white)
                            Spacer()
                            TextField("输入名称", text: $settings.playerName)
                                .frame(width: 140)
                                .multilineTextAlignment(.trailing)
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    
                    Section(header: Text("游戏选项").foregroundColor(.white.opacity(0.6))) {
                        Toggle("动画效果", isOn: $settings.enableAnimation)
                            .foregroundColor(.white)
                            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.2, green: 0.6, blue: 1.0)))
                        
                        Toggle("音效提示", isOn: $settings.enableSound)
                            .foregroundColor(.white)
                            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.2, green: 0.6, blue: 1.0)))
                        
                        Picker("牌桌颜色", selection: $settings.tableColor) {
                            ForEach(GameSettings.TableColor.allCases, id: \.self) { color in
                                Text(color.rawValue).tag(color)
                            }
                        }
                        .foregroundColor(.white)
                        .pickerStyle(.menu)
                        
                        HStack {
                            Text("回合时限")
                                .foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $settings.turnTimeLimit) {
                                Text("10秒").tag(10.0)
                                Text("15秒").tag(15.0)
                                Text("20秒").tag(20.0)
                                Text("30秒").tag(30.0)
                                Text("无限制").tag(999.0)
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}
