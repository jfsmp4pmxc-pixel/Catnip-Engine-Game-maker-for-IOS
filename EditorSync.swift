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

// EditorSync.swift
// Hai việc của editor liên quan tới "bên ngoài":
//  1. Sửa file trực tiếp bằng ứng dụng Tệp (hoặc shell iSH) mà không gây lỗi: editor tự phát hiện thay đổi,
//     làm mới cây file, nạp lại file đang mở nếu chưa sửa gì, và hỏi trước khi ghi đè nếu hai bên cùng sửa.
//  2. Nút Build: hiện tại xuất dự án thành file .zip; kết nối GitHub sẽ có sau.

import UIKit

private extension UIViewController {
    /// View controller trên cùng đang hiện (để trình bày hộp thoại cả khi Cài đặt/Docs đang mở).
    var topPresenter: UIViewController {
        var vc = self
        while let next = vc.presentedViewController, !next.isBeingDismissed { vc = next }
        return vc
    }
}

extension EditorViewController {

    // MARK: Theo dõi thay đổi bên ngoài

    func startWatchingExternalChanges() {
        stopWatchingExternalChanges()
        lastSignature = store.signature(project: project)
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.checkExternalChanges() }
        RunLoop.main.add(timer, forMode: .common)
        watchTimer = timer
        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        checkExternalChanges()
    }

    func stopWatchingExternalChanges() {
        watchTimer?.invalidate()
        watchTimer = nil
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func appBecameActive() {
        lastSignature = 0          // sau khi quay lại app, luôn kiểm tra lại
        checkExternalChanges()
    }

    @objc func checkExternalChanges() {
        guard isViewLoaded, view.window != nil, !isGameRunning,
              UIApplication.shared.applicationState == .active else { return }

        // Cả thư mục dự án bị xoá hoặc đổi tên bên ngoài.
        guard store.projectExists(project) else {
            handleProjectGone()
            return
        }

        // Quét thư mục ở luồng nền để không làm khựng giao diện với dự án lớn.
        let project = self.project
        let store = self.store
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let sig = store.signature(project: project)
            DispatchQueue.main.async { self?.applyExternalChanges(signature: sig) }
        }
    }

    private func applyExternalChanges(signature sig: Int) {
        guard sig != lastSignature, view.window != nil, !isGameRunning else { return }
        // Đang gõ dở (Telex/VNI): kiểm tra lại ở lần sau.
        guard textView.markedTextRange == nil else { return }
        lastSignature = sig

        reloadTree()

        guard let path = currentPath, canEdit else { return }

        guard store.fileExists(project: project, path: path) else {
            if isDirty {
                flash("⚠️ \(path) đã bị xoá bên ngoài, lưu để tạo lại")
            } else {
                showNoFile()
                flash("⚠️ \(path) đã bị xoá hoặc đổi tên bên ngoài")
            }
            return
        }

        guard let disk = store.read(project: project, path: path), disk != baselineText else {
            baselineDate = store.modificationDate(project: project, path: path)
            return
        }
        if isDirty {
            promptConflict(path)
        } else {
            reloadFromDisk(path)
            flash("↻ \(path) vừa được cập nhật từ bên ngoài")
        }
    }

    private func handleProjectGone() {
        guard !projectGoneShowing else { return }
        projectGoneShowing = true
        stopWatchingExternalChanges()
        let ac = UIAlertController(title: "Dự án không còn",
                                   message: "Thư mục \"\(project)\" đã bị xoá hoặc đổi tên bên ngoài ứng dụng.",
                                   preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Về danh sách dự án", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.isDirty = false          // không ghi lại file vào thư mục đã mất
            self.navigationController?.popToRootViewController(animated: true)
        })
        topPresenter.present(ac, animated: true)
    }

    // MARK: Nạp lại / xung đột

    /// Có phải file trên đĩa đã khác với lần đọc/ghi gần nhất của editor không (tức bị sửa ngoài)?
    func hasExternalConflict(_ path: String) -> Bool {
        guard let base = baselineText else { return false }
        let date = store.modificationDate(project: project, path: path)
        guard date != baselineDate else { return false }
        guard let disk = store.read(project: project, path: path) else { return false }   // file đã mất: cứ ghi lại
        if disk == base {
            baselineDate = date              // chỉ đổi ngày sửa, nội dung vẫn vậy
            return false
        }
        return true
    }

    func promptConflict(_ path: String) {
        guard !conflictShowing, UIApplication.shared.applicationState == .active else { return }
        conflictShowing = true
        let ac = UIAlertController(
            title: "File đã bị sửa bên ngoài",
            message: "\"\(path)\" vừa được thay đổi ở nơi khác (ứng dụng Tệp hoặc shell), trong khi bạn cũng đang sửa. Giữ bản nào?",
            preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Giữ bản đang soạn", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.conflictShowing = false
            // Coi bản trên đĩa là nền mới để lần lưu sau ghi đè.
            self.baselineText = self.store.read(project: self.project, path: path)
            self.baselineDate = self.store.modificationDate(project: self.project, path: path)
            self.flushSave()
        })
        ac.addAction(UIAlertAction(title: "Dùng bản trên đĩa", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.conflictShowing = false
            self.reloadFromDisk(path)
            self.flash("↻ Đã nạp lại \(path) từ đĩa")
        })
        topPresenter.present(ac, animated: true)
    }

    /// Nạp lại nội dung file đang mở từ đĩa, giữ vị trí con trỏ và vị trí cuộn gần đúng.
    func reloadFromDisk(_ path: String) {
        guard path == currentPath, let text = store.read(project: project, path: path) else { return }
        let selection = textView.selectedRange
        let offset = textView.contentOffset
        textView.text = text
        baselineText = text
        baselineDate = store.modificationDate(project: project, path: path)
        isDirty = false
        let length = (text as NSString).length
        let loc = min(selection.location, length)
        textView.selectedRange = NSRange(location: loc, length: min(selection.length, length - loc))
        textView.setContentOffset(offset, animated: false)
        textView.undoManager?.removeAllActions()
        refreshGutter()
        rehighlightNow()
        updateTitle()
        updateStatus()
    }

    // MARK: Nút Build

    /// Menu của nút Build. Hiện tại: xuất .zip. Kết nối GitHub sẽ được thêm sau.
    func makeBuildMenu() -> UIMenu {
        let zip = UIAction(title: "Xuất dự án (.zip)", image: UIImage(systemName: "doc.zipper")) { [weak self] _ in
            self?.exportProjectZip()
        }
        let github = UIAction(title: "Kết nối GitHub (sắp ra mắt)",
                              image: UIImage(systemName: "arrow.triangle.branch"),
                              attributes: .disabled) { _ in }
        return UIMenu(title: "Build", children: [zip, github])
    }

    /// Nén cả thư mục dự án thành <tên dự án>.zip rồi mở bảng chia sẻ (Lưu vào Tệp, AirDrop…).
    func exportProjectZip() {
        textView.resignFirstResponder()
        guard flushSave() else { return }

        var coordinationError: NSError?
        var exported: URL?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: store.projectURL(project), options: [.forUploading],
                                       error: &coordinationError) { zipURL in
            // File zip do hệ thống tạo chỉ tồn tại trong khối này: sao chép ra thư mục tạm.
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("catnip-export-\(UUID().uuidString)", isDirectory: true)
            let dst = dir.appendingPathComponent(project + ".zip")
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: zipURL, to: dst)
                exported = dst
            } catch {
                copyError = error
            }
        }

        guard let file = exported else {
            let reason = (coordinationError ?? copyError)?.localizedDescription ?? "lỗi không rõ"
            flash("⚠️ Không xuất được .zip: \(reason)")
            return
        }

        let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        share.popoverPresentationController?.barButtonItem = buildItem
        share.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
        }
        present(share, animated: true)
    }
}
