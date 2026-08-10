import AppKit

@main
struct PastyMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppController.shared
        app.delegate = delegate
        app.run()
    }
}
