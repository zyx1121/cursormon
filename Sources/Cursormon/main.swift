import AppKit
import QuartzCore
import ImageIO
import ServiceManagement

// MARK: - Catalog

struct Species { let dex: Int; let name: String }
let SPECIES = [
    Species(dex: 1, name: "妙蛙種子"),
    Species(dex: 4, name: "小火龍"),
    Species(dex: 7, name: "傑尼龜"),
    Species(dex: 25, name: "皮卡丘"),
    Species(dex: 39, name: "胖丁"),
    Species(dex: 54, name: "可達鴨"),
    Species(dex: 79, name: "呆呆獸"),
    Species(dex: 129, name: "鯉魚王"),
    Species(dex: 132, name: "百變怪"),
    Species(dex: 133, name: "伊布"),
    Species(dex: 143, name: "卡比獸"),
    Species(dex: 151, name: "夢幻"),
    Species(dex: 778, name: "謎擬Q"),
]
let SCALES: [(name: String, value: CGFloat)] = [("小", 2.0), ("中", 2.6), ("大", 3.4)]
let GAPS: [(name: String, value: CGFloat)] = [("近", 42), ("中", 62), ("遠", 92)]

let CHASE: CGFloat = 0.14
let ANIM_MOVING = 0.5
let ANIM_IDLE = 0.12

// MARK: - Sprite loading — fetch Gen5 BW animated GIF from PokeAPI at runtime,
// decode with ImageIO, cache the raw .gif under Application Support. Sprites are
// NEVER bundled (© Nintendo); the app downloads them on first use.

struct SpriteFrame {
    let cgImage: CGImage
    let width: Int
    let height: Int
}

@MainActor
enum SpriteLoader {
    private static var cache: [Int: [SpriteFrame]] = [:]
    private static let base = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated"

    static func load(dex: Int) async -> [SpriteFrame] {
        if let c = cache[dex] { return c }
        let gif = supportDir().appendingPathComponent("\(dex).gif")
        if !FileManager.default.fileExists(atPath: gif.path) {
            guard let url = URL(string: "\(base)/\(dex).gif"),
                  let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
            try? data.write(to: gif)
        }
        let frames = decode(gif: gif)
        if !frames.isEmpty { cache[dex] = frames }
        return frames
    }

    private static func supportDir() -> URL {
        let dir = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                   ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Cursormon", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Decode every GIF frame, then crop all to the shared (union) alpha bbox so
    /// the sprite is tight and frames don't jitter. Native size, no rescaling.
    private static func decode(gif: URL) -> [SpriteFrame] {
        guard let src = CGImageSourceCreateWithURL(gif as CFURL, nil) else { return [] }
        let n = CGImageSourceGetCount(src)
        var imgs: [CGImage] = []
        imgs.reserveCapacity(n)
        for i in 0..<n {
            if let im = CGImageSourceCreateImageAtIndex(src, i, nil) { imgs.append(im) }
        }
        guard let first = imgs.first else { return [] }
        let w = first.width, h = first.height

        let cs = CGColorSpaceCreateDeviceRGB()
        let bmp = CGImageAlphaInfo.premultipliedLast.rawValue
        var minX = w, maxX = -1, minPxY = h, maxPxY = -1
        for im in imgs {
            var px = [UInt8](repeating: 0, count: w * h * 4)
            let ok = px.withUnsafeMutableBytes { buf -> Bool in
                guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h,
                                          bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: cs, bitmapInfo: bmp) else { return false }
                ctx.draw(im, in: CGRect(x: 0, y: 0, width: w, height: h))
                return true
            }
            guard ok else { continue }
            for y in 0..<h {
                let rowOff = y * w * 4
                for x in 0..<w where px[rowOff + x * 4 + 3] != 0 {
                    if x < minX { minX = x }; if x > maxX { maxX = x }
                    if y < minPxY { minPxY = y }; if y > maxPxY { maxPxY = y }
                }
            }
        }
        guard maxX >= minX, maxPxY >= minPxY else {
            return imgs.map { SpriteFrame(cgImage: $0, width: w, height: h) }
        }
        // The bitmap context is bottom-up (row 0 = bottom); CGImage.cropping uses a
        // top-left origin, so flip the Y span when building the crop rect.
        let cw = maxX - minX + 1
        let ch = maxPxY - minPxY + 1
        let rect = CGRect(x: minX, y: h - 1 - maxPxY, width: cw, height: ch)
        return imgs.compactMap { im in
            im.cropping(to: rect).map { SpriteFrame(cgImage: $0, width: cw, height: ch) }
        }
    }
}

// MARK: - Overlay panel (transparent, click-through, floats over everything)

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - One pet — trails behind its leader (cursor, or the pet ahead of it)

@MainActor
final class Pet {
    let dex: Int
    private let panel: OverlayPanel
    private let container: NSView
    private let spriteLayer = CALayer()
    private let frames: [SpriteFrame]
    private var panelSize: CGSize = .init(width: 100, height: 100)

    private(set) var pos: CGPoint
    private var lastLeader: CGPoint
    private var lastBearing = CGVector(dx: -1, dy: 0)
    private var facingRight = false
    private var frameAcc: Double = 0

    private var scale: CGFloat
    var gap: CGFloat

    init(dex: Int, frames: [SpriteFrame], scale: CGFloat, gap: CGFloat, start: CGPoint) {
        self.dex = dex
        self.frames = frames
        self.scale = scale
        self.gap = gap

        panel = OverlayPanel(contentRect: CGRect(x: 0, y: 0, width: 100, height: 100),
                             styleMask: [.borderless, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        container = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        container.wantsLayer = true
        spriteLayer.magnificationFilter = .nearest
        container.layer?.addSublayer(spriteLayer)
        panel.contentView = container

        pos = start
        lastLeader = start
        spriteLayer.contents = frames.first?.cgImage
        applyLayout()
        panel.orderFrontRegardless()
    }

    func setScale(_ s: CGFloat) { scale = s; applyLayout() }

    func close() { panel.orderOut(nil) }

    func raise() { panel.orderFrontRegardless() }

    private func applyLayout() {
        guard let first = frames.first else { return }
        let sw = CGFloat(first.width) * scale
        let sh = CGFloat(first.height) * scale
        let pw = sw + 24, ph = sh + 24
        panelSize = CGSize(width: pw, height: ph)
        panel.setContentSize(panelSize)
        container.frame = CGRect(origin: .zero, size: panelSize)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        spriteLayer.bounds = CGRect(x: 0, y: 0, width: sw, height: sh)
        spriteLayer.position = CGPoint(x: pw / 2, y: ph / 2)
        CATransaction.commit()
        panel.setFrameOrigin(CGPoint(x: pos.x - pw / 2, y: pos.y - ph / 2))
    }

    /// Advance one tick, trailing `gap` behind `leader` (its motion direction).
    func step(leader: CGPoint) {
        guard !frames.isEmpty else { return }
        let ldx = leader.x - lastLeader.x, ldy = leader.y - lastLeader.y
        let lLen = hypot(ldx, ldy)
        lastLeader = leader
        var bx: CGFloat, by: CGFloat
        if lLen > 0.5 {
            bx = -ldx / lLen; by = -ldy / lLen      // behind the leader's motion
            lastBearing = CGVector(dx: bx, dy: by)
        } else {
            bx = lastBearing.dx; by = lastBearing.dy // idle: hold last trail direction
        }
        let target = CGPoint(x: leader.x + bx * gap, y: leader.y + by * gap)

        let prev = pos
        pos.x += (target.x - pos.x) * CHASE
        pos.y += (target.y - pos.y) * CHASE

        let vx = pos.x - prev.x
        let speed = hypot(vx, pos.y - prev.y)
        if abs(vx) > 0.2 { facingRight = vx > 0 }

        frameAcc += speed > 0.3 ? ANIM_MOVING : ANIM_IDLE
        let idx = frames.count > 1 ? Int(frameAcc) % frames.count : 0

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel.setFrameOrigin(CGPoint(x: pos.x - panelSize.width / 2,
                                     y: pos.y - panelSize.height / 2))
        spriteLayer.contents = frames[idx].cgImage
        spriteLayer.transform = CATransform3DMakeScale(facingRight ? -1 : 1, 1, 1)
        CATransaction.commit()
    }
}

// MARK: - Manager — a conga line of pets; pet[0] trails the cursor, pet[i] trails pet[i-1]

@MainActor
final class PetManager {
    private(set) var pets: [Pet] = []
    private var timer: Timer?
    private var scale: CGFloat
    private var gap: CGFloat

    init(scale: CGFloat, gap: CGFloat) {
        self.scale = scale
        self.gap = gap
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        var leader = NSEvent.mouseLocation
        for p in pets {
            p.step(leader: leader)
            leader = p.pos                          // next pet trails this one
        }
    }

    /// Reconcile live pets with the desired dex list. Sprites are fetched lazily
    /// (downloaded on first use), so this is async; existing pets are reused.
    func setDexList(_ list: [Int]) async {
        let cursor = NSEvent.mouseLocation
        var next: [Pet] = []
        for dex in list {
            if let existing = pets.first(where: { $0.dex == dex }) {
                next.append(existing); continue
            }
            let frames = await SpriteLoader.load(dex: dex)
            guard !frames.isEmpty else { continue }
            next.append(Pet(dex: dex, frames: frames, scale: scale, gap: gap,
                            start: CGPoint(x: cursor.x - gap, y: cursor.y)))
        }
        for p in pets where !list.contains(p.dex) { p.close() }
        pets = next
        // Stack so the pet nearest the cursor (pet[0]) sits on top of the ones behind.
        for p in pets.reversed() { p.raise() }
    }

    func setScale(_ s: CGFloat) { scale = s; pets.forEach { $0.setScale(s) } }
    func setGap(_ g: CGFloat) { gap = g; pets.forEach { $0.gap = g } }
}

// MARK: - App: menubar status item + menu (pick pokémon, size, distance, launch, quit)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var manager: PetManager!
    private let defaults = UserDefaults.standard

    private var selected: [Int] = [54]   // ordered: front = nearest the cursor
    private var scaleIdx = 0
    private var gapIdx = 1

    private var speciesItems: [NSMenuItem] = []
    private var scaleItems: [NSMenuItem] = []
    private var gapItems: [NSMenuItem] = []
    private var launchItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let saved = defaults.array(forKey: "dexList") as? [Int], !saved.isEmpty {
            selected = saved
        }
        scaleIdx = (defaults.object(forKey: "scaleIdx") as? Int).map { min(max($0, 0), SCALES.count - 1) } ?? 0
        gapIdx = (defaults.object(forKey: "gapIdx") as? Int).map { min(max($0, 0), GAPS.count - 1) } ?? 1

        manager = PetManager(scale: SCALES[scaleIdx].value, gap: GAPS[gapIdx].value)
        manager.start()
        buildStatusItem()
        Task { await manager.setDexList(orderedList()) }   // fetches sprites on first run
        NSLog("Cursormon: started")
    }

    /// The conga line in user-chosen order (front of list = nearest the cursor).
    private func orderedList() -> [Int] { selected }

    // MARK: menu

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // 選單列圖示 = 全家共用的 zyx 品牌標(Resources/MenubarIcon.png,template),找不到才退回 SF Symbol。
        if let p = Bundle.main.path(forResource: "MenubarIcon", ofType: "png"),
           let mark = NSImage(contentsOfFile: p) {
            let h: CGFloat = 18
            mark.size = NSSize(width: h * mark.size.width / max(mark.size.height, 1), height: h)
            mark.isTemplate = true
            statusItem.button?.image = mark
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Cursormon")
            statusItem.button?.image?.isTemplate = true
        }

        let menu = NSMenu()

        let pokeRoot = NSMenuItem(title: "寶可夢", action: nil, keyEquivalent: "")
        let pokeMenu = NSMenu()
        for s in SPECIES {
            let it = NSMenuItem(title: s.name, action: #selector(toggleSpecies(_:)), keyEquivalent: "")
            it.target = self
            it.tag = s.dex
            it.state = selected.contains(s.dex) ? .on : .off
            pokeMenu.addItem(it)
            speciesItems.append(it)
        }
        pokeRoot.submenu = pokeMenu
        menu.addItem(pokeRoot)

        menu.addItem(.separator())
        menu.addItem(submenu("大小", names: SCALES.map(\.name),
                             action: #selector(pickScale(_:)), current: scaleIdx, store: &scaleItems))
        menu.addItem(submenu("跟隨距離", names: GAPS.map(\.name),
                             action: #selector(pickGap(_:)), current: gapIdx, store: &gapItems))

        menu.addItem(.separator())
        launchItem = NSMenuItem(title: "登入時啟動", action: #selector(toggleLaunch), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "結束", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func submenu(_ title: String, names: [String], action: Selector,
                         current: Int, store: inout [NSMenuItem]) -> NSMenuItem {
        let sub = NSMenu()
        for (i, name) in names.enumerated() {
            let it = NSMenuItem(title: name, action: action, keyEquivalent: "")
            it.target = self
            it.tag = i
            it.state = (i == current) ? .on : .off
            sub.addItem(it)
            store.append(it)
        }
        let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        root.submenu = sub
        return root
    }

    @objc private func toggleSpecies(_ sender: NSMenuItem) {
        if let i = selected.firstIndex(of: sender.tag) { selected.remove(at: i) }
        else { selected.append(sender.tag) }   // newly added joins the tail of the line
        defaults.set(orderedList(), forKey: "dexList")
        for it in speciesItems { it.state = selected.contains(it.tag) ? .on : .off }
        Task { await manager.setDexList(orderedList()) }
    }

    @objc private func pickScale(_ sender: NSMenuItem) {
        scaleIdx = sender.tag
        manager.setScale(SCALES[scaleIdx].value)
        defaults.set(scaleIdx, forKey: "scaleIdx")
        for it in scaleItems { it.state = (it.tag == scaleIdx) ? .on : .off }
    }

    @objc private func pickGap(_ sender: NSMenuItem) {
        gapIdx = sender.tag
        manager.setGap(GAPS[gapIdx].value)
        defaults.set(gapIdx, forKey: "gapIdx")
        for it in gapItems { it.state = (it.tag == gapIdx) ? .on : .off }
    }

    // 開機自啟走 SMAppService（macOS 13+），不手寫 LaunchAgent —— app 搬家 / 改名也不會壞。
    // 需要 app 安裝在 /Applications。
    @objc private func toggleLaunch() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("[Cursormon] login item toggle failed: \(error)")
        }
        launchItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
