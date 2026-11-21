// CppControls.swift
// Lớp điều khiển ảo cho chương trình C++ có GUI (SDL3), kiểu PojavLauncher: con trỏ chuột điều khiển bằng
// bàn chạm, nút bấm gán phím/chuột, chỉnh sửa nút, tuỳ chỉnh con trỏ, nút buộc mở bàn phím ảo, ẩn/hiện nút.
// Chỉ hiện khi dự án dùng SDL (GUI); chương trình CLI thì ẩn. Gửi sự kiện qua CatnipInput (SDL_PushEvent).
// Chưa build/kiểm chứng.

import UIKit

// MARK: - Cấu hình

struct CtrlButton: Codable {
    var id: String = UUID().uuidString
    var label: String
    var key: String          // "W", "Space", "Shift", "Mouse Left", "Wheel Up"...
    var x: Double            // tâm nút, tỉ lệ theo bề rộng màn hình
    var y: Double            // tâm nút, tỉ lệ theo bề cao màn hình
    var size: Double = 56
    var opacity: Double = 0.6
    var toggle: Bool = false // true: bấm một lần là giữ, bấm nữa là nhả
    var square: Bool = false

    init(label: String, key: String, x: Double, y: Double, size: Double = 56, toggle: Bool = false) {
        self.label = label; self.key = key; self.x = x; self.y = y; self.size = size; self.toggle = toggle
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? "?"
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? "Space"
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 0.5
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 0.5
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? 56
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.6
        toggle = try c.decodeIfPresent(Bool.self, forKey: .toggle) ?? false
        square = try c.decodeIfPresent(Bool.self, forKey: .square) ?? false
    }
}

struct CursorStyle: Codable {
    var shape: String = "arrow"     // arrow, dot, cross, ring
    var size: Double = 28
    var color: String = "#FFFFFF"
    var opacity: Double = 0.9
    var speed: Double = 1.5         // hệ số nhân khi kéo ngón tay

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        shape = try c.decodeIfPresent(String.self, forKey: .shape) ?? "arrow"
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? 28
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#FFFFFF"
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 0.9
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? 1.5
    }
}

struct ControlsConfig: Codable {
    var buttons: [CtrlButton] = ControlsConfig.defaultButtons
    var cursor = CursorStyle()
    var hidden = false              // ẩn các nút điều khiển (con trỏ/bàn chạm vẫn hoạt động)
    var touchpad = true             // true: kéo ngón tay để điều khiển con trỏ; false: chạm trực tiếp xuống SDL

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        buttons = try c.decodeIfPresent([CtrlButton].self, forKey: .buttons) ?? ControlsConfig.defaultButtons
        cursor = try c.decodeIfPresent(CursorStyle.self, forKey: .cursor) ?? CursorStyle()
        hidden = try c.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
        touchpad = try c.decodeIfPresent(Bool.self, forKey: .touchpad) ?? true
    }

    static var defaultButtons: [CtrlButton] {
        [
            CtrlButton(label: "W", key: "W", x: 0.13, y: 0.58),
            CtrlButton(label: "A", key: "A", x: 0.06, y: 0.76),
            CtrlButton(label: "S", key: "S", x: 0.13, y: 0.76),
            CtrlButton(label: "D", key: "D", x: 0.20, y: 0.76),
            CtrlButton(label: "Space", key: "Space", x: 0.88, y: 0.78, size: 64),
            CtrlButton(label: "Shift", key: "Shift", x: 0.78, y: 0.78, toggle: true),
            CtrlButton(label: "E", key: "E", x: 0.80, y: 0.60),
            CtrlButton(label: "Esc", key: "Esc", x: 0.50, y: 0.08, size: 44),
            CtrlButton(label: "LMB", key: "Mouse Left", x: 0.92, y: 0.58),
            CtrlButton(label: "RMB", key: "Mouse Right", x: 0.92, y: 0.42),
        ]
    }
}

enum ControlsStore {
    private static func file(_ project: String) -> URL {
        let safe = project.replacingOccurrences(of: "/", with: "_")
        return CatnipPaths.root.appendingPathComponent("Controls", isDirectory: true).appendingPathComponent(safe + ".json")
    }
    static func load(_ project: String) -> ControlsConfig {
        guard let d = try? Data(contentsOf: file(project)), let c = try? JSONDecoder().decode(ControlsConfig.self, from: d) else { return ControlsConfig() }
        return c
    }
    static func save(_ c: ControlsConfig, project: String) {
        let f = file(project)
        try? FileManager.default.createDirectory(at: f.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let d = try? JSONEncoder().encode(c) { try? d.write(to: f, options: .atomic) }
    }
}

enum CtrlKeys {
    static let groups: [(String, [String])] = [
        ("Chữ", (65...90).map { String(UnicodeScalar($0)!) }),
        ("Số", ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
        ("Mũi tên", ["Up", "Down", "Left", "Right"]),
        ("Đặc biệt", ["Space", "Enter", "Esc", "Tab", "Backspace", "Delete", "Shift", "Ctrl", "Alt", "Home", "End", "PageUp", "PageDown"]),
        ("F1–F12", (1...12).map { "F\($0)" }),
        ("Chuột", ["Mouse Left", "Mouse Right", "Mouse Middle", "Wheel Up", "Wheel Down"]),
    ]
}

// MARK: - Gửi sự kiện vào SDL

enum GameInput {
    static var available: Bool {
        #if CATNIP_HAS_LOVE
        return true
        #else
        return false
        #endif
    }

    static func press(_ key: String, down: Bool) {
        #if CATNIP_HAS_LOVE
        switch key {
        case "Mouse Left": CatnipInput.mouseButton(1, down: down)
        case "Mouse Middle": CatnipInput.mouseButton(2, down: down)
        case "Mouse Right": CatnipInput.mouseButton(3, down: down)
        case "Wheel Up": if down { CatnipInput.scroll(x: 0, y: 1) }
        case "Wheel Down": if down { CatnipInput.scroll(x: 0, y: -1) }
        default: CatnipInput.sendKey(named: key, down: down)
        }
        #endif
    }

    static func move(nx: Double, ny: Double) {
        #if CATNIP_HAS_LOVE
        CatnipInput.moveMouse(toX: nx, y: ny)
        #endif
    }

    static func scroll(_ dy: Double) {
        #if CATNIP_HAS_LOVE
        CatnipInput.scroll(x: 0, y: dy)
        #endif
    }

    static func showKeyboard() {
        #if CATNIP_HAS_LOVE
        CatnipInput.startTextInput()
        #endif
    }

    static func quit() {
        #if CATNIP_HAS_LOVE
        CatnipInput.requestQuit()
        #endif
    }
}

// MARK: - Con trỏ

final class CursorView: UIView {
    var style = CursorStyle() { didSet { apply() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        apply()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func apply() {
        let s = CGFloat(style.size)
        bounds = CGRect(x: 0, y: 0, width: s, height: s)
        alpha = CGFloat(style.opacity)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        let color = UIColor(hex: style.color) ?? .white
        let s = bounds.width
        color.setFill()
        color.setStroke()
        UIColor.black.withAlphaComponent(0.7).setStroke()
        switch style.shape {
        case "dot":
            let p = UIBezierPath(ovalIn: bounds.insetBy(dx: s * 0.3, dy: s * 0.3))
            color.setFill(); p.fill()
            p.lineWidth = 1; UIColor.black.withAlphaComponent(0.6).setStroke(); p.stroke()
        case "cross":
            let p = UIBezierPath()
            p.move(to: CGPoint(x: s / 2, y: 2)); p.addLine(to: CGPoint(x: s / 2, y: s - 2))
            p.move(to: CGPoint(x: 2, y: s / 2)); p.addLine(to: CGPoint(x: s - 2, y: s / 2))
            p.lineWidth = 4; UIColor.black.withAlphaComponent(0.6).setStroke(); p.stroke()
            p.lineWidth = 2; color.setStroke(); p.stroke()
        case "ring":
            let p = UIBezierPath(ovalIn: bounds.insetBy(dx: 3, dy: 3))
            p.lineWidth = 4; UIColor.black.withAlphaComponent(0.6).setStroke(); p.stroke()
            p.lineWidth = 2; color.setStroke(); p.stroke()
        default:   // mũi tên, đầu nhọn ở góc trên trái (điểm bấm)
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 1, y: 1))
            p.addLine(to: CGPoint(x: 1, y: s * 0.85))
            p.addLine(to: CGPoint(x: s * 0.25, y: s * 0.63))
            p.addLine(to: CGPoint(x: s * 0.42, y: s * 0.98))
            p.addLine(to: CGPoint(x: s * 0.55, y: s * 0.92))
            p.addLine(to: CGPoint(x: s * 0.38, y: s * 0.58))
            p.addLine(to: CGPoint(x: s * 0.68, y: s * 0.58))
            p.close()
            color.setFill(); p.fill()
            p.lineWidth = 1.2; UIColor.black.setStroke(); p.stroke()
        }
    }

    /// Vị trí vẽ: mũi tên lấy góc trên trái làm điểm bấm, các kiểu còn lại lấy tâm.
    func place(at p: CGPoint) {
        if style.shape == "arrow" { frame.origin = p } else { center = p }
    }
}

// MARK: - Nút điều khiển

final class CtrlButtonView: UIView {
    var model: CtrlButton { didSet { refresh() } }
    var editing = false { didSet { pan.isEnabled = editing; tap.isEnabled = editing; refresh() } }
    var onEditTap: ((CtrlButton) -> Void)?
    var onMoved: ((CtrlButton, CGPoint) -> Void)?
    private let label = UILabel()
    private var held = false
    private let pan = UIPanGestureRecognizer()
    private let tap = UITapGestureRecognizer()
    private var panStart = CGPoint.zero

    init(model: CtrlButton) {
        self.model = model
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        label.textAlignment = .center
        label.textColor = .white
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.frame = bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(label)
        pan.addTarget(self, action: #selector(panned(_:)))
        tap.addTarget(self, action: #selector(tapped))
        pan.isEnabled = false; tap.isEnabled = false
        addGestureRecognizer(pan); addGestureRecognizer(tap)
        layer.borderWidth = 2
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        label.text = model.label
        let alpha = CGFloat(model.opacity)
        backgroundColor = (held ? UIColor.systemBlue : UIColor.black).withAlphaComponent(held ? 0.75 : alpha * 0.7)
        layer.borderColor = (editing ? UIColor.systemYellow : UIColor.white.withAlphaComponent(alpha + 0.2)).cgColor
        layer.cornerRadius = model.square ? 10 : bounds.width / 2
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = model.square ? 10 : bounds.width / 2
    }

    private func setHeld(_ on: Bool) {
        guard held != on else { return }
        held = on
        GameInput.press(model.key, down: on)
        refresh()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !editing else { return }
        if model.toggle { setHeld(!held) } else { setHeld(true) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !editing, !model.toggle else { return }
        setHeld(false)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !editing, !model.toggle else { return }
        setHeld(false)
    }

    func releaseIfHeld() { if held { setHeld(false) } }

    @objc private func tapped() { onEditTap?(model) }

    @objc private func panned(_ g: UIPanGestureRecognizer) {
        guard let sup = superview else { return }
        if g.state == .began { panStart = center }
        let t = g.translation(in: sup)
        center = CGPoint(x: panStart.x + t.x, y: panStart.y + t.y)
        if g.state == .ended || g.state == .cancelled { onMoved?(model, center) }
    }
}

// MARK: - Khung điều khiển (toàn màn hình, trong suốt)

final class ControlsView: UIView {
    var config = ControlsConfig() { didSet { applyConfig() } }
    var onConfigChange: ((ControlsConfig) -> Void)?
    var onEditButton: ((CtrlButton) -> Void)?
    var onGear: (() -> Void)?
    var onEye: (() -> Void)?
    var editMode = false { didSet { buttonViews.values.forEach { $0.editing = editMode }; applyConfig() } }

    let cursorView = CursorView()
    private var buttonViews: [String: CtrlButtonView] = [:]
    let gearButton = UIButton(type: .system)
    let keyboardButton = UIButton(type: .system)
    let eyeButton = UIButton(type: .system)
    private var cursorPos = CGPoint.zero
    private var cursorInit = false

    // trạng thái bàn chạm
    private var tpStart = CGPoint.zero, tpLast = CGPoint.zero
    private var tpTime: TimeInterval = 0
    private var tpMoved = false, dragging = false
    private var tpMax = 0
    private var holdTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        addSubview(cursorView)
        func style(_ b: UIButton, _ symbol: String) {
            b.setImage(UIImage(systemName: symbol), for: .normal)
            b.tintColor = .white
            b.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            b.layer.cornerRadius = 20
            b.layer.borderWidth = 1.5
            b.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
            addSubview(b)
        }
        style(gearButton, "gearshape.fill")
        style(keyboardButton, "keyboard")
        style(eyeButton, "eye.slash")
        gearButton.addAction(UIAction { [weak self] _ in self?.onGear?() }, for: .touchUpInside)
        keyboardButton.addAction(UIAction { _ in GameInput.showKeyboard() }, for: .touchUpInside)
        eyeButton.addAction(UIAction { [weak self] _ in self?.onEye?() }, for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyConfig() {
        cursorView.style = config.cursor
        cursorView.isHidden = !config.touchpad
        // dựng lại nút nếu danh sách đổi
        let ids = Set(config.buttons.map { $0.id })
        for (id, v) in buttonViews where !ids.contains(id) { v.releaseIfHeld(); v.removeFromSuperview(); buttonViews[id] = nil }
        for b in config.buttons {
            if let v = buttonViews[b.id] { v.model = b }
            else {
                let v = CtrlButtonView(model: b)
                v.editing = editMode
                v.onEditTap = { [weak self] m in self?.onEditButton?(m) }
                v.onMoved = { [weak self] m, c in self?.buttonMoved(m, to: c) }
                insertSubview(v, belowSubview: cursorView)
                buttonViews[b.id] = v
            }
        }
        let show = !config.hidden || editMode
        buttonViews.values.forEach { $0.isHidden = !show }
        eyeButton.setImage(UIImage(systemName: config.hidden ? "eye" : "eye.slash"), for: .normal)
        setNeedsLayout()
        if cursorInit { cursorView.place(at: cursorPos) }
    }

    private func buttonMoved(_ m: CtrlButton, to c: CGPoint) {
        guard bounds.width > 0, bounds.height > 0, let i = config.buttons.firstIndex(where: { $0.id == m.id }) else { return }
        config.buttons[i].x = Double(min(max(c.x / bounds.width, 0.02), 0.98))
        config.buttons[i].y = Double(min(max(c.y / bounds.height, 0.02), 0.98))
        onConfigChange?(config)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let safe = safeAreaInsets
        let top = max(safe.top, 8) + 4
        var x = max(safe.left, 8) + 4
        for b in [gearButton, keyboardButton, eyeButton] {
            b.frame = CGRect(x: x, y: top, width: 40, height: 40)
            x += 48
        }
        for (id, v) in buttonViews {
            guard let m = config.buttons.first(where: { $0.id == id }) else { continue }
            let s = CGFloat(m.size)
            v.bounds = CGRect(x: 0, y: 0, width: s, height: s)
            v.center = CGPoint(x: CGFloat(m.x) * bounds.width, y: CGFloat(m.y) * bounds.height)
        }
        if !cursorInit, bounds.width > 0 {
            cursorPos = CGPoint(x: bounds.midX, y: bounds.midY)
            cursorInit = true
            GameInput.move(nx: 0.5, ny: 0.5)
        }
        if cursorInit { cursorView.place(at: cursorPos) }
        bringSubviewToFront(cursorView)
        [gearButton, keyboardButton, eyeButton].forEach { bringSubviewToFront($0) }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let h = super.hitTest(point, with: event)
        if h === self { return config.touchpad ? self : nil }
        return h === cursorView ? self : h
    }

    // MARK: Bàn chạm

    private func moveCursor(by d: CGPoint) {
        let k = CGFloat(config.cursor.speed)
        cursorPos.x = min(max(cursorPos.x + d.x * k, 0), bounds.width)
        cursorPos.y = min(max(cursorPos.y + d.y * k, 0), bounds.height)
        cursorView.place(at: cursorPos)
        if bounds.width > 0, bounds.height > 0 {
            GameInput.move(nx: Double(cursorPos.x / bounds.width), ny: Double(cursorPos.y / bounds.height))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard config.touchpad else { return }
        let all = event?.touches(for: self) ?? touches
        tpMax = max(tpMax, all.count)
        if all.count == 1, let t = touches.first {
            tpStart = t.location(in: self); tpLast = tpStart; tpTime = t.timestamp
            tpMoved = false; dragging = false
            holdTimer?.invalidate()
            holdTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                guard let self = self, !self.tpMoved, self.tpMax == 1 else { return }
                self.dragging = true
                GameInput.press("Mouse Left", down: true)
            }
        } else {
            holdTimer?.invalidate()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard config.touchpad, let t = touches.first else { return }
        let p = t.location(in: self)
        let d = CGPoint(x: p.x - tpLast.x, y: p.y - tpLast.y)
        tpLast = p
        if hypot(p.x - tpStart.x, p.y - tpStart.y) > 8 {
            tpMoved = true
            if !dragging { holdTimer?.invalidate() }
        }
        let count = event?.touches(for: self)?.count ?? 1
        if count >= 2 { GameInput.scroll(Double(-d.y) / 12) } else { moveCursor(by: d) }
    }

    private func endTouches(_ touches: Set<UITouch>, with event: UIEvent?, cancelled: Bool) {
        guard config.touchpad else { return }
        holdTimer?.invalidate()
        if dragging {
            GameInput.press("Mouse Left", down: false)
            dragging = false
        } else if !cancelled, !tpMoved, let t = touches.first, t.timestamp - tpTime < 0.35 {
            let key = tpMax >= 2 ? "Mouse Right" : "Mouse Left"
            GameInput.press(key, down: true)
            GameInput.press(key, down: false)
        }
        let remaining = (event?.touches(for: self)?.count ?? 0) - touches.count
        if remaining <= 0 { tpMax = 0; tpMoved = false }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches, with: event, cancelled: false) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches, with: event, cancelled: true) }

    func releaseAll() { buttonViews.values.forEach { $0.releaseIfHeld() } }
}

// MARK: - View controller + cửa sổ nổi

private final class ControlsWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let h = super.hitTest(point, with: event)
        return h === self ? nil : h
    }
}

final class ControlsViewController: UIViewController {
    private let project: String
    private var config: ControlsConfig
    private let controls = ControlsView()
    private let editBar = UIStackView()
    weak var hostWindow: UIWindow?
    private var previousKey: UIWindow?

    init(project: String) {
        self.project = project
        self.config = ControlsStore.load(project)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { OrientationPolicy.mask }

    override func loadView() { view = controls }

    override func viewDidLoad() {
        super.viewDidLoad()
        controls.config = config
        controls.onConfigChange = { [weak self] c in self?.update(c) }
        controls.onEditButton = { [weak self] b in self?.editButton(b) }
        controls.onGear = { [weak self] in self?.showMenu() }
        controls.onEye = { [weak self] in self?.toggleHidden() }

        editBar.axis = .horizontal
        editBar.spacing = 8
        editBar.isHidden = true
        editBar.translatesAutoresizingMaskIntoConstraints = false
        func bar(_ title: String, _ color: UIColor, _ action: @escaping () -> Void) {
            var cfg = UIButton.Configuration.filled()
            cfg.title = title
            cfg.cornerStyle = .capsule
            cfg.baseBackgroundColor = color
            cfg.baseForegroundColor = .white
            let b = UIButton(configuration: cfg)
            b.addAction(UIAction { _ in action() }, for: .touchUpInside)
            editBar.addArrangedSubview(b)
        }
        bar("+ Thêm nút", .systemBlue) { [weak self] in self?.addButton() }
        bar("Mặc định", .systemGray) { [weak self] in self?.confirmReset() }
        bar("Xong", .systemGreen) { [weak self] in self?.setEditing(false) }
        controls.addSubview(editBar)
        NSLayoutConstraint.activate([
            editBar.centerXAnchor.constraint(equalTo: controls.centerXAnchor),
            editBar.topAnchor.constraint(equalTo: controls.safeAreaLayoutGuide.topAnchor, constant: 8),
        ])
    }

    private func update(_ c: ControlsConfig) {
        config = c
        controls.config = c
        ControlsStore.save(c, project: project)
    }

    func teardown() { controls.releaseAll() }

    // MARK: Trình bày hộp thoại từ cửa sổ không phải key

    private func present(_ vc: UIViewController) {
        previousKey = UIApplication.shared.windows.first { $0.isKeyWindow && $0 !== hostWindow }
        hostWindow?.makeKey()
        vc.popoverPresentationController?.sourceView = controls.gearButton
        vc.popoverPresentationController?.sourceRect = controls.gearButton.bounds
        present(vc, animated: true)
    }

    private func restoreKey() {
        previousKey?.makeKey()
        previousKey = nil
    }

    private func action(_ title: String, _ style: UIAlertAction.Style = .default, _ h: @escaping () -> Void) -> UIAlertAction {
        UIAlertAction(title: title, style: style) { [weak self] _ in self?.restoreKey(); h() }
    }

    private func cancel() -> UIAlertAction {
        UIAlertAction(title: "Đóng", style: .cancel) { [weak self] _ in self?.restoreKey() }
    }

    private func sheet(_ title: String?, _ message: String? = nil) -> UIAlertController {
        UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
    }

    private func prompt(_ title: String, _ message: String?, text: String, keyboard: UIKeyboardType = .default, _ done: @escaping (String) -> Void) {
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addTextField { tf in tf.text = text; tf.keyboardType = keyboard; tf.autocorrectionType = .no; tf.autocapitalizationType = .none }
        a.addAction(UIAlertAction(title: "Lưu", style: .default) { [weak self, weak a] _ in
            self?.restoreKey(); done(a?.textFields?.first?.text ?? "")
        })
        a.addAction(cancel())
        present(a)
    }

    // MARK: Menu chính (⚙)

    private func showMenu() {
        let s = sheet("Điều khiển")
        s.addAction(action("Bàn phím ảo (buộc mở)") { GameInput.showKeyboard() })
        s.addAction(action(config.hidden ? "Hiện nút điều khiển" : "Ẩn nút điều khiển") { [weak self] in self?.toggleHidden() })
        s.addAction(action("Chỉnh sửa nút điều khiển") { [weak self] in self?.setEditing(true) })
        s.addAction(action("Tuỳ chỉnh con trỏ…") { [weak self] in self?.cursorMenu() })
        s.addAction(action(config.touchpad ? "Chuyển sang chạm trực tiếp (tắt con trỏ)" : "Chuyển sang điều khiển bằng con trỏ") { [weak self] in
            guard let self = self else { return }
            var c = self.config; c.touchpad.toggle(); self.update(c)
        })
        s.addAction(action("Đóng chương trình", .destructive) { GameInput.quit() })
        s.addAction(cancel())
        present(s)
    }

    private func toggleHidden() {
        var c = config; c.hidden.toggle(); update(c)
    }

    private func setEditing(_ on: Bool) {
        controls.editMode = on
        editBar.isHidden = !on
    }

    // MARK: Con trỏ

    private func cursorMenu() {
        let c = config.cursor
        let s = sheet("Con trỏ chuột")
        let shapes = [("arrow", "Mũi tên"), ("dot", "Chấm"), ("cross", "Chữ thập"), ("ring", "Vòng tròn")]
        s.addAction(action("Kiểu: \(shapes.first { $0.0 == c.shape }?.1 ?? c.shape)…") { [weak self] in self?.pickShape(shapes) })
        s.addAction(action("Kích thước: \(Int(c.size))…") { [weak self] in
            self?.prompt("Kích thước con trỏ", "12–80", text: "\(Int(c.size))", keyboard: .numberPad) { v in
                guard let n = Double(v) else { return }
                self?.mutateCursor { $0.size = min(max(n, 12), 80) }
            }
        })
        s.addAction(action("Màu: \(c.color)…") { [weak self] in self?.pickColor() })
        s.addAction(action("Độ mờ: \(Int(c.opacity * 100))%…") { [weak self] in
            self?.prompt("Độ mờ con trỏ", "10–100 (%)", text: "\(Int(c.opacity * 100))", keyboard: .numberPad) { v in
                guard let n = Double(v) else { return }
                self?.mutateCursor { $0.opacity = min(max(n, 10), 100) / 100 }
            }
        })
        s.addAction(action(String(format: "Tốc độ kéo: %.1fx…", c.speed)) { [weak self] in
            self?.prompt("Tốc độ con trỏ", "0.3–5 (1 = bằng ngón tay)", text: String(format: "%.1f", c.speed), keyboard: .decimalPad) { v in
                guard let n = Double(v.replacingOccurrences(of: ",", with: ".")) else { return }
                self?.mutateCursor { $0.speed = min(max(n, 0.3), 5) }
            }
        })
        s.addAction(cancel())
        present(s)
    }

    private func mutateCursor(_ f: (inout CursorStyle) -> Void) {
        var c = config; f(&c.cursor); update(c)
    }

    private func pickShape(_ shapes: [(String, String)]) {
        let s = sheet("Kiểu con trỏ")
        for (key, name) in shapes { s.addAction(action(name) { [weak self] in self?.mutateCursor { $0.shape = key } }) }
        s.addAction(cancel())
        present(s)
    }

    private func pickColor() {
        let s = sheet("Màu con trỏ")
        let colors = [("Trắng", "#FFFFFF"), ("Đen", "#000000"), ("Đỏ", "#FF3B30"), ("Xanh lá", "#34C759"),
                      ("Xanh dương", "#0A84FF"), ("Vàng", "#FFD60A"), ("Hồng", "#FF2D92"), ("Cam", "#FF9F0A")]
        for (name, hex) in colors { s.addAction(action(name) { [weak self] in self?.mutateCursor { $0.color = hex } }) }
        s.addAction(action("Nhập mã màu…") { [weak self] in
            self?.prompt("Mã màu", "Dạng #RRGGBB", text: self?.config.cursor.color ?? "#FFFFFF") { v in
                if UIColor(hex: v) != nil { self?.mutateCursor { $0.color = v } }
            }
        })
        s.addAction(cancel())
        present(s)
    }

    // MARK: Nút

    private func addButton() {
        var c = config
        c.buttons.append(CtrlButton(label: "Nút", key: "Space", x: 0.5, y: 0.5))
        update(c)
        if let b = c.buttons.last { editButton(b) }
    }

    private func confirmReset() {
        let a = UIAlertController(title: "Đặt lại bố cục nút về mặc định?", message: "Các nút tự thêm sẽ mất.", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Đặt lại", style: .destructive) { [weak self] _ in
            self?.restoreKey()
            guard let self = self else { return }
            var c = self.config; c.buttons = ControlsConfig.defaultButtons; self.update(c)
        })
        a.addAction(cancel())
        present(a)
    }

    private func mutate(_ id: String, _ f: (inout CtrlButton) -> Void) {
        var c = config
        guard let i = c.buttons.firstIndex(where: { $0.id == id }) else { return }
        f(&c.buttons[i])
        update(c)
    }

    private func editButton(_ b: CtrlButton) {
        let s = sheet("Nút “\(b.label)” → \(b.key)")
        s.addAction(action("Đổi nhãn…") { [weak self] in
            self?.prompt("Nhãn nút", nil, text: b.label) { v in self?.mutate(b.id) { $0.label = String(v.prefix(6)) } }
        })
        s.addAction(action("Gán phím / chuột…") { [weak self] in self?.pickKey(b) })
        s.addAction(action("Kích thước: \(Int(b.size))…") { [weak self] in
            self?.prompt("Kích thước nút", "30–140", text: "\(Int(b.size))", keyboard: .numberPad) { v in
                guard let n = Double(v) else { return }
                self?.mutate(b.id) { $0.size = min(max(n, 30), 140) }
            }
        })
        s.addAction(action("Độ mờ: \(Int(b.opacity * 100))%…") { [weak self] in
            self?.prompt("Độ mờ nút", "10–100 (%)", text: "\(Int(b.opacity * 100))", keyboard: .numberPad) { v in
                guard let n = Double(v) else { return }
                self?.mutate(b.id) { $0.opacity = min(max(n, 10), 100) / 100 }
            }
        })
        s.addAction(action(b.toggle ? "Chế độ: bấm giữ nút → chuyển sang bật/tắt" : "Chế độ: bật/tắt → chuyển sang giữ-để-nhấn") { [weak self] in
            self?.mutate(b.id) { $0.toggle.toggle() }
        })
        s.addAction(action(b.square ? "Hình: vuông → tròn" : "Hình: tròn → vuông") { [weak self] in
            self?.mutate(b.id) { $0.square.toggle() }
        })
        s.addAction(action("Xoá nút", .destructive) { [weak self] in
            guard let self = self else { return }
            var c = self.config; c.buttons.removeAll { $0.id == b.id }; self.update(c)
        })
        s.addAction(cancel())
        present(s)
    }

    private func pickKey(_ b: CtrlButton) {
        let s = sheet("Gán phím cho “\(b.label)”")
        for (group, keys) in CtrlKeys.groups {
            s.addAction(action("\(group)…") { [weak self] in
                guard let self = self else { return }
                let g = self.sheet(group)
                for k in keys {
                    g.addAction(self.action(k) { [weak self] in
                        self?.mutate(b.id) {
                            $0.key = k
                            if $0.label == "Nút" || $0.label == b.key { $0.label = String(k.replacingOccurrences(of: "Mouse ", with: "").prefix(6)) }
                        }
                    })
                }
                g.addAction(self.cancel())
                self.present(g)
            })
        }
        s.addAction(cancel())
        present(s)
    }
}

enum CppControlsOverlay {
    private static var window: UIWindow?
    private static var controller: ControlsViewController?

    /// Hiện lớp điều khiển (chỉ nên gọi cho chương trình có GUI). Không làm key window để SDL vẫn nhận bàn phím.
    static func show(project: String) {
        guard window == nil else { return }
        let vc = ControlsViewController(project: project)
        let w = ControlsWindow(frame: UIScreen.main.bounds)
        w.windowLevel = .alert + 2
        w.backgroundColor = .clear
        w.rootViewController = vc
        vc.hostWindow = w
        w.isHidden = false
        window = w
        controller = vc
    }

    static func hide() {
        controller?.teardown()
        window?.isHidden = true
        window = nil
        controller = nil
    }
}
