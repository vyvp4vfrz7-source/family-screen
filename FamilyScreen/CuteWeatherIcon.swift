import SwiftUI

/// A cute, animated weather character drawn by the app itself: a waving sun,
/// a cloud with a peeking sun, a cloud under a pink umbrella, a snowman,
/// a sleepy moon, a whooshing wind friend and so on. Takes the same SF Symbol
/// names the weather code produces, so it can replace those icons anywhere.
/// Pass `windy: true` (strong wind) to show the wind friend instead.
struct CuteWeatherIcon: View {
    let symbol: String
    var size: CGFloat
    var windy: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Kind { case sun, moon, partSun, partMoon, cloud, rain, snow, thunder, fog, wind }

    private var kind: Kind {
        let s = symbol
        if s.contains("bolt") { return .thunder }
        if s.contains("snow") || s.contains("sleet") { return .snow }
        if s.contains("rain") || s.contains("drizzle") { return .rain }
        if windy || s.hasPrefix("wind") || s.contains("tornado") { return .wind }
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
            ZStack {
                sun(s * 0.86, t)
                waveArm(s, t).offset(x: s * 0.36, y: -s * 0.02)
            }
        case .moon:
            ZStack {
                stars(s, t)
                moon(s * 0.8, t)
                sleepZ(s, t).offset(x: s * 0.26, y: -s * 0.26)
            }
        case .partSun:
            ZStack {
                // The sun peeks out from behind the cloud, then hides again.
                sun(s * 0.6, t, awake: true)
                    .offset(x: -s * 0.2, y: -s * 0.2 + s * 0.06 * CGFloat(sin(t * 1.2)))
                cloud(s * 0.85, t).offset(x: s * 0.07, y: s * 0.1)
            }
        case .partMoon:
            ZStack {
                moon(s * 0.55, t).offset(x: -s * 0.18, y: -s * 0.2)
                cloud(s * 0.85, t, awake: false).offset(x: s * 0.07, y: s * 0.1)
            }
        case .cloud:
            cloud(s, t, awake: false)
        case .rain:
            ZStack {
                drops(s, t, snow: false).offset(x: -s * 0.06)
                cloud(s * 0.82, t).offset(x: -s * 0.06, y: -s * 0.14)
                umbrella(s * 0.42, t).offset(x: s * 0.3, y: s * 0.1)
            }
        case .snow:
            ZStack {
                drops(s * 1.3, t, snow: true).offset(y: -s * 0.55)
                snowman(s, t)
            }
        case .thunder:
            let flash = t.truncatingRemainder(dividingBy: 2.6) < 0.3
            ZStack {
                Bolt().fill(Color(red: 1, green: 0.82, blue: 0.2))
                    .frame(width: s * 0.22, height: s * 0.34)
                    .opacity(flash ? 1 : 0.4)
                    .scaleEffect(flash ? 1.15 : 1)
                    .offset(x: s * 0.02, y: s * 0.28)
                cloud(s * 0.9, t, tint: Color(white: 0.8), surprised: flash).offset(y: -s * 0.12)
            }
        case .fog:
            ZStack {
                cloud(s * 0.9, t, awake: false).offset(y: -s * 0.1)
                ForEach(0..<2) { i in
                    Capsule().fill(Color.white.opacity(0.55))
                        .frame(width: s * 0.62, height: s * 0.06)
                        .offset(x: CGFloat(sin(t * 0.9 + Double(i) * 2)) * s * 0.08, y: s * (0.27 + 0.11 * CGFloat(i)))
                }
            }
        case .wind:
            wind(s, t)
        }
    }

    // MARK: Characters

    private func sun(_ s: CGFloat, _ t: Double, awake: Bool = true) -> some View {
        ZStack {
            ZStack {
                ForEach(0..<8) { i in
                    Capsule().fill(Color(red: 1, green: 0.78, blue: 0.25))
                        .frame(width: s * 0.08, height: s * 0.16)
                        .offset(y: -s * 0.4)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
            }
            .rotationEffect(.degrees(t * 18))
            Circle()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.4), Color(red: 1, green: 0.7, blue: 0.22)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.6, height: s * 0.6)
                .scaleEffect(CGFloat(1 + 0.03 * sin(t * 2)))
            face(s * 0.6, t, awake: awake)
        }
        .frame(width: s, height: s)
    }

    /// A little arm that waves hello.
    private func waveArm(_ s: CGFloat, _ t: Double) -> some View {
        Capsule().fill(Color(red: 1, green: 0.76, blue: 0.25))
            .frame(width: s * 0.07, height: s * 0.2)
            .offset(y: -s * 0.08)
            .rotationEffect(.degrees(20 + 25 * sin(t * 4)), anchor: .center)
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
            face(s * 0.4, t, awake: false).offset(x: -s * 0.12, y: s * 0.06)
        }
        .rotationEffect(.degrees(6 * sin(t * 0.8)))
        .frame(width: s, height: s)
    }

    /// "z z" floating up from a sleeping face.
    private func sleepZ(_ s: CGFloat, _ t: Double) -> some View {
        ZStack {
            ForEach(0..<2) { i in
                let p = (t * 0.4 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(.system(size: s * (0.12 + 0.06 * CGFloat(p)), weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(1 - p)
                    .offset(x: s * 0.08 * CGFloat(p), y: -s * 0.18 * CGFloat(p))
            }
        }
    }

    private func stars(_ s: CGFloat, _ t: Double) -> some View {
        let spots: [(CGFloat, CGFloat)] = [(0.36, 0.1), (-0.36, -0.3), (0.0, -0.42)]
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

    private func cloud(_ s: CGFloat, _ t: Double, tint: Color = Color(white: 0.97),
                       awake: Bool = true, surprised: Bool = false) -> some View {
        ZStack {
            Group {
                Circle().frame(width: s * 0.42, height: s * 0.42).offset(x: -s * 0.08, y: -s * 0.08)
                Circle().frame(width: s * 0.3, height: s * 0.3).offset(x: s * 0.15, y: -s * 0.01)
                Capsule().frame(width: s * 0.78, height: s * 0.3).offset(y: s * 0.08)
            }
            .foregroundColor(tint)
            .shadow(color: .black.opacity(0.15), radius: s * 0.02, y: s * 0.02)
            face(s * 0.4, t, awake: awake, surprised: surprised).offset(x: -s * 0.02, y: s * 0.07)
        }
        .offset(x: s * 0.03 * CGFloat(sin(t * 0.8)))
        .frame(width: s, height: s)
    }

    /// A pink umbrella that sways a little.
    private func umbrella(_ s: CGFloat, _ t: Double) -> some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Color(white: 0.35))
                .frame(width: max(s * 0.05, 1.5), height: s * 0.55)
                .offset(y: s * 0.22)
            HalfDisc().fill(Color(red: 1, green: 0.48, blue: 0.66))
                .frame(width: s * 0.9, height: s * 0.45)
        }
        .frame(width: s, height: s, alignment: .top)
        .rotationEffect(.degrees(10 + 6 * sin(t * 1.6)), anchor: .bottom)
    }

    /// A snowman with a red scarf and a carrot nose.
    private func snowman(_ s: CGFloat, _ t: Double) -> some View {
        ZStack {
            Circle().fill(Color.white).frame(width: s * 0.5, height: s * 0.5).offset(y: s * 0.18)
            ZStack {
                Circle().fill(Color.white).frame(width: s * 0.38, height: s * 0.38)
                face(s * 0.38, t)
                Triangle().fill(Color(red: 1, green: 0.55, blue: 0.24))
                    .frame(width: s * 0.1, height: s * 0.05)
                    .rotationEffect(.degrees(90))
                    .offset(x: s * 0.04, y: s * 0.02)
            }
            .offset(y: -s * 0.18)
            .rotationEffect(.degrees(4 * sin(t * 1.3)))
            Capsule().fill(Color(red: 0.9, green: 0.34, blue: 0.3))
                .frame(width: s * 0.36, height: s * 0.07)
                .offset(y: -s * 0.02)
        }
        .shadow(color: .black.opacity(0.12), radius: s * 0.02, y: s * 0.02)
    }

    /// A round little wind friend blowing whooshing lines.
    private func wind(_ s: CGFloat, _ t: Double) -> some View {
        ZStack {
            ForEach(0..<3) { i in
                let p = (t * 0.9 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Capsule().fill(Color(red: 0.8, green: 0.9, blue: 1).opacity(1 - p))
                    .frame(width: s * 0.36, height: s * 0.05)
                    .offset(x: s * (0.05 - 0.4 * CGFloat(p)), y: s * (-0.14 + 0.14 * CGFloat(i)))
            }
            ZStack {
                Circle().fill(Color(red: 0.91, green: 0.96, blue: 1)).frame(width: s * 0.44, height: s * 0.44)
                face(s * 0.44, t)
                Circle().stroke(Color(red: 0.3, green: 0.25, blue: 0.3), lineWidth: max(s * 0.015, 1))
                    .frame(width: s * 0.06, height: s * 0.06)
                    .offset(x: -s * 0.1, y: s * 0.06)
            }
            .offset(x: s * 0.22 + s * 0.02 * CGFloat(sin(t * 3)))
        }
        .frame(width: s, height: s)
    }

    private func drops(_ s: CGFloat, _ t: Double, snow: Bool) -> some View {
        ZStack {
            ForEach(0..<3) { i in
                let phase = (t * (snow ? 0.5 : 1.1) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Group {
                    if snow {
                        Circle().fill(Color.white).frame(width: s * 0.07, height: s * 0.07)
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

    /// Happy eyes that blink now and then (or sleepy closed eyes), a smile
    /// and pink cheeks.
    private func face(_ d: CGFloat, _ t: Double, awake: Bool = true, surprised: Bool = false) -> some View {
        let ink = Color(red: 0.25, green: 0.2, blue: 0.25)
        let blink = t.truncatingRemainder(dividingBy: 3.7) < 0.14
        let line = StrokeStyle(lineWidth: max(d * 0.045, 1), lineCap: .round)
        return ZStack {
            HStack(spacing: d * 0.24) {
                ForEach(0..<2) { _ in
                    if awake && !blink {
                        Circle().fill(ink).frame(width: d * 0.11, height: d * 0.11)
                            .overlay(Circle().fill(Color.white).frame(width: d * 0.035, height: d * 0.035)
                                        .offset(x: d * 0.015, y: -d * 0.02))
                    } else {
                        SleepyEye().stroke(ink, style: line).frame(width: d * 0.14, height: d * 0.06)
                    }
                }
            }
            .offset(y: -d * 0.04)
            Group {
                if surprised {
                    Circle().stroke(ink, style: line).frame(width: d * 0.09, height: d * 0.09)
                } else {
                    SleepyEye().stroke(ink, style: line).frame(width: d * 0.12, height: d * 0.05)
                }
            }
            .offset(y: d * 0.1)
            HStack(spacing: d * 0.42) {
                Ellipse().fill(Color(red: 1, green: 0.55, blue: 0.6).opacity(0.6)).frame(width: d * 0.14, height: d * 0.08)
                Ellipse().fill(Color(red: 1, green: 0.55, blue: 0.6).opacity(0.6)).frame(width: d * 0.14, height: d * 0.08)
            }
            .offset(y: d * 0.09)
        }
    }
}

/// A downward curve: a closed eye or a smile.
private struct SleepyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY))
        return p
    }
}

private struct HalfDisc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width / 2,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct Bolt: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.55, y: 0))
        p.addLine(to: CGPoint(x: 0, y: h * 0.58))
        p.addLine(to: CGPoint(x: w * 0.45, y: h * 0.58))
        p.addLine(to: CGPoint(x: w * 0.3, y: h))
        p.addLine(to: CGPoint(x: w, y: h * 0.38))
        p.addLine(to: CGPoint(x: w * 0.55, y: h * 0.38))
        p.closeSubpath()
        return p.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}
