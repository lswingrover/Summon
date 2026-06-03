import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "s.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            Text("Summon")
                .font(.title.bold())
            Text("Version \(AppVersion.current)")
                .foregroundStyle(.secondary)
            Divider()
            Text("Free, local-first text expander for macOS.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Link("github.com/lswingrover/summon",
                 destination: URL(string: "https://github.com/lswingrover/summon")!)
                .font(.caption)
        }
        .padding(28)
        .frame(width: 280)
    }
}
