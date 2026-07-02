//
//  NotesBoardView.swift — Screen 14: Structured Notes
//
//  Notes are cards with a zone, group, tag and date — not just free text — so
//  context is easy to find later. Filter by tag, full create/edit/delete.
//

import SwiftUI

struct NotesBoardView: View {
    @EnvironmentObject var store: FarmStore
    @State private var tagFilter: String?
    @State private var editing: FarmNote?
    @State private var showNew = false
    @State private var toast: Toast?

    private var tags: [String] {
        Array(Set(store.notes.map { $0.tag }.filter { !$0.isEmpty })).sorted()
    }
    private var visible: [FarmNote] {
        guard let t = tagFilter else { return store.notes }
        return store.notes.filter { $0.tag == t }
    }

    var body: some View {
        DetailScaffold(title: "Structured Notes", trailingIcon: "plus", trailingAction: { showNew = true }) {
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        SelectChip(text: "All", selected: tagFilter == nil) { tagFilter = nil }
                        ForEach(tags, id: \.self) { t in
                            SelectChip(text: "#\(t)", selected: tagFilter == t, tint: Theme.wood) {
                                tagFilter = tagFilter == t ? nil : t
                            }
                        }
                    }
                }
            }

            SecondaryButton(title: "Add Note", icon: "square.and.pencil") { showNew = true }

            if visible.isEmpty {
                RoostCard { EmptyState(symbol: "note.text", title: "No notes yet",
                                       message: "Capture supplier tips, ideas and reminders with context.") }
            } else {
                ForEach(visible) { note in noteCard(note) }
            }
        }
        .sheet(isPresented: $showNew) {
            NoteEditorView(note: nil) { toast = Toast(message: "Note added") }.environmentObject(store)
        }
        .sheet(item: $editing) { n in
            NoteEditorView(note: n) { toast = Toast(message: "Note saved") }.environmentObject(store)
        }
        .toast($toast)
    }

    private func noteCard(_ note: FarmNote) -> some View {
        RoostCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(note.title).font(.roost(16, .bold)).foregroundColor(Theme.textPrimary)
                    Spacer()
                    Menu {
                        Button { editing = note } label: { Label("Edit", systemImage: "pencil") }
                        Button { store.deleteNote(note) } label: { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis").foregroundColor(Theme.textSecondary).frame(width: 28, height: 28)
                    }
                }
                if !note.body.isEmpty {
                    Text(note.body).font(.roostBody).foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    if !note.tag.isEmpty { TagChip(text: "#\(note.tag)", tint: Theme.wood) }
                    if note.zoneID != nil { TagChip(text: store.zoneName(note.zoneID), symbol: "mappin", tint: Theme.info) }
                    if note.groupID != nil { TagChip(text: store.groupName(note.groupID), symbol: "oval.fill", tint: Theme.amberDeep) }
                    Spacer()
                    Text(FarmStore.shortDate(note.date)).font(.roost(11, .medium)).foregroundColor(Theme.textFaint)
                }
            }
        }
    }
}

// MARK: - Note editor

struct NoteEditorView: View {
    @EnvironmentObject var store: FarmStore
    @Environment(\.presentationMode) var presentationMode
    var note: FarmNote?
    var onSave: () -> Void

    @State private var title = ""
    @State private var body_ = ""
    @State private var tag = ""
    @State private var zoneID: UUID?
    @State private var groupID: UUID?

    var body: some View {
        SheetScaffold(title: note == nil ? "Add Note" : "Edit Note",
                      saveEnabled: !title.trimmingCharacters(in: .whitespaces).isEmpty,
                      onSave: save, onClose: { presentationMode.wrappedValue.dismiss() }) {
            RoostField(title: "Title", placeholder: "Note title", text: $title, icon: "note.text")

            VStack(alignment: .leading, spacing: 6) {
                Text("BODY").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
                TextEditor(text: $body_).frame(height: 110).padding(8)
                    .background(RoundedRectangle(cornerRadius: Metric.radiusSmall).fill(Theme.background))
                    .overlay(RoundedRectangle(cornerRadius: Metric.radiusSmall).stroke(Theme.stroke, lineWidth: 1))
            }

            RoostField(title: "Tag", placeholder: "e.g. repair, supply", text: $tag, icon: "number")

            Text("LINK TO ZONE").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: zoneID == nil) { zoneID = nil }
                    ForEach(store.sortedZones) { z in
                        SelectChip(text: z.name, symbol: z.kind.symbol, selected: zoneID == z.id) { zoneID = z.id }
                    }
                }
            }

            Text("LINK TO GROUP").font(.roost(11, .bold)).foregroundColor(Theme.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SelectChip(text: "None", selected: groupID == nil) { groupID = nil }
                    ForEach(store.groups) { g in
                        SelectChip(text: g.name, symbol: g.type.symbol, selected: groupID == g.id, tint: g.color) { groupID = g.id }
                    }
                }
            }
        }
        .onAppear {
            if let n = note { title = n.title; body_ = n.body; tag = n.tag; zoneID = n.zoneID; groupID = n.groupID }
        }
    }
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let cleanTag = tag.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        if var n = note {
            n.title = trimmed; n.body = body_; n.tag = cleanTag; n.zoneID = zoneID; n.groupID = groupID
            store.updateNote(n)
        } else {
            store.addNote(FarmNote(title: trimmed, body: body_, tag: cleanTag, zoneID: zoneID, groupID: groupID))
        }
        onSave()
        presentationMode.wrappedValue.dismiss()
    }
}
