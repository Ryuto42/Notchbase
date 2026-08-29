import SwiftUI

struct TerminalPane: View {
    var body: some View {
        TerminalHostView()
            .padding(6)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.5)
            }
            .padding(.horizontal, 11)
            .padding(.top, 3)
            .padding(.bottom, 11)
    }
}
