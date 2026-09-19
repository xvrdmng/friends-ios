import SwiftUI

/// Fondo crema con garabatos pastel a medio salir de la pantalla: sol, nube,
/// corazon, flor y una carita triste. Formas de SwiftUI, sin assets.
struct DoodleBackground: View {
    private struct Placement: Identifiable {
        let id: Int
        let kind: Doodle.Kind
        let x: CGFloat, y: CGFloat   // fraccion del lienzo
        let size: CGFloat
        let angle: Double
        let fill: Color
    }

    private let items: [Placement] = [
        .init(id: 0, kind: .face,   x: 0.0,  y: 0.13, size: 90, angle: -8,  fill: Color(hex: "#F1ECE6")),
        .init(id: 1, kind: .sun,    x: 0.93, y: 0.04, size: 100, angle: 0,  fill: Color(hex: "#FFF0A8")),
        .init(id: 2, kind: .cloud,  x: 0.96, y: 0.40, size: 130, angle: 0,  fill: Color(hex: "#D6E6E6")),
        .init(id: 3, kind: .dot,    x: 0.02, y: 0.55, size: 64, angle: 0,   fill: Color(hex: "#F1ECE6")),
        .init(id: 4, kind: .heart,  x: 0.92, y: 0.80, size: 70, angle: 12,  fill: Color(hex: "#F8D3E6")),
        .init(id: 5, kind: .flower, x: 0.08, y: 0.86, size: 64, angle: -10, fill: Color(hex: "#F8D3E6")),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.appBackground
                ForEach(items) { item in
                    Doodle(kind: item.kind)
                        .fill(item.fill)
                        .overlay(
                            Doodle(kind: item.kind)
                                .stroke(Color.black.opacity(0.35),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        )
                        .frame(width: item.size, height: item.size)
                        .rotationEffect(.degrees(item.angle))
                        .position(x: geo.size.width * item.x, y: geo.size.height * item.y)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct Doodle: Shape {
    enum Kind { case heart, sun, face, flower, cloud, dot }
    let kind: Kind

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()

        switch kind {
        case .heart:
            p.move(to: CGPoint(x: c.x, y: rect.maxY - h * 0.08))
            p.addCurve(to: CGPoint(x: rect.minX + w * 0.04, y: rect.minY + h * 0.34),
                       control1: CGPoint(x: c.x - w * 0.15, y: rect.maxY - h * 0.25),
                       control2: CGPoint(x: rect.minX - w * 0.06, y: rect.minY + h * 0.58))
            p.addCurve(to: CGPoint(x: c.x, y: rect.minY + h * 0.26),
                       control1: CGPoint(x: rect.minX + w * 0.08, y: rect.minY - h * 0.06),
                       control2: CGPoint(x: c.x - w * 0.02, y: rect.minY + h * 0.02))
            p.addCurve(to: CGPoint(x: rect.maxX - w * 0.04, y: rect.minY + h * 0.34),
                       control1: CGPoint(x: c.x + w * 0.02, y: rect.minY + h * 0.02),
                       control2: CGPoint(x: rect.maxX - w * 0.08, y: rect.minY - h * 0.06))
            p.addCurve(to: CGPoint(x: c.x, y: rect.maxY - h * 0.08),
                       control1: CGPoint(x: rect.maxX + w * 0.06, y: rect.minY + h * 0.58),
                       control2: CGPoint(x: c.x + w * 0.15, y: rect.maxY - h * 0.25))
        case .sun:
            let r = min(w, h) * 0.3
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            for i in 0..<8 {
                let a = Double(i) * .pi / 4
                let inner = min(w, h) * 0.38, outer = min(w, h) * 0.5
                p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * inner, y: c.y + CGFloat(sin(a)) * inner))
                p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * outer, y: c.y + CGFloat(sin(a)) * outer))
            }
        case .face:
            p.addEllipse(in: rect.insetBy(dx: w * 0.04, dy: h * 0.04))
            let eye = w * 0.04
            for dx in [-0.16, 0.16] {
                p.addEllipse(in: CGRect(x: c.x + w * CGFloat(dx) - eye, y: c.y - h * 0.08 - eye,
                                        width: eye * 2, height: eye * 2))
            }
            p.move(to: CGPoint(x: c.x - w * 0.2, y: c.y + h * 0.26))
            p.addQuadCurve(to: CGPoint(x: c.x + w * 0.2, y: c.y + h * 0.26),
                           control: CGPoint(x: c.x, y: c.y + h * 0.1))
        case .flower:
            let petal = min(w, h) * 0.2
            for i in 0..<6 {
                let a = Double(i) * .pi / 3
                let pc = CGPoint(x: c.x + CGFloat(cos(a)) * petal * 1.35, y: c.y + CGFloat(sin(a)) * petal * 1.35)
                p.addEllipse(in: CGRect(x: pc.x - petal, y: pc.y - petal, width: petal * 2, height: petal * 2))
            }
        case .cloud:
            p.addRoundedRect(in: CGRect(x: rect.minX, y: c.y, width: w, height: h * 0.32),
                             cornerSize: CGSize(width: h * 0.16, height: h * 0.16))
            p.addEllipse(in: CGRect(x: rect.minX + w * 0.12, y: c.y - h * 0.16, width: w * 0.32, height: h * 0.4))
            p.addEllipse(in: CGRect(x: rect.minX + w * 0.36, y: c.y - h * 0.3, width: w * 0.36, height: h * 0.5))
        case .dot:
            p.addEllipse(in: rect)
            let r = min(w, h) * 0.14
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        return p
    }
}
