import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let preview: () -> Void

    @AppStorage(Preferences.Key.enabled) private var enabled = Preferences().enabled
    @AppStorage(Preferences.Key.style) private var style = Preferences().style
    @AppStorage(Preferences.Key.brightness) private var brightness = Preferences().brightness
    @AppStorage(Preferences.Key.speed) private var speed = Preferences().speed
    @AppStorage(Preferences.Key.gather) private var gather = Preferences().gather
    @AppStorage(Preferences.Key.zone) private var zone = Preferences().zone
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 18) {
            header
            Card(title: "Efekt") {
                HStack(spacing: 10) {
                    ForEach(EffectStyle.allCases) { option in
                        StyleTile(style: option, selected: style == option) { style = option }
                    }
                }
                SliderRow(title: "Parlaklık", symbol: "sun.max", value: $brightness,
                          range: Preferences.brightnessRange, label: "\(Int(brightness * 100))%")
                SliderRow(title: "Hız", symbol: "gauge.with.dots.needle.67percent", value: $speed,
                          range: Preferences.speedRange, label: String(format: "%.1f×", speed))
            }
            Card(title: "Davranış") {
                ToggleRow(title: "Yaklaşırken ışık toplansın",
                          detail: "İmleç kenara doğru giderken bulanıklık ve ışık birikir",
                          symbol: "dot.radiowaves.left.and.right", isOn: $gather)
                SliderRow(title: "Yaklaşma mesafesi", symbol: "arrow.left.and.right", value: $zone,
                          range: Preferences.zoneRange, label: "\(Int(zone)) pt")
                    .disabled(!gather)
                    .opacity(gather ? 1 : 0.4)
            }
            Card(title: "Sistem") {
                PermissionRow()
                ToggleRow(title: "Girişte başlat", detail: "Mac açıldığında menü çubuğunda hazır olsun",
                          symbol: "power", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        } catch {
                            NSLog("ScreenDrop login item failed: \(error)")
                        }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
            }
            footer
        }
        .padding(22)
        .frame(width: 460)
        .background(.background)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.62, blue: 1), Color(red: 0.78, green: 0.52, blue: 1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)
            .shadow(color: Color(red: 0.6, green: 0.55, blue: 1).opacity(0.45), radius: 10, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("ScreenDrop").font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("Monitörler arasında NameDrop efekti")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Etkin", isOn: $enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.large)
        }
    }

    private var footer: some View {
        HStack {
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button(action: preview) {
                Label("Önizle", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!enabled)
        }
    }
}

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 14) { content }
                .padding(14)
                .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.quaternary, lineWidth: 0.5))
        }
    }
}

private struct StyleTile: View {
    let style: EffectStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: style.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                Text(style.title).font(.system(size: 13, weight: .semibold))
                Text(style.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(selected ? Color.accentColor.opacity(0.1) : Color.clear,
                        in: .rect(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: selected ? 1.5 : 0.5))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct SliderRow: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Label(title, systemImage: symbol).font(.system(size: 13))
                Spacer()
                Text(label)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
                .controlSize(.small)
                .accessibilityLabel(title)
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let detail: String
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
    }
}

/// İzin durumu sistem ayarlarından değişebilir; birkaç saniyede bir yeniden okunur.
private struct PermissionRow: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { _ in
            let granted = CGPreflightScreenCaptureAccess()
            HStack(spacing: 10) {
                Image(systemName: "rectangle.dashed.badge.record")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Ekran Kaydı").font(.system(size: 13))
                        Circle()
                            .fill(granted ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                    Text(granted ? "Bulanıklık ve dalga açık" : "İzin yok: yalnızca ışık oynar")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !granted {
                    Button("İzin ver") {
                        if !CGRequestScreenCaptureAccess() {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
    }
}
