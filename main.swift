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

import UIKit

extension Notification.Name {
    /// Phát khi app sắp xuống nền / thoát, để editor ghi file đang mở xuống đĩa.
    static let catnipFlushNow = Notification.Name("catnip.flushNow")
}

/// Một nơi duy nhất quyết định app được xoay những hướng nào, để màn hình và bàn phím luôn cùng hướng.
enum OrientationPolicy {
    /// Khi game LÖVE đang chạy, để game tự quyết định hướng của nó (SDL).
    static var gameRunning = false

    static var mask: UIInterfaceOrientationMask {
        if gameRunning { return .all }
        if SettingsStore.shared.settings.lockPortrait { return .portrait }
        return UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    /// Yêu cầu hệ thống tính lại hướng theo thiết bị. Gọi sau khi game thoát hoặc khi đổi cài đặt.
    static func refresh() {
        if #available(iOS 16.0, *) {
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
            }
        }
        UIViewController.attemptRotationToDeviceOrientation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}

/// Navigation controller của Catnip: hướng xoay lấy từ OrientationPolicy thay vì mặc định.
final class CatnipNavigationController: UINavigationController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { OrientationPolicy.mask }
    override var shouldAutorotate: Bool { true }
}

final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        CatnipPaths.prepare()

        let projects = ProjectListViewController()
        let nav = CatnipNavigationController(rootViewController: projects)
        nav.navigationBar.prefersLargeTitles = true

        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = nav
        w.makeKeyAndVisible()
        window = w

        // Mở lại dự án đang làm dở lần trước (nếu còn).
        let s = SettingsStore.shared.settings
        if let name = s.lastProject, ProjectStore.shared.listProjects().contains(name) {
            nav.pushViewController(EditorViewController(project: name), animated: false)
        }
        return true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationPolicy.mask
    }

    func applicationDidBecomeActive(_ application: UIApplication) { OrientationPolicy.refresh() }
    func applicationWillResignActive(_ application: UIApplication) { flush() }
    func applicationDidEnterBackground(_ application: UIApplication) { flush() }
    func applicationWillTerminate(_ application: UIApplication) { flush() }

    private func flush() {
        NotificationCenter.default.post(name: .catnipFlushNow, object: nil)
        SettingsStore.shared.saveNow()
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
