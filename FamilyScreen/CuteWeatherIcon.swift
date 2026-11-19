import SwiftUI

/// A cute, gently animated weather picture (sleepy faces, drifting clouds,
/// falling rain and snow) drawn by the app itself. Takes the same SF Symbol
/// names the weather code produces, so it can replace those icons anywhere.
struct CuteWeatherIcon: View {
    let symbol: String
    var size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Kind { case sun, moon, partSun, partMoon, cloud, rain, snow, thunder, fog }

    private var kind: Kind {
        let s = symbol
        if s.contains("bolt") { return .thunder }
        if s.contains("snow") || s.contains("sleet") { return .snow }
        if s.contains("rain") || s.contains("drizzle") { return .rain }
        if s.contains("fog") || s.contains("haze") || s.contains("smoke") { return .fog }
        if s.hasPrefix("cloud.sun") { return .partSun }
        if s.hasPrefix("cloud.moon") { return .partMoon }
        if s.hasPrefix("cloud") { return .cloud }
        if s.hasPrefix("moon") { return .moon }
        if s.hasPrefix("sun") { return .sun }
        return .cloud
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            picture(t)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func picture(_ t: Double) -> some View {
        let s = size
        switch kind {
        case .sun:
            sun(s, t)
        case .moon:
            ZStack {
                stars(s, t)
                moon(s * 0.75, t)
            }
        case .partSun:
            ZStack {
                sun(s * 0.72, t).offset(x: -s * 0.16, y: -s * 0.16)
                cloud(s * 0.85, t).offset(x: s * 0.07, y: s * 0.1)
            }
        case .partMoon:
            ZStack {
                moon(s * 0.55, t).offset(x: -s * 0.18, y: -s * 0.2)
                cloud(s * 0.85, t).offset(x: s * 0.07, y: s * 0.1)
            }
        case .cloud:
            cloud(s, t)
        case .rain:
            ZStack {
                drops(s, t, snow: false)
                cloud(s * 0.9, t).offset(y: -s * 0.12)
            }
        case .snow:
            ZStack {
                drops(s, t, snow: true)
                cloud(s * 0.9, t).offset(y: -s * 0.12)
            }
        case .thunder:
            let flash = t.truncatingRemainder(dividingBy: 2.6) < 0.3
            ZStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: s * 0.34))
                    .foregroundColor(Color(red: 1, green: 0.82, blue: 0.2))
                    .opacity(flash ? 1 : 0.45)
                    .offset(x: s * 0.04, y: s * 0.28)
                cloud(s * 0.9, t, tint: Color(white: 0.78)).offset(y: -s * 0.12)
            }
        case .fog:
            ZStack {
                cloud(s * 0.9, t).offset(y: -s * 0.1)
                ForEach(0..<2) { i in
                    Capsule().fill(Color.white.opacity(0.55))
                        .frame(width: s * 0.62, height: s * 0.06)
                        .offset(x: CGFloat(sin(t * 0.9 + Double(i) * 2)) * s * 0.08, y: s * (0.27 + 0.11 * CGFloat(i)))
                }
            }
        }
    }

    // MARK: Pieces

    private func sun(_ s: CGFloat, _ t: Double) -> some View {
        ZStack {
            ZStack {
                ForEach(0..<8) { i in
                    Capsule().fill(Color(red: 1, green: 0.78, blue: 0.25))
                        .frame(width: s * 0.07, height: s * 0.15)
                        .offset(y: -s * 0.38)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
            }
            .rotationEffect(.degrees(t * 18))
            Circle()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.4), Color(red: 1, green: 0.68, blue: 0.2)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.54, height: s * 0.54)
                .scaleEffect(CGFloat(1 + 0.03 * sin(t * 2)))
            face(s * 0.54)
        }
        .frame(width: s, height: s)
    }

    private func moon(_ s: CGFloat, _ t: Double) -> some View {
        ZStack {
            Circle().fill(Color(red: 1, green: 0.92, blue: 0.6))
                .mask(
                    ZStack {
                        Circle()
                        Circle().offset(x: s * 0.28, y: -s * 0.14).blendMode(.destinationOut)
                    }
                    .compositingGroup()
                )
                .frame(width: s * 0.7, height: s * 0.7)
            face(s * 0.4).offset(x: -s * 0.12, y: s * 0.06)
        }
        .rotationEffect(.degrees(6 * sin(t * 0.8)))
        .frame(width: s, height: s)
    }

    private func stars(_ s: CGFloat, _ t: Double) -> some View {
        let spots: [(CGFloat, CGFloat)] = [(0.3, -0.32), (0.38, 0.05), (-0.36, -0.3)]
        return ZStack {
            ForEach(0..<3) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: s * 0.12))
                    .foregroundColor(.white)
                    .opacity(0.4 + 0.6 * abs(sin(t * 1.5 + Double(i))))
                    .offset(x: s * spots[i].0, y: s * spots[i].1)
            }
        }
    }

    private func cloud(_ s: CGFloat, _ t: Double, tint: Color = Color(white: 0.97)) -> some View {
        ZStack {
            Group {
                Circle().frame(width: s * 0.42, height: s * 0.42).offset(x: -s * 0.08, y: -s * 0.08)
                Circle().frame(width: s * 0.3, height: s * 0.3).offset(x: s * 0.15, y: -s * 0.01)
                Capsule().frame(width: s * 0.78, height: s * 0.3).offset(y: s * 0.08)
            }
            .foregroundColor(tint)
            .shadow(color: .black.opacity(0.15), radius: s * 0.02, y: s * 0.02)
            face(s * 0.36).offset(x: -s * 0.02, y: s * 0.07)
        }
        .offset(x: s * 0.03 * CGFloat(sin(t * 0.8)))
        .frame(width: s, height: s)
    }

    private func drops(_ s: CGFloat, _ t: Double, snow: Bool) -> some View {
        ZStack {
            ForEach(0..<3) { i in
                let phase = (t * (snow ? 0.5 : 1.1) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Group {
                    if snow {
                        Circle().fill(Color.white).frame(width: s * 0.09, height: s * 0.09)
                    } else {
                        Capsule().fill(Color(red: 0.45, green: 0.72, blue: 1)).frame(width: s * 0.06, height: s * 0.13)
                    }
                }
                .offset(x: s * (-0.18 + 0.18 * CGFloat(i)) + (snow ? s * 0.04 * CGFloat(sin(t * 2 + Double(i))) : 0),
                        y: s * (0.12 + 0.3 * CGFloat(phase)))
                .opacity(1 - phase)
            }
        }
    }

    /// Sleepy closed eyes and pink cheeks.
    private func face(_ d: CGFloat) -> some View {
        ZStack {
            HStack(spacing: d * 0.24) {
                SleepyEye().stroke(Color(red: 0.3, green: 0.25, blue: 0.3), style: StrokeStyle(lineWidth: max(d * 0.04, 1), lineCap: .round))
                    .frame(width: d * 0.14, height: d * 0.06)
                SleepyEye().stroke(Color(red: 0.3, green: 0.25, blue: 0.3), style: StrokeStyle(lineWidth: max(d * 0.04, 1), lineCap: .round))
                    .frame(width: d * 0.14, height: d * 0.06)
            }
            .offset(y: -d * 0.02)
            HStack(spacing: d * 0.38) {
                Ellipse().fill(Color(red: 1, green: 0.55, blue: 0.6).opacity(0.6)).frame(width: d * 0.14, height: d * 0.08)
                Ellipse().fill(Color(red: 1, green: 0.55, blue: 0.6).opacity(0.6)).frame(width: d * 0.14, height: d * 0.08)
            }
            .offset(y: d * 0.11)
        }
    }
}

private struct SleepyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY))
        return p
    }
}
