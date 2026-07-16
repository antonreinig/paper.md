import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            Text("Documents are saved automatically while you type. paper.md does not send document content over the network.")
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 460)
    }
}
