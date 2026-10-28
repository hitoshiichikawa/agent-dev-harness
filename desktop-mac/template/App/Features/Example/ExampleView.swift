import Domain
import SwiftUI

/// View は ViewModel を観察するだけ。@State は UI 状態のみ。
struct ExampleView: View {
    @State var viewModel: ExampleViewModel
    @State private var selection: Example.ID?

    var body: some View {
        NavigationSplitView {
            List(viewModel.items, selection: $selection) { item in
                Text(item.name)
                    .contextMenu {
                        Button("Delete", role: .destructive) { Task { await viewModel.remove(item) } }
                    }
            }
            .navigationTitle("Examples")
            .overlay { if viewModel.isLoading { ProgressView() } }
            .toolbar {
                ToolbarItem {
                    TextField("New name", text: $viewModel.draftName)
                        .frame(width: 160)
                        .onSubmit { Task { await viewModel.add() } }
                }
            }
        } detail: {
            if let id = selection, let item = viewModel.items.first(where: { $0.id == id }) {
                VStack(alignment: .leading) {
                    Text(item.name).font(.title)
                    Text(item.createdAt, style: .date).foregroundStyle(.secondary)
                }
                .padding()
            } else {
                ContentUnavailableView("Select an item", systemImage: "sidebar.left")
            }
        }
        .task { await viewModel.load() }
        .alert("Error", isPresented: Binding(get: { viewModel.error != nil }, set: { if !$0 { viewModel.error = nil } })) {
            Button("OK") {}
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}
