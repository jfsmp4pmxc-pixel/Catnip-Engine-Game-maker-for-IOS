//
//  Catnip Engine: game maker for IOS
//
//  Copyright (C) 2026 jfsmp4pmxc-pixel <ihhjnkk@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <https://www.gnu.org/licenses/>.
//

// MediaViewer.swift
// Trình xem trong editor cho file không phải văn bản: ảnh, video, âm thanh, và hex editor cho mọi file khác.

import UIKit
import AVFoundation
import AVKit
import ImageIO

enum MediaKind {
    case image, video, audio, hex

    static let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tif", "tiff", "ico", "icns", "heic", "heif", "webp", "tga", "dds"]
    static let videoExts: Set<String> = ["mp4", "mov", "m4v", "3gp", "3g2", "avi", "mkv", "webm"]
    static let audioExts: Set<String> = ["mp3", "wav", "m4a", "aac", "caf", "aif", "aiff", "flac", "ogg", "oga", "opus", "wma", "amr"]

    static func detect(_ path: String) -> MediaKind {
        let ext = (path as NSString).pathExtension.lowercased()
        if imageExts.contains(ext) { return .image }
        if videoExts.contains(ext) { return .video }
        if audioExts.contains(ext) { return .audio }
        return .hex
    }
}

/// Khung chứa một trình xem. Editor gắn view này lên vùng soạn thảo.
final class MediaViewerController: UIViewController {
    let url: URL
    private(set) var kind: MediaKind
    private var child: UIViewController?

    init(url: URL, kind: MediaKind) {
        self.url = url
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Appearance.theme.bgColor
        let vc: UIViewController
        switch kind {
        case .image: vc = ImageViewerViewController(url: url)
        case .video: vc = VideoViewerViewController(url: url)
        case .audio: vc = AudioViewerViewController(url: url)
        case .hex:   vc = HexEditorViewController(url: url)
        }
        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: view.topAnchor), vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        vc.didMove(toParent: self)
        child = vc
    }

    /// Dừng phát (video/âm thanh) trước khi gỡ khỏi màn hình.
    func stop() {
        (child as? VideoViewerViewController)?.stop()
        (child as? AudioViewerViewController)?.stop()
    }
}

private func fileSizeText(_ url: URL) -> String {
    let n = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    return ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
}

// MARK: - Ảnh

final class ImageViewerViewController: UIViewController, UIScrollViewDelegate {
    private let url: URL
    private let scroll = UIScrollView()
    private let imageView = UIImageView()
    private let info = UILabel()

    init(url: URL) { self.url = url; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let t = Appearance.theme
        view.backgroundColor = t.bgColor
        scroll.delegate = self
        scroll.minimumZoomScale = 0.05
        scroll.maximumZoomScale = 16
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        imageView.contentMode = .scaleToFill
        scroll.addSubview(imageView)

        info.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        info.textColor = t.mutedColor
        info.textAlignment = .center
        info.numberOfLines = 2
        info.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(info)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: info.topAnchor),
            info.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8), info.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            info.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -6),
        ])
        let dbl = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        dbl.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(dbl)
        load()
    }

    private func load() {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(src) > 0 else {
            info.text = "Không đọc được ảnh này (\(fileSizeText(url)))"
            return
        }
        let count = CGImageSourceGetCount(src)
        var image: UIImage?
        if count > 1 {
            var frames: [UIImage] = []
            var total = 0.0
            for i in 0..<min(count, 300) {
                guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
                frames.append(UIImage(cgImage: cg))
                let props = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
                let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                total += (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            }
            image = UIImage.animatedImage(with: frames, duration: max(total, 0.1))
        } else if let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) {
            image = UIImage(cgImage: cg)
        }
        guard let img = image else { info.text = "Không đọc được ảnh này"; return }
        imageView.image = img
        imageView.frame = CGRect(origin: .zero, size: img.size)
        scroll.contentSize = img.size
        let type = (url.pathExtension).uppercased()
        info.text = "\(url.lastPathComponent)\n\(Int(img.size.width)) × \(Int(img.size.height)) · \(type) · \(fileSizeText(url))" + (count > 1 ? " · \(count) khung" : "")
    }

    private var lastBounds = CGSize.zero

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let img = imageView.image, scroll.bounds.width > 0, img.size.width > 0, img.size.height > 0 else { return }
        if lastBounds != scroll.bounds.size {
            lastBounds = scroll.bounds.size
            let fit = min(scroll.bounds.width / img.size.width, scroll.bounds.height / img.size.height)
            scroll.minimumZoomScale = min(fit, 1)
            scroll.zoomScale = min(fit, 1)
        }
        centerImage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }

    private func centerImage() {
        let b = scroll.bounds.size
        var f = imageView.frame
        f.origin.x = f.width < b.width ? (b.width - f.width) / 2 : 0
        f.origin.y = f.height < b.height ? (b.height - f.height) / 2 : 0
        imageView.frame = f
    }

    @objc private func doubleTapped() {
        if scroll.zoomScale > scroll.minimumZoomScale * 1.01 { scroll.setZoomScale(scroll.minimumZoomScale, animated: true) }
        else { scroll.setZoomScale(min(scroll.maximumZoomScale, max(1, scroll.minimumZoomScale * 3)), animated: true) }
    }
}

// MARK: - Video

final class VideoViewerViewController: UIViewController {
    private let url: URL
    private let player: AVPlayer
    private let playerVC = AVPlayerViewController()

    init(url: URL) {
        self.url = url
        player = AVPlayer(url: url)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        view.backgroundColor = .black
        playerVC.player = player
        playerVC.allowsPictureInPicturePlayback = false
        addChild(playerVC)
        playerVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerVC.view)
        NSLayoutConstraint.activate([
            playerVC.view.topAnchor.constraint(equalTo: view.topAnchor), playerVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            playerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor), playerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        playerVC.didMove(toParent: self)

        let ok = AVURLAsset(url: url).isPlayable
        if !ok {
            let l = UILabel()
            l.text = "iOS không phát được định dạng này (\(url.pathExtension.uppercased()))\n\(url.lastPathComponent) · \(fileSizeText(url))"
            l.numberOfLines = 0
            l.textAlignment = .center
            l.textColor = .white
            l.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(l)
            NSLayoutConstraint.activate([l.centerXAnchor.constraint(equalTo: view.centerXAnchor), l.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                                         l.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16)])
        }
    }

    func stop() { player.pause() }
    deinit { player.pause() }
}

// MARK: - Âm thanh

final class AudioViewerViewController: UIViewController {
    private let url: URL
    private let player: AVPlayer
    private var timeObserver: Any?
    private let titleLabel = UILabel()
    private let infoLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let slider = UISlider()
    private let elapsed = UILabel()
    private let remaining = UILabel()
    private let loopButton = UIButton(type: .system)
    private var loop = false
    private var seeking = false
    private var duration: Double = 0

    init(url: URL) {
        self.url = url
        player = AVPlayer(url: url)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let t = Appearance.theme
        view.backgroundColor = t.bgColor
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let icon = UIImageView(image: UIImage(systemName: "waveform.circle.fill"))
        icon.tintColor = t.accentColor
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 96).isActive = true

        titleLabel.text = url.lastPathComponent
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = t.fgColor
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        infoLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        infoLabel.textColor = t.mutedColor
        infoLabel.textAlignment = .center
        infoLabel.text = "\(url.pathExtension.uppercased()) · \(fileSizeText(url))"

        playButton.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 64)), for: .normal)
        playButton.tintColor = t.accentColor
        playButton.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)
        let back = smallButton("gobackward.10", #selector(skipBack))
        let fwd = smallButton("goforward.10", #selector(skipForward))
        loopButton.setImage(UIImage(systemName: "repeat"), for: .normal)
        loopButton.tintColor = t.mutedColor
        loopButton.addTarget(self, action: #selector(toggleLoop), for: .touchUpInside)
        let controls = UIStackView(arrangedSubviews: [back, playButton, fwd, loopButton])
        controls.axis = .horizontal
        controls.spacing = 28
        controls.alignment = .center

        slider.addTarget(self, action: #selector(seekBegan), for: .touchDown)
        slider.addTarget(self, action: #selector(seekChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(seekEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        for l in [elapsed, remaining] {
            l.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            l.textColor = t.mutedColor
            l.text = "0:00"
        }
        let timeRow = UIStackView(arrangedSubviews: [elapsed, UIView(), remaining])

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, infoLabel, controls, slider, timeRow])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.setCustomSpacing(24, after: infoLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        controls.setContentHuggingPriority(.required, for: .vertical)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            stack.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -48).withPriority(.defaultHigh),
        ])
        controls.alignment = .center
        stack.arrangedSubviews[3].setContentHuggingPriority(.required, for: .horizontal)

        let item = player.currentItem
        let asset = item?.asset
        asset?.loadValuesAsynchronously(forKeys: ["duration", "playable"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, let a = asset else { return }
                if a.isPlayable == false {
                    self.infoLabel.text = "iOS không phát được định dạng này (\(self.url.pathExtension.uppercased()))"
                    self.playButton.isEnabled = false
                }
                let d = CMTimeGetSeconds(a.duration)
                if d.isFinite && d > 0 { self.duration = d; self.slider.maximumValue = Float(d); self.updateTime(0) }
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self, !self.seeking else { return }
            let s = CMTimeGetSeconds(time)
            if s.isFinite { self.slider.value = Float(s); self.updateTime(s) }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didFinish), name: .AVPlayerItemDidPlayToEndTime, object: item)
    }

    private func smallButton(_ symbol: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 28)), for: .normal)
        b.tintColor = Appearance.theme.fgColor
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func fmt(_ s: Double) -> String {
        let n = Int(max(0, s))
        return String(format: "%d:%02d", n / 60, n % 60)
    }

    private func updateTime(_ s: Double) {
        elapsed.text = fmt(s)
        remaining.text = duration > 0 ? "-" + fmt(duration - s) : "--:--"
    }

    private func setPlayingIcon(_ playing: Bool) {
        let name = playing ? "pause.circle.fill" : "play.circle.fill"
        playButton.setImage(UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 64)), for: .normal)
    }

    @objc private func togglePlay() {
        if player.rate > 0 { player.pause(); setPlayingIcon(false) }
        else { player.play(); setPlayingIcon(true) }
    }
    @objc private func skipBack() { seek(by: -10) }
    @objc private func skipForward() { seek(by: 10) }
    private func seek(by d: Double) {
        let cur = CMTimeGetSeconds(player.currentTime())
        let target = max(0, min(duration > 0 ? duration : cur + d, cur + d))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }
    @objc private func toggleLoop() {
        loop.toggle()
        loopButton.tintColor = loop ? Appearance.theme.accentColor : Appearance.theme.mutedColor
    }
    @objc private func seekBegan() { seeking = true }
    @objc private func seekChanged() { updateTime(Double(slider.value)) }
    @objc private func seekEnded() {
        player.seek(to: CMTime(seconds: Double(slider.value), preferredTimescale: 600)) { [weak self] _ in self?.seeking = false }
    }
    @objc private func didFinish() {
        if loop { player.seek(to: .zero); player.play() }
        else { setPlayingIcon(false); player.seek(to: .zero) }
    }

    func stop() { player.pause(); setPlayingIcon(false) }
    deinit {
        if let o = timeObserver { player.removeTimeObserver(o) }
        player.pause()
        NotificationCenter.default.removeObserver(self)
    }
}

private extension NSLayoutConstraint {
    func withPriority(_ p: UILayoutPriority) -> NSLayoutConstraint { priority = p; return self }
}

// MARK: - Hex editor

final class HexEditorViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let url: URL
    private var data = Data()
    private var readOnly = false
    private var truncated = false
    private let table = UITableView(frame: .zero, style: .plain)
    private let info = UILabel()
    private var perRow = 16
    private var highlight: (offset: Int, length: Int)?
    private let maxLoad = 64 * 1024 * 1024
    private let maxEdit = 8 * 1024 * 1024

    init(url: URL) { self.url = url; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let t = Appearance.theme
        view.backgroundColor = t.bgColor

        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
        if size > maxLoad {
            truncated = true
            if let h = try? FileHandle(forReadingFrom: url) { data = h.readData(ofLength: maxLoad); try? h.close() }
        } else {
            data = (try? Data(contentsOf: url)) ?? Data()
        }
        readOnly = truncated || size > maxEdit

        let bar = UIView()
        bar.backgroundColor = t.bg2Color
        bar.translatesAutoresizingMaskIntoConstraints = false
        info.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        info.textColor = t.mutedColor
        info.numberOfLines = 2
        let goto = barButton("Đi tới", #selector(gotoTapped))
        let find = barButton("Tìm", #selector(findTapped))
        let row = UIStackView(arrangedSubviews: [info, UIView(), goto, find])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(row)

        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.backgroundColor = t.bgColor
        table.separatorStyle = .none
        table.register(HexRowCell.self, forCellReuseIdentifier: "hex")
        table.rowHeight = 20
        view.addSubview(bar)
        view.addSubview(table)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.topAnchor), bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            row.topAnchor.constraint(equalTo: bar.topAnchor, constant: 6), row.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 10), row.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -10),
            table.topAnchor.constraint(equalTo: bar.bottomAnchor), table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor), table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        updateInfo()
    }

    private func barButton(_ title: String, _ sel: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.tintColor = Appearance.theme.accentColor
        b.addTarget(self, action: sel, for: .touchUpInside)
        return b
    }

    private func updateInfo() {
        var s = "\(url.lastPathComponent) · \(data.count) byte · \(fileSizeText(url))"
        if truncated { s += " · chỉ hiện 64 MB đầu" }
        s += readOnly ? " · chỉ đọc (>8 MB)" : " · chạm một dòng để sửa"
        info.text = s
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Khoảng "OFFSET(8) + 2 khoảng trắng + n*3 + 1 + n" ký tự: chọn n lớn nhất vừa chiều rộng.
        let charW = ("0" as NSString).size(withAttributes: [.font: HexRowCell.font]).width
        let avail = Int((view.bounds.width - 16) / max(charW, 1))
        var n = (avail - 11) / 4
        n = max(4, min(32, n - n % 4))
        if n != perRow { perRow = n; table.reloadData() }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { (data.count + perRow - 1) / perRow }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "hex", for: indexPath) as! HexRowCell
        let start = indexPath.row * perRow
        let end = min(start + perRow, data.count)
        cell.configure(offset: start, bytes: data[start..<end], perRow: perRow, theme: Appearance.theme,
                       highlight: highlight, selectedRow: indexPath.row)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !readOnly else { toast("File lớn: chỉ xem, không sửa"); return }
        let start = indexPath.row * perRow
        let end = min(start + perRow, data.count)
        let hex = data[start..<end].map { String(format: "%02X", $0) }.joined(separator: " ")
        let a = UIAlertController(title: String(format: "Sửa tại 0x%X", start),
                                  message: "Nhập \(end - start) byte hex (ghi đè, giữ nguyên độ dài).", preferredStyle: .alert)
        a.addTextField { tf in
            tf.text = hex
            tf.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            tf.autocapitalizationType = .allCharacters
            tf.autocorrectionType = .no
        }
        a.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        a.addAction(UIAlertAction(title: "Ghi", style: .default) { [weak self, weak a] _ in
            guard let self = self, let text = a?.textFields?.first?.text else { return }
            guard let bytes = Self.parseHex(text), bytes.count == end - start else {
                self.toast("Cần đúng \(end - start) byte hex"); return
            }
            self.data.replaceSubrange(start..<end, with: bytes)
            self.save()
            self.table.reloadRows(at: [indexPath], with: .none)
        })
        present(a, animated: true)
    }

    private func save() {
        do { try data.write(to: url, options: .atomic); updateInfo() }
        catch { toast("Lỗi ghi: \(error.localizedDescription)") }
    }

    private func toast(_ s: String) {
        let a = UIAlertController(title: nil, message: s, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    static func parseHex(_ s: String) -> [UInt8]? {
        let digits = s.filter { !$0.isWhitespace && $0 != "," }.replacingOccurrences(of: "0x", with: "")
        guard !digits.isEmpty, digits.count % 2 == 0, digits.allSatisfy({ $0.isHexDigit }) else { return nil }
        var out: [UInt8] = []
        var i = digits.startIndex
        while i < digits.endIndex {
            let j = digits.index(i, offsetBy: 2)
            guard let b = UInt8(digits[i..<j], radix: 16) else { return nil }
            out.append(b)
            i = j
        }
        return out
    }

    @objc private func gotoTapped() {
        let a = UIAlertController(title: "Đi tới offset", message: "Số thập phân hoặc hex (0x...).", preferredStyle: .alert)
        a.addTextField { $0.placeholder = "0x100 hoặc 256"; $0.autocorrectionType = .no }
        a.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        a.addAction(UIAlertAction(title: "Đi", style: .default) { [weak self, weak a] _ in
            guard let self = self, var t = a?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) else { return }
            var off: Int?
            if t.lowercased().hasPrefix("0x") { t.removeFirst(2); off = Int(t, radix: 16) } else { off = Int(t) }
            guard let o = off, o >= 0, o < self.data.count else { self.toast("Offset ngoài file (0..\(max(0, self.data.count - 1)))"); return }
            self.highlight = (o, 1)
            self.scrollTo(o)
        })
        present(a, animated: true)
    }

    @objc private func findTapped() {
        let a = UIAlertController(title: "Tìm", message: "Chuỗi hex (vd 48 65 6C) hoặc văn bản.", preferredStyle: .alert)
        a.addTextField { $0.placeholder = "48 65 6C hoặc Hello"; $0.autocorrectionType = .no; $0.autocapitalizationType = .none }
        a.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        a.addAction(UIAlertAction(title: "Tìm", style: .default) { [weak self, weak a] _ in
            guard let self = self, let text = a?.textFields?.first?.text, !text.isEmpty else { return }
            let needle: Data
            if let b = Self.parseHex(text), text.contains(where: { $0 == " " }) || text.lowercased().hasPrefix("0x") { needle = Data(b) }
            else if let b = Self.parseHex(text), text.count >= 4 { needle = Data(b) }
            else { needle = Data(text.utf8) }
            let from = max(0, (self.table.indexPathsForVisibleRows?.first?.row ?? 0) * self.perRow + 1)
            var r = self.data.range(of: needle, options: [], in: min(from, self.data.count)..<self.data.count)
            if r == nil { r = self.data.range(of: needle) }
            guard let found = r else { self.toast("Không thấy"); return }
            self.highlight = (found.lowerBound, needle.count)
            self.scrollTo(found.lowerBound)
        })
        present(a, animated: true)
    }

    private func scrollTo(_ offset: Int) {
        table.reloadData()
        let row = offset / perRow
        table.scrollToRow(at: IndexPath(row: row, section: 0), at: .middle, animated: true)
    }
}

final class HexRowCell: UITableViewCell {
    static let font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        label.font = HexRowCell.font
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(offset: Int, bytes: Data, perRow: Int, theme: Theme, highlight: (offset: Int, length: Int)?, selectedRow: Int) {
        backgroundColor = theme.bgColor
        let out = NSMutableAttributedString()
        func add(_ s: String, _ c: UIColor) { out.append(NSAttributedString(string: s, attributes: [.foregroundColor: c, .font: HexRowCell.font])) }
        add(String(format: "%08X", offset), theme.tokenColor(.comment))
        add("  ", theme.fgColor)
        for i in 0..<perRow {
            if i < bytes.count {
                let b = bytes[bytes.startIndex + i]
                let hl = highlight.map { offset + i >= $0.offset && offset + i < $0.offset + $0.length } ?? false
                let color: UIColor = hl ? theme.accentColor : (b == 0 ? theme.mutedColor : theme.fgColor)
                let s = NSMutableAttributedString(string: String(format: "%02X ", b), attributes: [.foregroundColor: color, .font: HexRowCell.font])
                if hl { s.addAttribute(.backgroundColor, value: theme.hoverColor, range: NSRange(location: 0, length: 2)) }
                out.append(s)
            } else { add("   ", theme.fgColor) }
        }
        add(" ", theme.fgColor)
        var ascii = ""
        for b in bytes { ascii.append((b >= 32 && b < 127) ? Character(UnicodeScalar(b)) : ".") }
        add(ascii, theme.tokenColor(.string))
        label.attributedText = out
    }
}
