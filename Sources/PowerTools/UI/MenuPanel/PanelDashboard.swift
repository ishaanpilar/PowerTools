// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import SwiftUI

// MARK: - Dashboard

/// The monitor tiles the dashboard can show, in display order. Tiles are laid
/// out two to a row, so the order also decides which ones share a row.
enum PanelDashboardTile: Hashable {
    case cpu, memory, storage, battery, gpu, network

    var detailKind: MetricDetailKind {
        switch self {
        case .cpu: return .cpu
        case .memory: return .memory
        case .storage: return .disk
        case .battery: return .battery
        case .gpu: return .gpu
        case .network: return .network
        }
    }
}

/// What the dashboard shows for the sections currently in the panel. A tile
/// follows its section: hiding System in Settings, or uninstalling the metric
/// in the Features hub, takes the tile (and its sampling) away with it.
struct PanelDashboardLayout {
    let showsThermal: Bool
    let showsKeepAwake: Bool
    let tiles: [PanelDashboardTile]

    init(sections: [PanelSectionID]) {
        let system = sections.contains(.system)
        showsThermal = system && AppFeature.monitorCPU.isAvailable
        showsKeepAwake = sections.contains(.keepAwake)
        var tiles: [PanelDashboardTile] = []
        if system, AppFeature.monitorCPU.isAvailable { tiles.append(.cpu) }
        if system, AppFeature.monitorMemory.isAvailable { tiles.append(.memory) }
        if sections.contains(.disk), AppFeature.monitorDisk.isAvailable { tiles.append(.storage) }
        if sections.contains(.power), AppFeature.monitorPower.isAvailable, PowerSampler.hasInternalBattery {
            tiles.append(.battery)
        }
        if system, AppFeature.monitorGPU.isAvailable { tiles.append(.gpu) }
        if sections.contains(.network), AppFeature.monitorNetwork.isAvailable { tiles.append(.network) }
        self.tiles = tiles
    }

    /// Only the readings the visible cards draw, so the dashboard costs no
    /// more than the tabs it replaces did while showing the same numbers.
    var monitorNeeds: SystemMonitorPanelNeeds {
        var needs = SystemMonitorPanelNeeds()
        if showsThermal {
            needs.cpuTemperature = true
            needs.gpuTemperature = AppFeature.monitorGPU.isAvailable
            needs.thermal = true
        }
        for tile in tiles {
            switch tile {
            case .cpu: needs.cpu = true
            case .memory: needs.memory = true
            case .storage: needs.disk = true
            case .battery:
                needs.power = true
                needs.battery = true
            case .gpu:
                needs.gpu = true
                needs.gpuTemperature = true
            case .network: needs.network = true
            }
        }
        return needs
    }
}

/// The menu panel's first screen: the Mac's vital signs at a glance, Keep
/// Awake one switch away, and every section one click away. Tiles open the
/// matching metric detail; the section grid opens the full section.
struct PanelDashboardView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.defaultDuration) private var defaultDuration: Int = 0

    let sections: [PanelSectionID]
    let openSection: (PanelSectionID) -> Void
    let openMetric: (MetricDetailKind) -> Void

    private static let cardShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        let layout = PanelDashboardLayout(sections: sections)
        VStack(alignment: .leading, spacing: 8) {
            if layout.showsThermal {
                thermalCard
            }
            ForEach(Array(rows(of: layout.tiles, size: 2).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { tile in
                        tileView(tile)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if layout.showsKeepAwake {
                keepAwakeRow
            }
            if !sections.isEmpty {
                sectionsGrid
                    .padding(.top, 4)
            }
        }
    }

    private func rows<Item>(of items: [Item], size: Int) -> [[Item]] {
        stride(from: 0, to: items.count, by: size).map { Array(items[$0..<min($0 + size, items.count)]) }
    }

    private var unit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
    }

    // MARK: Thermal

    private var thermalCard: some View {
        let snapshot = monitor.snapshot
        let pressure = snapshot.thermalPressure
        let tint = pressure?.panelColor(for: colorScheme) ?? Color.secondary
        return DashboardCard(action: { openSection(.system) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(l10n.s.thermalPressureLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if let pressure {
                        Text(pressure.panelName(l10n.s))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(tint.opacity(0.16)))
                    }
                    Spacer(minLength: 4)
                    Text(snapshot.cpuTemperature.map { MetricFormat.temperature($0, unit: unit) } ?? "–")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(snapshot.cpuTemperature == nil ? Color.secondary : tint)
                }
                temperatureGraph(snapshot.cpuTemperatureHistory, tint: tint)
                temperatureReadouts(snapshot)
            }
        }
    }

    /// The graph is drawn against its own recent range rather than from zero:
    /// a chip idling at 45° and working at 70° would otherwise be a line in
    /// the top third with nothing visible happening.
    @ViewBuilder
    private func temperatureGraph(_ history: [Double], tint: Color) -> some View {
        if history.count >= 2, let low = history.min(), let high = history.max() {
            let floor = max(0, low - 4)
            let span = max(8, high + 4 - floor)
            Sparkline(values: history.map { $0 - floor },
                      color: tint,
                      maxValue: span,
                      fillOpacity: 0.24,
                      lineWidth: 1.6)
                .frame(height: 44)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(colorScheme == .light ? 0.07 : 0.10))
                )
                .overlay(alignment: .topLeading) {
                    graphLabel(MetricFormat.temperatureCompact(high, unit: unit))
                }
                .overlay(alignment: .bottomLeading) {
                    graphLabel(MetricFormat.temperatureCompact(low, unit: unit))
                }
                .accessibilityHidden(true)
        }
    }

    private func graphLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
    }

    @ViewBuilder
    private func temperatureReadouts(_ snapshot: SystemSnapshot) -> some View {
        let readouts: [(String, Double)] = [
            (l10n.s.cpuLabel, snapshot.cpuTemperature),
            (l10n.s.gpuLabel, snapshot.gpuTemperature),
            (l10n.s.batteryLabel, snapshot.batteryTemperature),
        ].compactMap { label, value in value.map { (label, $0) } }
        if readouts.isEmpty, snapshot.thermalPressure == nil {
            Text(l10n.s.monitorUnavailable)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        } else if !readouts.isEmpty {
            HStack(spacing: 12) {
                ForEach(readouts, id: \.0) { label, value in
                    HStack(spacing: 4) {
                        Text(label)
                            .foregroundStyle(.secondary)
                        Text(MetricFormat.temperature(value, unit: unit))
                            .monospacedDigit()
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Tiles

    @ViewBuilder
    private func tileView(_ tile: PanelDashboardTile) -> some View {
        let snapshot = monitor.snapshot
        let open = { openMetric(tile.detailKind) }
        switch tile {
        case .cpu:
            DashboardMetricTile(title: l10n.s.cpuLabel,
                                systemImage: "cpu",
                                tint: .accentColor,
                                value: snapshot.cpuUsage.map(MetricFormat.percent) ?? "–",
                                caption: "\(l10n.s.systemUptime) \(SystemSection.uptimeString())",
                                accessory: .sparkline(snapshot.cpuHistory, .accentColor, 1),
                                action: open)
        case .gpu:
            let tint = PanelMetricColor.cyan(for: colorScheme)
            DashboardMetricTile(title: l10n.s.gpuLabel,
                                systemImage: "rectangle.connected.to.line.below",
                                tint: tint,
                                value: snapshot.gpuUsage.map(MetricFormat.percent) ?? "–",
                                caption: snapshot.gpuTemperature.map { MetricFormat.temperature($0, unit: unit) },
                                accessory: .sparkline(snapshot.gpuHistory, tint, 1),
                                action: open)
        case .memory:
            let used = MonitorMemoryMetric.current.value(in: snapshot)
            let total = snapshot.memoryTotal
            let fraction = used.flatMap { used in
                total.flatMap { $0 > 0 ? Double(used) / Double($0) : nil }
            }
            let tint = snapshot.memoryPressure.panelColor(for: colorScheme)
            DashboardMetricTile(title: l10n.s.memorySection,
                                systemImage: "memorychip",
                                tint: tint,
                                value: fraction.map(MetricFormat.percent) ?? "–",
                                caption: used.flatMap { used in
                                    total.map { "\(MetricFormat.bytes(used)) / \(MetricFormat.bytes($0))" }
                                },
                                accessory: .bar(fraction ?? 0, tint),
                                action: open)
        case .storage:
            let disk = primaryDisk(in: snapshot)
            DashboardMetricTile(title: l10n.s.diskSection,
                                systemImage: "internaldrive",
                                tint: .accentColor,
                                value: disk.map { MetricFormat.percent($0.usedFraction) } ?? "–",
                                caption: disk.map { "\(MetricFormat.diskBytes($0.freeBytes)) \(l10n.s.diskAvailable)" },
                                accessory: .bar(disk?.usedFraction ?? 0, nil),
                                action: open)
        case .battery:
            let power = snapshot.power
            let charge = power?.chargePercent
            let fraction = charge.map { Double($0) / 100 }
            let tint = batteryTint(fraction)
            DashboardMetricTile(title: l10n.s.batteryLabel,
                                systemImage: batterySymbol(power),
                                tint: tint,
                                value: charge.map { "\($0)%" } ?? "–",
                                caption: batteryCaption(power),
                                accessory: .bar(fraction ?? 0, tint),
                                action: open)
        case .network:
            let tint = PanelMetricColor.green(for: colorScheme)
            DashboardMetricTile(title: l10n.s.networkSection,
                                systemImage: "network",
                                tint: tint,
                                value: snapshot.netDownBytesPerSec.map { "↓ \(MetricFormat.bytesPerSecCompact($0))" } ?? "–",
                                caption: snapshot.netUpBytesPerSec.map { "↑ \(MetricFormat.bytesPerSecCompact($0))" },
                                accessory: .sparkline(snapshot.netDownHistory, tint, nil),
                                action: open)
        }
    }

    /// The startup volume when it can be told apart, since that is the disk
    /// "running out of space" means; otherwise the Disks section's first.
    private func primaryDisk(in snapshot: SystemSnapshot) -> DiskDeviceReading? {
        let devices = snapshot.disk?.devices ?? []
        return devices.first(where: { $0.mountPath == "/" })
            ?? devices.first(where: \.isInternal)
            ?? devices.first
    }

    private func batteryTint(_ fraction: Double?) -> Color {
        guard let fraction else { return .secondary }
        if fraction <= 0.10 { return PanelMetricColor.red(for: colorScheme) }
        if fraction <= 0.20 { return PanelMetricColor.orange(for: colorScheme) }
        return PanelMetricColor.green(for: colorScheme)
    }

    private func batterySymbol(_ power: PowerReading?) -> String {
        guard let power else { return "battery.100" }
        if power.isCharging { return "battery.100.bolt" }
        switch power.chargePercent ?? 100 {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private func batteryCaption(_ power: PowerReading?) -> String? {
        guard let power else { return nil }
        if power.isCharging { return l10n.s.powerCharging }
        if let remaining = power.timeRemainingSeconds.flatMap(BatteryTimeSupport.formatted) {
            return remaining
        }
        return power.externalConnected ? nil : l10n.s.powerOnBattery
    }

    // MARK: Keep awake

    private var keepAwakeRow: some View {
        HStack(spacing: 10) {
            Button {
                openSection(.keepAwake)
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(awake.isActive ? PanelMetricColor.orange(for: colorScheme) : Color.accentColor)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(l10n.s.keepAwakeTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        keepAwakeStatus
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: keepAwakeBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityLabel(l10n.s.keepAwakeTitle)
        }
        .padding(10)
        .background(Self.cardShape.fill(PanelSurface.cardFill(for: colorScheme)))
        .overlay(Self.cardShape.strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.7))
    }

    @ViewBuilder
    private var keepAwakeStatus: some View {
        if awake.isActive {
            if awake.sessionTrigger == .automation {
                Text(FeatureStrings.keepAwakeAutomation(l10n.language)
                    .activeStatus(for: awake.activeAutomationConditions))
            } else if let end = awake.endDate {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text("\(l10n.s.keepAwakeEndsIn) \(KeepAwakeCard.remainingText(until: end))")
                        .monospacedDigit()
                }
            } else {
                Text(l10n.s.keepAwakeUntilDisabled)
            }
        } else {
            Text(l10n.s.keepAwakeNormalRules)
        }
    }

    /// The same switch as the Keep Awake section's: on starts a session of
    /// the default length, off ends whatever session is running.
    private var keepAwakeBinding: Binding<Bool> {
        Binding(
            get: { awake.isActive },
            set: { on in
                if on {
                    awake.activate(minutes: defaultDuration)
                } else if awake.isActive {
                    awake.toggle()
                }
            }
        )
    }

    // MARK: Sections

    private var sectionsGrid: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionTitle(l10n.s.panelFooterSections)
                .padding(.leading, 2)
            ForEach(Array(rows(of: sections, size: 3).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row) { id in
                        sectionTile(id)
                    }
                    // Keep a short last row on the grid instead of stretching it.
                    ForEach(0..<(3 - row.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionTile(_ id: PanelSectionID) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button {
            openSection(id)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: id.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 18)
                Text(id.title(l10n.s))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 58, maxHeight: .infinity)
            .contentShape(shape)
            .panelGlassControl(in: shape)
        }
        .buttonStyle(.plain)
        .help(id.title(l10n.s))
    }
}

// MARK: - Header stats

/// The live readings beside the logo: temperature, CPU and memory, each a
/// shortcut into its detail. They stay on every screen, so the numbers
/// people open the panel for are there whichever section they left it on.
struct PanelHeaderStats: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue

    let openMetric: (MetricDetailKind) -> Void

    static var monitorNeeds: SystemMonitorPanelNeeds {
        SystemMonitorPanelNeeds(cpu: AppFeature.monitorCPU.isAvailable,
                                memory: AppFeature.monitorMemory.isAvailable,
                                cpuTemperature: AppFeature.monitorCPU.isAvailable)
    }

    var body: some View {
        let snapshot = monitor.snapshot
        HStack(spacing: 5) {
            if AppFeature.monitorCPU.isAvailable, let temperature = snapshot.cpuTemperature {
                chip(symbol: "thermometer.medium",
                     value: MetricFormat.temperatureCompact(temperature,
                                                            unit: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius),
                     tint: snapshot.thermalPressure?.panelColor(for: colorScheme) ?? .secondary,
                     label: l10n.s.temperatures) {
                    openMetric(.cpu)
                }
            }
            if AppFeature.monitorCPU.isAvailable, let usage = snapshot.cpuUsage {
                chip(symbol: "cpu",
                     value: MetricFormat.percent(usage),
                     tint: .accentColor,
                     label: l10n.s.cpuLabel) {
                    openMetric(.cpu)
                }
            }
            if AppFeature.monitorMemory.isAvailable,
               let used = MonitorMemoryMetric.current.value(in: snapshot),
               let total = snapshot.memoryTotal, total > 0 {
                chip(symbol: "memorychip",
                     value: MetricFormat.percent(Double(used) / Double(total)),
                     tint: snapshot.memoryPressure.panelColor(for: colorScheme),
                     label: l10n.s.memorySection) {
                    openMetric(.memory)
                }
            }
        }
    }

    private func chip(symbol: String, value: String, tint: Color, label: String,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 7)
            .frame(height: 22)
            .contentShape(Capsule())
            .panelGlassControl(in: Capsule())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel("\(label) \(value)")
    }
}

// MARK: - Building blocks

/// A tappable content card. Cards hold readings, so they keep the quiet card
/// fill rather than glass (glass is for the controls that sit on content),
/// and answer the pointer with a light wash.
private struct DashboardCard<Label: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    private let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        Button(action: action) {
            label()
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(shape.fill(PanelSurface.cardFill(for: colorScheme)))
                .overlay(shape.fill(Color.primary.opacity(hovering ? 0.045 : 0)))
                .overlay(shape.strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.7))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

private struct DashboardMetricTile: View {
    enum Accessory {
        case bar(Double, Color?)
        /// Values, color, and a fixed top of scale (nil scales to the peak).
        case sparkline([Double], Color, Double?)
    }

    let title: String
    let systemImage: String
    let tint: Color
    let value: String
    let caption: String?
    let accessory: Accessory
    let action: () -> Void

    var body: some View {
        DashboardCard(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                accessoryView
                    .frame(height: 16)
                Text(caption ?? " ")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case let .bar(fraction, color):
            UsageBar(fraction: fraction, tint: color)
                .frame(maxHeight: .infinity)
        case let .sparkline(values, color, maxValue):
            if values.count >= 2 {
                Sparkline(values: values, color: color, maxValue: maxValue, lineWidth: 1.3)
            } else {
                Color.clear
            }
        }
    }
}

extension View {
    /// Liquid Glass for a control sitting on the panel (a chip, a tile, a
    /// back button), on macOS 26 with the Liquid Glass setting on. Everywhere
    /// else it falls back to the raised fill the panel's controls already use.
    func panelGlassControl<S: InsettableShape>(in shape: S) -> some View {
        modifier(PanelGlassControlModifier(shape: shape))
    }
}

private struct PanelGlassControlModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var liquidGlassEnabled = false

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *), liquidGlassEnabled, !reduceTransparency {
            content
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            standard(content)
        }
#else
        standard(content)
#endif
    }

    private func standard(_ content: Content) -> some View {
        content
            .background(shape.fill(PanelSurface.controlFill(for: colorScheme)))
            .overlay(shape.strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.7))
    }
}

extension SystemMonitorPanelNeeds {
    /// Everything either side needs: the header's readings ride along with
    /// whatever screen is open beneath it.
    func union(_ other: SystemMonitorPanelNeeds) -> SystemMonitorPanelNeeds {
        var merged = self
        merged.system = system || other.system
        merged.network = network || other.network
        merged.disk = disk || other.disk
        merged.power = power || other.power
        merged.cpu = cpu || other.cpu
        merged.gpu = gpu || other.gpu
        merged.memory = memory || other.memory
        merged.battery = battery || other.battery
        merged.peripheralBattery = peripheralBattery || other.peripheralBattery
        merged.cpuTemperature = cpuTemperature || other.cpuTemperature
        merged.gpuTemperature = gpuTemperature || other.gpuTemperature
        merged.batteryTemperature = batteryTemperature || other.batteryTemperature
        merged.fanSpeed = fanSpeed || other.fanSpeed
        merged.thermal = thermal || other.thermal
        return merged
    }
}

extension ThermalPressure {
    func panelColor(for scheme: ColorScheme) -> Color {
        switch self {
        case .nominal: return PanelMetricColor.green(for: scheme)
        case .moderate: return PanelMetricColor.yellow(for: scheme)
        case .heavy: return PanelMetricColor.orange(for: scheme)
        case .critical: return PanelMetricColor.red(for: scheme)
        }
    }

    func panelName(_ s: Strings) -> String {
        switch self {
        case .nominal: return s.thermalNominal
        case .moderate: return s.thermalModerate
        case .heavy: return s.thermalHeavy
        case .critical: return s.thermalCritical
        }
    }
}

extension MemoryPressure {
    func panelColor(for scheme: ColorScheme) -> Color {
        switch self {
        case .normal, .unknown: return PanelMetricColor.mint(for: scheme)
        case .warning: return PanelMetricColor.yellow(for: scheme)
        case .critical: return PanelMetricColor.red(for: scheme)
        }
    }
}
