import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let test: () -> Void
    let hasSeam: () -> Bool

    @AppStorage(Preferences.Key.enabled) private var enabled = Preferences().enabled
    @AppStorage(Preferences.Key.intensity) private var intensity = Preferences().intensity
    @AppStorage(Preferences.Key.skipFullScreen) private var skipFullScreen = Preferences().skipFullScreen
    @AppStorage(Preferences.Key.chromatic) private var chromatic = Preferences().chromatic
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 18) {
            header
            Card(title: "Efekt") {
                SliderRow(title: "Yoğunluk", symbol: "water.waves", value: $intensity,
                          range: Preferences.intensityRange, label: "\(Int((intensity * 100).rounded()))%")
                ToggleRow(title: "Renk kayması", detail: "Dalganın kenarında çok hafif renk ayrışması",
                          symbol: "circle.lefthalf.filled", isOn: $chromatic)
            }
            Card(title: "Davranış") {
                ToggleRow(title: "Tam ekranda oynatma", detail: "Öndeki uygulama bir ekranı kaplıyorsa (oyun, video) efekt yok",
                          symbol: "arrow.up.left.and.arrow.down.right", isOn: $skipFullScreen)
                InfoRow(title: "Hareketi Azalt", symbol: "figure.walk.motion",
                        detail: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                            ? "Açık: dalga çok daha hafif oynar"
                            : "Kapalı: sistem ayarı açılırsa dalga hafifler")
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
        .padding(.horizontal, 22)
        .padding(.top, 30)
        .padding(.bottom, 22)
        .frame(width: 460)
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
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("ScreenDrop").font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("Monitörler arasında su gibi bir geçiş")
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
            Button(action: test) {
                Label("Efekti test et", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!hasSeam())
            .help(hasSeam() ? "İlk ek yerinin ortasında efekti oynatır" : "İki komşu ekran gerekiyor")
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
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
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

private struct InfoRow: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

/// Efekt ekrandaki görüntüyü büktüğü için Ekran Kaydı izni şart. Durum birkaç saniyede bir yeniden okunur.
private struct PermissionRow: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { _ in
            let granted = CGPreflightScreenCaptureAccess()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.dashed.badge.record")
                        .frame(width: 18)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Ekran Kaydı").font(.system(size: 13))
                            Circle()
                                .fill(granted ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                                .accessibilityHidden(true)
                        }
                        Text(granted ? "İzin var" : "İzin yok: efekt oynamaz")
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
                if !granted {
                    Text("Dalga, ek yerinin iki yanındaki görüntünün kendisini büker; bunun için geçiş anında o şeridin anlık görüntüsü alınır. Görüntü yalnızca bellekte kullanılır, kaydedilmez ve Mac'ten çıkmaz. İzni verdikten sonra ScreenDrop'u yeniden başlat.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(Color.orange.opacity(0.08), in: .rect(cornerRadius: 9, style: .continuous))
                }
            }
        }
    }
}
