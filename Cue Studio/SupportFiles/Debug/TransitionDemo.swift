//
//  TransitionDemo.swift
//  Cue Studio
//

#if DEBUG
import SwiftUI

/// Debug only: the star transition over a mock Scripts (the dock at the bottom), in a box, for `DesignCatalogueView`.
struct TransitionDemo: View {
    let run: Int
    let ready: Int

    @State private var transition = IdeaTransitionService()

    var body: some View {
        ZStack {
            Palette.bg
            VStack(alignment: .leading, spacing: 10) {
                Text("Scripts").font(.largeTitle.bold()).foregroundStyle(Palette.ink)
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface).frame(height: 64)
                }
                Spacer()
                Text("3 things I stopped buying this year").padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .dockSurface().foregroundStyle(Palette.ink)
            }
            .padding(16)
            .scaleEffect(dims ? 0.94 : 1, anchor: UnitPoint(x: 0.5, y: 0.4))
            .brightness(dims ? -0.4 : 0)
            .saturation(dims ? 0.7 : 1)
            .blur(radius: dims ? 10 : 0)
            .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: IdeaTransitionService.riseDuration), value: dims)
            StarTransitionOverlay(transition: transition)
        }
        .onAppear {
            transition.begin(
                from: CGPoint(x: 330, y: 560), idea: "3 things I stopped buying this year", platformName: "TikTok", abort: {}, arrive: {}
            )
        }
        .onChange(of: ready) { Task { await transition.contentReady() } }
    }

    private var dims: Bool { transition.phase == .rising || transition.phase == .waiting }
}
#endif
