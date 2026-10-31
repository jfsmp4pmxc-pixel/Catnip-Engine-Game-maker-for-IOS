// main.swift
// Catnip — điểm vào của app.
// Vì file tên `main.swift`, ta dùng top-level code thay cho @main / @UIApplicationMain.

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
