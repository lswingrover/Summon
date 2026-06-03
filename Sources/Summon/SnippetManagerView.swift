import SwiftUI
import SummonCore

struct SnippetManagerView: View {
    let store: SnippetStore

    @State private var snippets: [Snippet] = []
    @State private var selected: UUID?
    @State private var showEditor = false
    @State private var editTarget: Snippet?
    @State private var searchText = ""

    var filtered: [Snippet] {
        guard !searchText.isEmpty else { return snippets }
        let q = searchText.lowercased()
        return snippets.filter {
            $0.trigger.lowercased().contains(q) ||
            $0.expansion.lowercased().contains(q) ||
            $0.label.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filtered, selection: $selected) { snippet in
                SnippetRowView(snippet: snippet)
                    .tag(snippet.id)
                    .contextMenu {
                        Button("Edit")   { beginEdit(snippet) }
                        Divider()
                        Button("Delete", role: .destructive) { delete(snippet) }
                    }
            }
            .searchable(text: $searchText, prompt: "Search snippets…")
            .navigationTitle("Snippets (\(snippets.count))")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: beginAdd) {
                        Label("Add Snippet", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let id = selected, let snippet = snippets.first(where: { $0.id == id }) {
                SnippetDetailView(snippet: snippet, onEdit: { beginEdit(snippet) })
            } else {
                ContentUnavailableView("No Snippet Selected",
                    systemImage: "text.cursor",
                    description: Text("Select a snippet from the list, or add a new one."))
            }
        }
        .frame(minWidth: 620, minHeight: 400)
        .sheet(isPresented: $showEditor) {
            SnippetEditorView(store: store, existing: editTarget) { refresh() }
        }
        .onAppear { refresh() }
    }

    private func refresh() {
        Task {
            let all = await store.snippets
            await MainActor.run { snippets = all }
        }
    }

    private func beginAdd()          { editTarget = nil; showEditor = true }
    private func beginEdit(_ s: Snippet) { editTarget = s; showEditor = true }

    private func delete(_ s: Snippet) {
        Task {
            try? await store.delete(id: s.id)
            await MainActor.run {
                if selected == s.id { selected = nil }
            }
            refresh()
        }
    }
}

struct SnippetRowView: View {
    let snippet: Snippet
    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.trigger)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(snippet.enabled ? .primary : .secondary)
                if !snippet.label.isEmpty {
                    Text(snippet.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !snippet.enabled {
                Text("disabled")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .opacity(snippet.enabled ? 1.0 : 0.55)
    }
}

struct SnippetDetailView: View {
    let snippet: Snippet
    let onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(snippet.trigger, systemImage: "bolt.fill")
                            .font(.title2.monospaced().bold())
                        if !snippet.label.isEmpty {
                            Text(snippet.label).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Edit", action: onEdit).buttonStyle(.borderedProminent)
                }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("EXPANSION").font(.caption).foregroundStyle(.tertiary)
                    Text(snippet.expansion)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(24)
        }
    }
}
