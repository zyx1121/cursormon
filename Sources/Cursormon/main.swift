import AppKit
import QuartzCore

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

// MARK: - Sprite loading (decode once, cache per dex)
//
// Each <dex>.json is a Gen5 BW animated sprite decoded to {w, h, frames:[[row...]]},
// every pixel a packed 0xRRGGBB Int, negative meaning transparent.

struct SpriteFrame {
    let cgImage: CGImage
    let width: Int
    let height: Int
}

@MainActor
enum SpriteLoader {
    private static var cache: [Int: [SpriteFrame]] = [:]

    static func load(dex: Int) -> [SpriteFrame] {
        if let c = cache[dex] { return c }
        let frames = decode(dex: dex)
        cache[dex] = frames
        return frames
    }

    private static func decode(dex: Int) -> [SpriteFrame] {
        guard let url = Bundle.main.url(forResource: String(dex), withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let w = obj["w"] as? Int, let h = obj["h"] as? Int
        else { return [] }

        let framesData: [[[Int]]]
        if let frames = obj["frames"] as? [[[Int]]] {
            framesData = frames
        } else if let rows = obj["rows"] as? [[Int]] {
            framesData = [rows]
        } else {
            framesData = []
        }
        return framesData.compactMap { rows in
            makeImage(rows: rows, w: w, h: h).map { SpriteFrame(cgImage: $0, width: w, height: h) }
        }
    }

    private static func makeImage(rows: [[Int]], w: Int, h: Int) -> CGImage? {
        var px = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<h {
            let row = y < rows.count ? rows[y] : []
            for x in 0..<w {
                let v = x < row.count ? row[x] : -1
                let i = (y * w + x) * 4
                if v < 0 { continue }
                px[i + 0] = UInt8((v >> 16) & 255)
                px[i + 1] = UInt8((v >> 8) & 255)
                px[i + 2] = UInt8(v & 255)
                px[i + 3] = 255
            }
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let bmp = CGImageAlphaInfo.premultipliedLast.rawValue
        return px.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                      bytesPerRow: w * 4, space: cs, bitmapInfo: bmp)?.makeImage()
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

    init(dex: Int, scale: CGFloat, gap: CGFloat, start: CGPoint) {
        self.dex = dex
        self.scale = scale
        self.gap = gap
        frames = SpriteLoader.load(dex: dex)

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

    /// Reconcile live pets with the desired dex list (order preserved, existing reused).
    func setDexList(_ list: [Int]) {
        let cursor = NSEvent.mouseLocation
        var next: [Pet] = []
        for dex in list {
            if let existing = pets.first(where: { $0.dex == dex }) {
                next.append(existing)
            } else {
                next.append(Pet(dex: dex, scale: scale, gap: gap,
                                start: CGPoint(x: cursor.x - gap, y: cursor.y)))
            }
        }
        for p in pets where !list.contains(p.dex) { p.close() }
        pets = next
        // Stack so the pet nearest the cursor (pet[0]) sits on top of the ones behind:
        // raising last→first leaves pet[0] frontmost.
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
        manager.setDexList(orderedList())
        manager.start()
        buildStatusItem()
        NSLog("Cursormon: started (pets=\(manager.pets.count))")
    }

    /// The conga line in user-chosen order (front of list = nearest the cursor).
    private func orderedList() -> [Int] { selected }

    // MARK: menu

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Cursormon")
        statusItem.button?.image?.isTemplate = true

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
        launchItem.state = isLaunchAtLogin() ? .on : .off
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
        manager.setDexList(orderedList())
        defaults.set(orderedList(), forKey: "dexList")
        for it in speciesItems { it.state = selected.contains(it.tag) ? .on : .off }
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

    @objc private func toggleLaunch() {
        let on = !isLaunchAtLogin()
        setLaunchAtLogin(on)
        launchItem.state = on ? .on : .off
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: launch-at-login via a LaunchAgent plist (loads next login; RunAtLoad)

    private func launchPlistURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/dev.zyx.cursormon.plist")
    }

    private func isLaunchAtLogin() -> Bool {
        FileManager.default.fileExists(atPath: launchPlistURL().path)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        let url = launchPlistURL()
        if on {
            let exe = Bundle.main.executablePath ?? ""
            let plist: [String: Any] = [
                "Label": "dev.zyx.cursormon",
                "ProgramArguments": [exe],
                "RunAtLoad": true,
            ]
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try? data.write(to: url)
            }
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
