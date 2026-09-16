// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Dashboard

/// The monitor cards the dashboard can show, one full-width row each, in
/// display order. Declaration order is the default order: CPU, Memory,
/// Storage, Network, GPU, Battery.
enum PanelDashboardTile: String, PanelOrderItem, Identifiable {
    case cpu, memory, storage, network, gpu, battery

    var id: String { rawValue }

    var detailKind: MetricDetailKind {
        switch self {
        case .cpu: return .cpu
        case .memory: return .memory
        case .storage: return .disk
        case .network: return .network
        case .gpu: return .gpu
        case .battery: return .battery
        }
    }

    var symbolName: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .storage: return "internaldrive"
        case .network: return "network"
        case .gpu: return "rectangle.connected.to.line.below"
        case .battery: return "battery.100"
        }
    }

    func title(_ s: Strings) -> String {
        switch self {
        case .cpu: return s.cpuLabel
        case .memory: return s.memorySection
        case .storage: return s.diskSection
        case .network: return s.networkSection
        case .gpu: return s.gpuLabel
        case .battery: return s.batteryLabel
        }
    }

    /// The equivalent existing menu-bar metric: the card's own circle toggle
    /// shows or hides this reading next to the status icon, reusing the same
    /// keys the Menu bar settings page already writes to.
    var menuBarMetric: MenuBarMetric {
        switch self {
        case .cpu: return .cpu
        case .memory: return .memory
        case .storage: return .diskUsage
        case .network: return .network
        case .gpu: return .gpu
        case .battery: return .battery
        }
    }

    /// A card follows its section: hiding System in Settings, or uninstalling
    /// the metric in the Features hub, takes the card (and its sampling) away
    /// with it, independent of the card's own show/hide switch below.
    func isAvailable(sections: [PanelSectionID]) -> Bool {
        switch self {
        case .cpu: return sections.contains(.system) && AppFeature.monitorCPU.isAvailable
        case .memory: return sections.contains(.system) && AppFeature.monitorMemory.isAvailable
        case .storage: return sections.contains(.disk) && AppFeature.monitorDisk.isAvailable
        case .network: return sections.contains(.network) && AppFeature.monitorNetwork.isAvailable
        case .gpu: return sections.contains(.system) && AppFeature.monitorGPU.isAvailable
        case .battery:
            return sections.contains(.power) && AppFeature.monitorPower.isAvailable
                && PowerSampler.hasInternalBattery
        }
    }

    var visibilityKey: String {
        switch self {
        case .cpu: return DefaultsKey.panelDashboardShowCPU
        case .memory: return DefaultsKey.panelDashboardShowMemory
        case .storage: return DefaultsKey.panelDashboardShowStorage
        case .network: return DefaultsKey.panelDashboardShowNetwork
        case .gpu: return DefaultsKey.panelDashboardShowGPU
        case .battery: return DefaultsKey.panelDashboardShowBattery
        }
    }

    static func isShown(_ tile: PanelDashboardTile, defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: tile.visibilityKey) as? Bool ?? true
    }
}

/// What the dashboard shows for the sections currently in the panel: the
/// saved card order and visibility, intersected with what is actually
/// installed and turned on. Read fresh each time (not a View), so the
/// caption in Settings and the sampling plan in the live panel never disagree.
struct PanelDashboardLayout {
    let showsThermal: Bool
    let showsKeepAwake: Bool
    let tiles: [PanelDashboardTile]

    init(sections: [PanelSectionID]) {
        let system = sections.contains(.system)
        showsThermal = system && AppFeature.monitorCPU.isAvailable
        showsKeepAwake = sections.contains(.keepAwake)
        tiles = PanelLayout.itemOrder(PanelDashboardTile.self, key: DefaultsKey.panelDashboardOrder)
            .filter { $0.isAvailable(sections: sections) && PanelDashboardTile.isShown($0) }
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
/// Awake one switch away, and every section one click away. Cards open the
/// matching metric detail; the section grid opens the full section. The card
/// list mirrors the section list: full width, one after another, reorderable
/// and individually hideable from its own edit mode.
struct PanelDashboardView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.defaultDuration) private var defaultDuration: Int = 0
    @AppStorage(DefaultsKey.panelDashboardOrder) private var cardOrderRaw = ""
    @AppStorage(DefaultsKey.panelDashboardShowCPU) private var showCPU = true
    @AppStorage(DefaultsKey.panelDashboardShowMemory) private var showMemory = true
    @AppStorage(DefaultsKey.panelDashboardShowStorage) private var showStorage = true
    @AppStorage(DefaultsKey.panelDashboardShowNetwork) private var showNetwork = true
    @AppStorage(DefaultsKey.panelDashboardShowGPU) private var showGPU = true
    @AppStorage(DefaultsKey.panelDashboardShowBattery) private var showBattery = true
    // Whether each card's history graph draws under its bar — the same
    // switches Settings → Monitor already exposes, now also live here.
    @AppStorage(DefaultsKey.monitorGraphCPU) private var graphCPU = true
    @AppStorage(DefaultsKey.monitorGraphMemory) private var graphMemory = true
    @AppStorage(DefaultsKey.monitorGraphGPU) private var graphGPU = true
    @AppStorage(DefaultsKey.monitorGraphNetwork) private var graphNetwork = true
    @AppStorage(DefaultsKey.monitorGraphBattery) private var graphBattery = true
    @State private var editingCards = false
    @State private var draggingTile: PanelDashboardTile?

    let sections: [PanelSectionID]
    let openSection: (PanelSectionID) -> Void
    /// The card currently expanded in place; nil collapses them all. Owned by
    /// `MenuPanelView` so the sampling plan can see it too — an expanded
    /// card's detail needs readings the collapsed card never asked for.
    @Binding var expandedTile: PanelDashboardTile?

    private static let cardShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        let layout = PanelDashboardLayout(sections: sections)
        VStack(alignment: .leading, spacing: 8) {
            if layout.showsThermal {
                thermalCard
            }
            chargingCard
            cardsSection
            if layout.showsKeepAwake {
                keepAwakeRow
            }
            if !sections.isEmpty {
                sectionsGrid
                    .padding(.top, 4)
            }
            // Hidden cards still count: the edit button above brings them back.
            if !layout.showsThermal, !layout.showsKeepAwake, sections.isEmpty,
               availableTiles(sections: sections).isEmpty {
                PanelDashboardEmptyState()
            }
        }
    }

    private func toggleExpanded(_ tile: PanelDashboardTile) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            expandedTile = (expandedTile == tile) ? nil : tile
        }
    }

    // MARK: Charging

    /// A card that exists only while actually drawing power from a charger —
    /// hidden on battery, and hidden while plugged in but not charging (already
    /// full, or paused by Optimized Battery Charging) — appearing and leaving
    /// with the same animation a card's own expansion uses.
    @ViewBuilder
    private var chargingCard: some View {
        if PowerSampler.hasInternalBattery, let power = monitor.snapshot.power, power.isCharging {
            let tint = PanelMetricColor.yellow(for: colorScheme)
            DashboardCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint)
                            .frame(width: 16)
                        Text(l10n.s.powerCharging)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(power.batteryWatts.map { MetricFormat.watts(abs($0)) } ?? "–")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                    }
                    HStack(spacing: 8) {
                        Text(l10n.s.batteryLabel)
                        Spacer(minLength: 8)
                        Text(power.chargePercent.map { "\($0)%" } ?? "–")
                            .monospacedDigit()
                    }
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    if let adapterWatts = power.adapterWatts {
                        HStack(spacing: 8) {
                            Text(l10n.s.powerAdapter)
                            Spacer(minLength: 8)
                            Text(MetricFormat.watts(adapterWatts))
                                .monospacedDigit()
                        }
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    }
                    if let remaining = power.timeRemainingSeconds.flatMap(BatteryTimeSupport.formatted) {
                        HStack(spacing: 8) {
                            Text(FeatureStrings.batteryTime(l10n.language).title)
                            Spacer(minLength: 8)
                            Text(remaining)
                        }
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    }
                    UsageBar(fraction: power.chargePercent.map { Double($0) / 100 } ?? 0, tint: tint)
                        .frame(height: 6)
                    if monitor.snapshot.batteryHistory.count >= 2 {
                        Sparkline(values: monitor.snapshot.batteryHistory, color: tint, maxValue: 1, lineWidth: 1.4)
                            .frame(height: 48)
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
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
        // The menu-bar circle is laid over the card, not inside its Button's
        // label: a Button nested inside another Button's label never gets its
        // own tap on macOS — the outer one swallows it. An .overlay sits as a
        // true sibling in the view tree, so it keeps its own hit-testing.
        return DashboardCard(action: { openSection(.system) }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 12, weight: .semibold))
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
                    Color.clear.frame(width: 20, height: 20)
                }
                temperatureGraph(snapshot.cpuTemperatureHistory, tint: tint)
                temperatureReadouts(snapshot)
            }
        }
        .overlay(alignment: .topTrailing) {
            DashboardMenuBarToggle(metric: .cpuTemperature)
                .padding(.top, 10)
                .padding(.trailing, 10)
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
                .frame(height: 56)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(colorScheme == .light ? 0.07 : 0.10))
                )
                .overlay(alignment: .topLeading) {
                    // Equal readings (e.g. right after launch, one sample in)
                    // would print the same number twice; wait for the graph
                    // to actually say something before labeling its ends.
                    if high > low {
                        graphLabel(MetricFormat.temperatureCompact(high, unit: unit))
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if high > low {
                        graphLabel(MetricFormat.temperatureCompact(low, unit: unit))
                    }
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

    // MARK: Cards

    /// The card order in the user's saved order; `PanelLayout` fills in any
    /// card the saved order omits, in its canonical position, so a card can
    /// never silently disappear from the editor.
    private var orderedTiles: [PanelDashboardTile] {
        _ = cardOrderRaw
        return PanelLayout.itemOrder(PanelDashboardTile.self, key: DefaultsKey.panelDashboardOrder)
    }

    private func availableTiles(sections: [PanelSectionID]) -> [PanelDashboardTile] {
        orderedTiles.filter { $0.isAvailable(sections: sections) }
    }

    private func isTileShown(_ tile: PanelDashboardTile) -> Bool {
        switch tile {
        case .cpu: return showCPU
        case .memory: return showMemory
        case .storage: return showStorage
        case .network: return showNetwork
        case .gpu: return showGPU
        case .battery: return showBattery
        }
    }

    private func tileVisibilityBinding(_ tile: PanelDashboardTile) -> Binding<Bool> {
        switch tile {
        case .cpu: return $showCPU
        case .memory: return $showMemory
        case .storage: return $showStorage
        case .network: return $showNetwork
        case .gpu: return $showGPU
        case .battery: return $showBattery
        }
    }

    private var tileOrderBinding: Binding<[PanelDashboardTile]> {
        Binding {
            orderedTiles
        } set: { newValue in
            PanelLayout.setItemOrder(newValue, key: DefaultsKey.panelDashboardOrder)
        }
    }

    private func resetCards() {
        PanelLayout.resetItemOrder(key: DefaultsKey.panelDashboardOrder)
        cardOrderRaw = ""
        showCPU = true
        showMemory = true
        showStorage = true
        showNetwork = true
        showGPU = true
        showBattery = true
    }

    @ViewBuilder
    private var cardsSection: some View {
        let available = availableTiles(sections: sections)
        if !available.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    sectionTitle(l10n.s.monitorDashboardCardsSection)
                    Spacer(minLength: 0)
                    if editingCards {
                        cardsResetButton
                    }
                    cardsEditButton
                }
                .padding(.leading, 2)
                ForEach(available.filter { editingCards || isTileShown($0) }) { tile in
                    PanelReorderableItem(item: tile,
                                         isEnabled: editingCards,
                                         order: tileOrderBinding,
                                         dragging: $draggingTile) {
                        tileView(tile, editing: editingCards)
                    }
                }
            }
        }
    }

    private var cardsEditButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                editingCards.toggle()
                if editingCards { expandedTile = nil }
            }
        } label: {
            if editingCards {
                Label(l10n.s.uninstallerDoneTitle, systemImage: "checkmark")
                    .font(.system(size: 10.5, weight: .bold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 18)
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(editingCards ? Color.white : Color.secondary)
        .background(
            RoundedRectangle(cornerRadius: editingCards ? 8 : 6, style: .continuous)
                .fill(editingCards ? Color.accentColor : Color.clear)
        )
        .help(editingCards ? l10n.s.uninstallerDoneTitle : l10n.s.menuEdit)
    }

    private var cardsResetButton: some View {
        Button(action: resetCards) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 10.5, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.07))
        )
        .help(l10n.s.mixerOutputDefault)
    }

    @ViewBuilder
    private func tileView(_ tile: PanelDashboardTile, editing: Bool) -> some View {
        let snapshot = monitor.snapshot
        let open = { toggleExpanded(tile) }
        let visibility = tileVisibilityBinding(tile)
        switch tile {
        case .cpu:
            // A fixed identity color, not .accentColor: CPU's own color has
            // to stay itself regardless of the system accent, or a red accent
            // (a legitimate, common choice) makes ordinary CPU load look like
            // a standing warning every time the card is glanced at.
            let cpuTint = PanelMetricColor.blue(for: colorScheme)
            DashboardMetricTile(title: l10n.s.cpuLabel,
                                systemImage: "cpu",
                                accent: cpuTint,
                                value: snapshot.cpuUsage.map(MetricFormat.percent) ?? "–",
                                valueColor: snapshot.cpuUsage.map { metricValueColor(cpuTint, $0, for: colorScheme) },
                                caption: "\(l10n.s.systemUptime) \(SystemSection.uptimeString())",
                                bar: (snapshot.cpuUsage ?? 0, nil),
                                graph: graphCPU ? (snapshot.cpuHistory, cpuTint, 1) : nil,
                                menuBarMetric: tile.menuBarMetric,
                                detailKind: tile.detailKind,
                                isExpanded: expandedTile == tile,
                                isEditing: editing,
                                visibility: visibility,
                                action: open)
        case .gpu:
            let tint = PanelMetricColor.cyan(for: colorScheme)
            DashboardMetricTile(title: l10n.s.gpuLabel,
                                systemImage: "rectangle.connected.to.line.below",
                                accent: tint,
                                value: snapshot.gpuUsage.map(MetricFormat.percent) ?? "–",
                                valueColor: snapshot.gpuUsage.map { metricValueColor(tint, $0, for: colorScheme) },
                                caption: snapshot.gpuTemperature.map { MetricFormat.temperature($0, unit: unit) },
                                bar: (snapshot.gpuUsage ?? 0, nil),
                                graph: graphGPU ? (snapshot.gpuHistory, tint, 1) : nil,
                                menuBarMetric: tile.menuBarMetric,
                                detailKind: tile.detailKind,
                                isExpanded: expandedTile == tile,
                                isEditing: editing,
                                visibility: visibility,
                                action: open)
        case .memory:
            let used = MonitorMemoryMetric.current.value(in: snapshot)
            let total = snapshot.memoryTotal
            let fraction = used.flatMap { used in
                total.flatMap { $0 > 0 ? Double(used) / Double($0) : nil }
            }
            // Memory already carries a kernel-driven pressure color; that is a
            // better signal than a flat usage threshold, so it stands in for
            // the warming rule the other cards use on their value text.
            let tint = snapshot.memoryPressure.panelColor(for: colorScheme)
            DashboardMetricTile(title: l10n.s.memorySection,
                                systemImage: "memorychip",
                                accent: tint,
                                value: fraction.map(MetricFormat.percent) ?? "–",
                                caption: used.flatMap { used in
                                    total.map { "\(MetricFormat.bytes(used)) / \(MetricFormat.bytes($0))" }
                                },
                                bar: (fraction ?? 0, nil),
                                graph: graphMemory ? (MonitorMemoryMetric.current.history(in: snapshot), tint, 1) : nil,
                                menuBarMetric: tile.menuBarMetric,
                                detailKind: tile.detailKind,
                                isExpanded: expandedTile == tile,
                                isEditing: editing,
                                visibility: visibility,
                                action: open)
        case .storage:
            let disk = primaryDisk(in: snapshot)
            // Same reasoning as CPU: storage keeps its own identity color
            // rather than riding the system accent.
            let storageTint = PanelMetricColor.orange(for: colorScheme)
            DashboardMetricTile(title: l10n.s.diskSection,
                                systemImage: "internaldrive",
                                accent: storageTint,
                                value: disk.map { MetricFormat.percent($0.usedFraction) } ?? "–",
                                valueColor: disk.map { metricValueColor(storageTint, $0.usedFraction, for: colorScheme) },
                                captionRow: disk.map { (l10n.s.diskAvailable, MetricFormat.diskBytes($0.freeBytes)) },
                                bar: (disk?.usedFraction ?? 0, nil),
                                menuBarMetric: tile.menuBarMetric,
                                detailKind: tile.detailKind,
                                isExpanded: expandedTile == tile,
                                isEditing: editing,
                                visibility: visibility,
                                action: open)
        case .battery:
            let power = snapshot.power
            let charge = power?.chargePercent
            let fraction = charge.map { Double($0) / 100 }
            // Low battery is the danger direction here, the opposite of every
            // other card, so it keeps its own low-is-red tint rather than the
            // shared high-is-red warming rule.
            let tint = batteryTint(fraction)
            DashboardMetricTile(title: l10n.s.batteryLabel,
                                systemImage: batterySymbol(power),
                                accent: tint,
                                value: charge.map { "\($0)%" } ?? "–",
                                caption: batteryCaption(power),
                                bar: (fraction ?? 0, nil),
                                graph: graphBattery ? (snapshot.batteryHistory, tint, 1) : nil,
                                menuBarMetric: tile.menuBarMetric,
                                detailKind: tile.detailKind,
                                isExpanded: expandedTile == tile,
                                isEditing: editing,
                                visibility: visibility,
                                action: open)
        case .network:
            let tint = PanelMetricColor.green(for: colorScheme)
            DashboardMetricTile(title: l10n.s.networkSection,
                                systemImage: "network",
                                accent: tint,
                                value: snapshot.netDownBytesPerSec.map { "↓ \(MetricFormat.bytesPerSecCompact($0))" } ?? "–",
                                caption: snapshot.netUpBytesPerSec.map { "↑ \(MetricFormat.bytesPerSecCompact($0))" },
                                graph: graphNetwork ? (snapshot.netDownHistory, tint, nil) : nil,
                                menuBarMetric: tile.menuBarMetric,
                                detailKind: tile.detailKind,
                                isExpanded: expandedTile == tile,
                                isEditing: editing,
                                visibility: visibility,
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

// MARK: - Building blocks

/// A tappable content card. Cards hold readings, so they keep the quiet card
/// fill rather than glass (glass is for the controls that sit on content),
/// and answer the pointer with a light wash.
private struct DashboardCard<Label: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false
    /// Nil for a card that only ever displays, like the charging summary —
    /// no button, no hover wash, matching MacTelemetry's own cards, which
    /// carry no tap action at all.
    var action: (() -> Void)? = nil
    @ViewBuilder let label: () -> Label

    private let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

    var body: some View {
        if let action {
            Button(action: action) { cardBody }
                .buttonStyle(.plain)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        label()
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(shape.fill(PanelSurface.cardFill(for: colorScheme)))
            .overlay(shape.fill(Color.primary.opacity(hovering ? 0.045 : 0)))
            .overlay(shape.strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.7))
            .contentShape(shape)
    }
}

/// A value's color warms as its fraction climbs, independent of the card's
/// identity color: the accent normally, orange from 75%, red from 90%.
func metricValueColor(_ accent: Color, _ fraction: Double, for scheme: ColorScheme) -> Color {
    if fraction >= 0.9 { return PanelMetricColor.red(for: scheme) }
    if fraction >= 0.75 { return PanelMetricColor.orange(for: scheme) }
    return accent
}

/// A small circle beside a card's value: filled when that reading is shown
/// next to the menu bar icon, empty when it isn't — the same switch as the
/// Menu bar settings page's per-metric list, one tap away from the card
/// itself, exactly as its counterpart sits next to every value.
struct DashboardMenuBarToggle: View {
    @ObservedObject private var l10n = L10n.shared
    let metric: MenuBarMetric
    @AppStorage private var shown: Bool

    init(metric: MenuBarMetric) {
        self.metric = metric
        _shown = AppStorage(wrappedValue: false, metric.defaultsKey)
    }

    var body: some View {
        Button {
            shown.toggle()
        } label: {
            Image(systemName: shown ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundStyle(shown ? Color.accentColor : Color.secondary.opacity(0.45))
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(shown ? l10n.s.panelHideItem : l10n.s.panelShowItem)
        .accessibilityLabel(shown ? l10n.s.panelHideItem : l10n.s.panelShowItem)
    }
}

/// One full-width dashboard card: icon, title, the live value and its
/// menu-bar tick on one row; a progress bar; an optional history graph,
/// only while its Settings → Monitor graph switch is on; then a caption. In
/// its list's edit mode it collapses to a single compact row (drag handle,
/// name, eye button) like every other reorderable list in the panel, instead
/// of dragging a live graph.
private struct DashboardMetricTile: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false

    let title: String
    let systemImage: String
    let accent: Color
    let value: String
    /// Defaults to `accent`; pass a warmed color for values worth flagging
    /// at high usage (`metricValueColor`).
    var valueColor: Color? = nil
    var caption: String? = nil
    /// A label/value pair, right-aligned, for a caption that is itself a
    /// reading rather than a sentence (e.g. "Available" / "13.9 GB").
    var captionRow: (label: String, value: String)? = nil
    /// The fraction bar under the header row; nil for readings with no
    /// natural 0...1 bound, like a network rate.
    var bar: (fraction: Double, tint: Color?)? = nil
    /// The optional history graph under the bar, already gated by the
    /// matching Settings → Monitor toggle; nil hides it outright.
    var graph: (values: [Double], color: Color, maxValue: Double?)? = nil
    let menuBarMetric: MenuBarMetric
    /// What a tap expands, embedded (no nested card, no repeated headline
    /// value) right under the header rather than swapped in from outside.
    let detailKind: MetricDetailKind
    var isExpanded = false
    var isEditing = false
    var visibility: Binding<Bool>? = nil
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

    var body: some View {
        if isEditing {
            editingRow
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Only the collapsed header/bar/graph/caption is the tap
                // target: expanding reveals plain rows, not a second button,
                // so nothing below can be mistaken for another card to tap.
                Button(action: action) {
                    content
                        .contentShape(Rectangle())
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(hovering ? 0.045 : 0))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)

                if isExpanded {
                    MetricDetailView(kind: detailKind, style: .embedded)
                        .padding(.top, 8)
                        // Grows out of the header rather than fading in flat:
                        // scaled down from the top edge, so it visibly
                        // unfolds from the row that opened it, and the same
                        // shape in reverse on collapse.
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(shape.fill(PanelSurface.cardFill(for: colorScheme)))
            .overlay(shape.strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.7))
            .clipShape(shape)
            .overlay(alignment: .topTrailing) {
                // Same reasoning as the Thermal card: the circle is a sibling
                // overlay, not nested inside the header's own Button, or
                // macOS SwiftUI hands its taps to the outer button instead.
                DashboardMenuBarToggle(metric: menuBarMetric)
                    .padding(.top, 10)
                    .padding(.trailing, 10)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(valueColor ?? accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Color.clear.frame(width: 20, height: 20)
            }
            if let bar {
                UsageBar(fraction: bar.fraction, tint: bar.tint ?? accent)
                    .frame(height: 6)
            }
            if let graph, graph.values.count >= 2 {
                Sparkline(values: graph.values, color: graph.color, maxValue: graph.maxValue, lineWidth: 1.4)
                    .frame(height: 48)
            }
            if let captionRow {
                HStack(spacing: 8) {
                    Text(captionRow.label)
                    Spacer(minLength: 8)
                    Text(captionRow.value)
                        .monospacedDigit()
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            } else if let caption {
                Text(caption)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private var editingRow: some View {
        HStack(spacing: 9) {
            PanelDragHandle()
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isHidden ? .secondary : accent)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isHidden ? .secondary : .primary)
            Spacer(minLength: 0)
            if isHidden {
                PanelHiddenBadge()
            }
            if let visibility {
                PanelInlineHideButton(isVisible: visibility)
            }
        }
        .panelCard()
    }

    private var isHidden: Bool { visibility?.wrappedValue == false }
}

extension View {
    /// Liquid Glass for a control sitting on the panel (a chip, a tile, a
    /// back button), on macOS 26 with the Liquid Glass setting on. Everywhere
    /// else it falls back to the raised fill the panel's controls already use.
    func panelGlassControl<S: InsettableShape>(in shape: S) -> some View {
        modifier(PanelGlassControlModifier(shape: shape))
    }

    /// Groups two or more adjacent `panelGlassControl` views (the search and
    /// settings buttons sitting side by side, say) under one shared Liquid
    /// Glass sampling region. Apple's guidance is explicit that glass cannot
    /// sample glass: without this, each control blurs the desktop behind the
    /// whole popover independently instead of reading its neighbor's edge the
    /// way one real pane of glass would. Below macOS 26 this is a pass-through.
    @ViewBuilder
    func panelGlassGroup() -> some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 6) { self }
        } else {
            self
        }
#else
        self
#endif
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
    /// Everything either side needs: an expanded card's full detail rides
    /// along with whatever the collapsed dashboard already samples.
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
