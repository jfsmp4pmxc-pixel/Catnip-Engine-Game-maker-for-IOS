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

final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        CatnipPaths.prepare()

        let projects = ProjectListViewController()
        let nav = UINavigationController(rootViewController: projects)
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

    func applicationWillResignActive(_ application: UIApplication) { flush() }
    func applicationDidEnterBackground(_ application: UIApplication) { flush() }
    func applicationWillTerminate(_ application: UIApplication) { flush() }

    private func flush() {
        NotificationCenter.default.post(name: .catnipFlushNow, object: nil)
        SettingsStore.shared.saveNow()
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
