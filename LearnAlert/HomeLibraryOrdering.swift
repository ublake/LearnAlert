import SwiftUI
import UniformTypeIdentifiers

private struct HomeLibraryDropDelegate: DropDelegate {
    let id: String
    @Binding var dragging: String?
    let accepts: (String) -> Bool
    let move: (String, String) -> Void

    func validateDrop(info: DropInfo) -> Bool { dragging.map(accepts) ?? false }
    func dropEntered(info: DropInfo) {
        guard let source = dragging, source != id, accepts(source) else { return }
        withAnimation(.snappy) { move(source, id) }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: validateDrop(info: info) ? .move : .forbidden)
    }
    func performDrop(info: DropInfo) -> Bool {
        let accepted = validateDrop(info: info)
        dragging = nil
        return accepted
    }
}

struct HomeLibraryDragModifier: ViewModifier {
    static let contentType = UTType(exportedAs: "com.learnalert.library-order")
    let id: String
    let enabled: Bool
    @Binding var dragging: String?
    let accepts: (String) -> Bool
    let move: (String, String) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    dragging = id
                    let provider = NSItemProvider()
                    provider.registerDataRepresentation(forTypeIdentifier: Self.contentType.identifier, visibility: .ownProcess) { complete in
                        complete(Data(id.utf8), nil); return nil
                    }
                    return provider
                }
                .onDrop(of: [Self.contentType], delegate: HomeLibraryDropDelegate(id: id, dragging: $dragging, accepts: accepts, move: move))
        } else { content }
    }
}
