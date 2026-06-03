import SwiftUI
import SummonCore

struct SnippetEditorView: View {
    let store: SnippetStore
    let existing: Snippet?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var trigger   = ""
    @State private var expansion = ""
    @State private var label     = ""
    @State private var enabled   = true
    @State private var errorMsg  = ""
    @State private var saving    = false

    var isEditing: Bool { existing != nil }

    var canSave: Bool {
        !trigger.trimmingCharacters(in: .whitespaces).isEmpty &&
        !expansion.trimmingCharacters(in: .whitespaces).isEmpty &&
        !saving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isEditing ? "Edit Snippet" : "New Snippet")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 4) {
                Text("TRIGGER").font(.caption).foregroundStyle(.tertiary)
                TextField("e.g. ;addr or !email", text: $trigger)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                Text("The short text you type to trigger the expansion.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("EXPANSION").font(.caption).foregroundStyle(.tertiary)
                TextEditor(text: $expansion)
                    .font(.body)
                    .frame(minHeight: 100, maxHeight: 300)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator, lineWidth: 1))
                Text("The full text that replaces the trigger.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("LABEL (OPTIONAL)").font(.caption).foregroundStyle(.tertiary)
                TextField("e.g. Home address, Signature", text: $label)
                    .textFieldStyle(.roundedBorder)
            }

            Toggle("Enabled", isOn: $enabled)

            if !errorMsg.isEmpty {
                Text(errorMsg)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save Changes" : "Add Snippet", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480, alignment: .leading)
        .onAppear { populate() }
    }

    private func populate() {
        guard let s = existing else { return }
        trigger   = s.trigger
        expansion = s.expansion
        label     = s.label
        enabled   = s.enabled
    }

    private func save() {
        let t = trigger.trimmingCharacters(in: .whitespaces)
        let e = expansion.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !e.isEmpty else { return }
        saving = true
        errorMsg = ""

        Task {
            do {
                if let existing {
                    var updated       = existing
                    updated.trigger   = t
                    updated.expansion = e
                    updated.label     = label
                    updated.enabled   = enabled
                    try await store.update(updated)
                } else {
                    try await store.add(Snippet(trigger: t, expansion: e, label: label, enabled: enabled))
                }
                onSave()
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    errorMsg = error.localizedDescription
                    saving   = false
                }
            }
        }
    }
}
