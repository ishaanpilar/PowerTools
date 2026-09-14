// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import SwiftUI

/// First-run experience, also reachable later through Settings › About.
/// The person chooses what they want first; only then does the app explain and
/// request the permissions that choice actually needs.
enum OnboardingMode {
    case full

    func title(_ strings: Strings) -> String {
        strings.obStepWelcomeTitle
    }
}

enum OnboardingStep: CaseIterable {
    case setup, permissions, ai, done
}

struct OnboardingView: View {
    var mode: OnboardingMode = .full
    var onFinish: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Persisted so the flow resumes where it stopped — macOS relaunches the
    /// app when Screen Recording is granted mid-onboarding.
    @AppStorage(DefaultsKey.onboardingStep) private var index = 0
    @State private var selectedFeatures: Set<AppFeature>
    @State private var selectedPreset: FeaturePreset?
    /// Which way the last move went, so the incoming step slides in from the
    /// side the person is heading towards.
    @State private var movingForward = true

    init(mode: OnboardingMode = .full, onFinish: @escaping () -> Void) {
        self.mode = mode
        self.onFinish = onFinish
        let applied = OnboardingProgress.selectionWasApplied()
        _selectedFeatures = State(initialValue: applied
            ? Set(AppFeature.allCases.filter(\.isAvailable))
            : FeaturePreset.essential.features)
        _selectedPreset = State(initialValue: applied ? nil : .essential)
    }

    private var steps: [OnboardingStep] { OnboardingStep.allCases }
    private var current: OnboardingStep { steps[min(max(0, index), steps.count - 1)] }
    private var strings: OnboardingStrings { FeatureStrings.onboarding(l10n.language) }

    private var setupPermissions: [AppPermission] {
        let permissions = Set(selectedFeatures.flatMap(\.onboardingPermissions))
        return [.accessibility, .screenRecording].filter { permissions.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .id(current)
                .transition(stepTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            Rectangle()
                .fill(OnboardingPalette.hairline)
                .frame(height: 1)
            navigationBar
        }
        .frame(width: 780, height: 660)
        .background(OnboardingBackground())
        .environment(\.colorScheme, .dark)
        .onAppear {
            if !steps.indices.contains(index) { index = 0 }
            // Onboarding narrates the permission trip itself; the floating
            // guide card would just double the voice.
            PermissionGuideOverlay.suppressed = true
        }
        .onDisappear {
            PermissionGuideOverlay.suppressed = false
        }
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let edgeIn: Edge = movingForward ? .trailing : .leading
        let edgeOut: Edge = movingForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: edgeIn).combined(with: .opacity),
            removal: .move(edge: edgeOut).combined(with: .opacity))
    }

    @ViewBuilder
    private var content: some View {
        switch current {
        case .setup:
            SetupStep(selectedFeatures: $selectedFeatures, selectedPreset: $selectedPreset)
        case .permissions:
            PermissionsStep(features: selectedFeatures, permissions: setupPermissions)
        case .ai:
            AIPreviewStep()
        case .done:
            DoneStep()
        }
    }

    private var navigationBar: some View {
        ZStack {
            HStack {
                Button(l10n.s.obBack) { move(to: max(0, index - 1)) }
                    .buttonStyle(OnboardingButtonStyle(prominent: false))
                    .opacity(index == 0 ? 0 : 1)
                    .disabled(index == 0)
                    .accessibilityHidden(index == 0)
                Spacer()
                Button(action: advance) {
                    HStack(spacing: 6) {
                        Text(primaryButtonTitle)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(OnboardingButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
            }

            // Centred on the window, not between two buttons of different
            // widths, so it sits still while the primary label changes.
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(steps.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == index ? Theme.brandLime
                                  : i < index ? Theme.brandLime.opacity(0.4)
                                  : Color.white.opacity(0.18))
                            .frame(width: i == index ? 22 : 7, height: 7)
                    }
                }
                Text(String(format: strings.stepFormat, index + 1, steps.count))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .monospacedDigit()
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: index)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var primaryButtonTitle: String {
        current == .done ? String(format: strings.openAppFormat, AppInfo.name) : l10n.s.obContinue
    }

    private func move(to newIndex: Int) {
        movingForward = newIndex > index
        withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.9)) {
            index = newIndex
        }
    }

    private func advance() {
        switch current {
        case .done:
            index = 0
            onFinish()
            // After the window has gone, so the panel is not dismissed by the
            // window's own close.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                appDelegate()?.showMainPanel()
            }
        case .setup:
            FeatureRuntime.shared.replaceAvailable(with: selectedFeatures,
                                                   enabling: selectedPreset?.enableKeys ?? [])
            move(to: OnboardingProgress.firstStepAfterSelection)
        case .permissions, .ai:
            move(to: index + 1)
        }
    }
}

// MARK: - Step 1: set up

/// Presets are quick starts, while the catalog below allows an exact choice.
/// Both use the Features hub's own names and descriptions so setup stays
/// consistent with what the person can change later.
private struct SetupStep: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var selectedFeatures: Set<AppFeature>
    @Binding var selectedPreset: FeaturePreset?
    @State private var choosingFeatures = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }
    private var strings: OnboardingStrings { FeatureStrings.onboarding(l10n.language) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Theme.brandGradient)
                            .frame(width: 56, height: 56)
                            .overlay(BrandMark(width: 32))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .accessibilityHidden(true)
                        Text(strings.setupTitle)
                            .font(.system(size: 28, weight: .bold))
                            .accessibilityAddTraits(.isHeader)
                    }

                    VStack(spacing: 8) {
                        ForEach(FeaturePreset.allCases) { preset in
                            presetCard(preset)
                        }
                    }

                    VStack(spacing: 8) {
                        featureChooser
                        launchAtLoginCard
                    }
                }
                .frame(width: 460)
                .frame(maxWidth: .infinity)
                .padding(.top, 44)
                .padding(.bottom, 20)
            }

            LanguageMenu()
                .padding(.top, 20)
                .padding(.trailing, 24)
        }
    }

    // MARK: Presets

    private func name(_ preset: FeaturePreset) -> String {
        switch preset {
        case .essential: return hub.presetEssentialName
        case .windows: return hub.presetWindowsName
        case .battery: return hub.presetBatteryName
        }
    }

    private func caption(_ preset: FeaturePreset) -> String {
        switch preset {
        case .essential: return hub.presetEssentialDesc
        case .windows: return hub.presetWindowsDesc
        case .battery: return hub.presetBatteryDesc
        }
    }

    /// One glyph per distinct feature in catalog order, so the row reads the
    /// same every time.
    private func symbols(_ preset: FeaturePreset) -> [String] {
        var seen = Set<String>()
        return AppFeature.allCases
            .filter { preset.features.contains($0) }
            .map(\.symbolName)
            .filter { seen.insert($0).inserted }
    }

    private func presetCard(_ preset: FeaturePreset) -> some View {
        let selected = selectedPreset == preset
        return Button {
            selectedPreset = preset
            selectedFeatures = preset.features
        } label: {
            HStack(spacing: 12) {
                OnboardingIconTile(symbol: preset.symbolName,
                                   tint: selected ? Theme.brandLime : OnboardingPalette.secondaryText,
                                   size: 40)
                VStack(alignment: .leading, spacing: 6) {
                    Text(name(preset))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    // What the preset installs, shown rather than described;
                    // the description stays in the accessibility label.
                    HStack(spacing: 9) {
                        ForEach(symbols(preset), id: \.self) { symbol in
                            Image(systemName: symbol)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(OnboardingPalette.secondaryText)
                        }
                    }
                    .accessibilityHidden(true)
                }
                Spacer(minLength: 8)
                SelectionMark(selected: selected, size: 20)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(OnboardingCardButtonStyle(highlighted: selected))
        .accessibilityLabel("\(name(preset)). \(caption(preset))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Choose features myself

    private var featureChooser: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { choosingFeatures.toggle() }
            } label: {
                HStack(spacing: 12) {
                    OnboardingIconTile(symbol: "slider.horizontal.3",
                                       tint: OnboardingPalette.secondaryText, size: 40)
                    Text(strings.chooseMyself)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(String(format: strings.selectedCountFormat, selectedFeatures.count))
                        .font(.system(size: 12))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .rotationEffect(.degrees(choosingFeatures ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(OnboardingRowButtonStyle())
            .accessibilityValue(String(format: strings.selectedCountFormat, selectedFeatures.count))

            if choosingFeatures {
                Rectangle().fill(OnboardingPalette.hairline).frame(height: 1)
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(FeatureGroup.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 2) {
                            OnboardingSectionLabel(CommandBarCatalog.groupTitle(group, hub: hub))
                                .padding(.bottom, 4)
                            ForEach(AppFeature.features(in: group), id: \.self) { feature in
                                featureRow(feature)
                            }
                        }
                    }
                    Text(l10n.s.obPurposeSkip)
                        .font(.system(size: 11.5))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .transition(.opacity)
            }
        }
        .onboardingCard()
    }

    private func featureRow(_ feature: AppFeature) -> some View {
        let selected = selectedFeatures.contains(feature)
        // The picker writes availability through the same runtime gate as the
        // hub, so a feature this Mac cannot run would silently stay off after
        // being ticked here. It is shown and refused instead, exactly as the
        // hub row does it.
        let blocked = feature.installBlockedReason
        let row = Button {
            selectedPreset = nil
            if selected {
                selectedFeatures.remove(feature)
            } else {
                selectedFeatures.insert(feature)
            }
        } label: {
            HStack(spacing: 10) {
                OnboardingIconTile(symbol: feature.symbolName,
                                   tint: selected ? Theme.brandLime : OnboardingPalette.secondaryText,
                                   size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(feature.hubTitle(l10n.s, hub: hub))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(feature.hubDescription(hub))
                        .font(.system(size: 11.5))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                SelectionMark(selected: selected, size: 17)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(OnboardingRowButtonStyle())
        .disabled(blocked != nil)
        .opacity(blocked == nil ? 1 : 0.45)
        .accessibilityLabel("\(feature.hubTitle(l10n.s, hub: hub)). \(feature.hubDescription(hub))"
                            + (blocked.map { ". \($0)" } ?? ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
        // .help() never fires on a disabled control, so the tooltip sits on a
        // wrapper outside it, the same way the Features hub row does it.
        return HStack(spacing: 0) { row }.help(blocked ?? "")
    }

    // MARK: Launch at login

    private var launchAtLoginCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                OnboardingIconTile(symbol: "power", tint: OnboardingPalette.secondaryText, size: 40)
                Text(l10n.s.launchAtLogin)
                    .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 8)
                Toggle(l10n.s.launchAtLogin, isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Theme.brandLime)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLogin.setEnabled(enabled)
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
            }
            if let loginError {
                Label(loginError, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .onboardingCard()
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

/// The app's language, as a compact menu in the corner rather than a form row
/// competing with the setup choices.
private struct LanguageMenu: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Menu {
            Picker(l10n.s.obLanguageLabel, selection: $l10n.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(l10n.language.displayName, systemImage: "globe")
                .font(.system(size: 12, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.07)))
        .overlay(Capsule().strokeBorder(OnboardingPalette.hairline, lineWidth: 1))
        .help(l10n.s.obLanguageLabel)
        .accessibilityLabel(l10n.s.obLanguageLabel)
        .accessibilityValue(l10n.language.displayName)
    }
}

// MARK: - Step 2: permissions

private struct PermissionsStep: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var showingOtherPermissions = false
    let features: Set<AppFeature>
    let permissions: [AppPermission]

    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }
    private var strings: OnboardingStrings { FeatureStrings.onboarding(l10n.language) }
    private var otherPermissions: [AppPermission] {
        AppPermission.allCases.filter { !permissions.contains($0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        BrandHeader()
                        VStack(alignment: .leading, spacing: 8) {
                            Text(strings.permissionsTitle)
                                .font(.system(size: 28, weight: .bold))
                                .accessibilityAddTraits(.isHeader)
                            Text(strings.permissionsBody)
                                .font(.system(size: 13.5))
                                .foregroundStyle(OnboardingPalette.secondaryText)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    PermissionSketch()
                }

                if permissions.isEmpty {
                    HStack(spacing: 14) {
                        OnboardingIconTile(symbol: "checkmark", tint: .green, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(strings.permissionsNoneTitle)
                                .font(.system(size: 14, weight: .semibold))
                            Text(hub.onboardingNoSelectedPermissions)
                                .font(.system(size: 12.5))
                                .foregroundStyle(OnboardingPalette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .onboardingCard()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        OnboardingSectionLabel(hub.onboardingSelectedPermissionsTitle)
                        ForEach(permissions, id: \.self) { permission in
                            OnboardingPermissionCard(permission: permission,
                                                     usedBy: featureNames(for: permission))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    DisclosureGroup(isExpanded: $showingOtherPermissions) {
                        VStack(alignment: .leading, spacing: 14) {
                            PermissionsPortalSections(hub: hub, visiblePermissions: otherPermissions)
                        }
                        .padding(.top, 12)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hub.onboardingOtherPermissionsTitle)
                                .font(.system(size: 14, weight: .semibold))
                            Text(hub.onboardingOtherPermissionsCaption)
                                .font(.system(size: 12))
                                .foregroundStyle(OnboardingPalette.secondaryText)
                        }
                    }
                    .padding(16)
                    .onboardingCard()

                    Label(l10n.s.permissionRestartNote, systemImage: "info.circle")
                        .font(.system(size: 11.5))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
    }

    private func featureNames(for permission: AppPermission) -> String {
        features
            .filter { $0.onboardingPermissions.contains(permission) }
            .map { $0.hubTitle(l10n.s, hub: hub) }
            // Localized: a plain sort orders by Unicode scalar, which throws
            // every accented name past Z.
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .joined(separator: ", ")
    }
}

/// One permission the chosen features need: what it is for, who uses it, and
/// its live state with the way to grant it.
private struct OnboardingPermissionCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var pollingDemandID = UUID()
    let permission: AppPermission
    let usedBy: String

    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }

    private var granted: Bool {
        permission == .accessibility ? permissions.accessibility : permissions.screenRecording
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            OnboardingIconTile(symbol: permission.symbolName,
                               tint: permission == .accessibility ? .blue : .pink,
                               size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(permission.name(hub))
                    .font(.system(size: 14, weight: .semibold))
                Text(permission.explainer(hub))
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(format: FeatureStrings.onboarding(l10n.language).permissionUsedByFormat,
                            usedBy))
                    .font(.system(size: 11.5))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 8) {
                StatusPill(granted: granted,
                           text: granted ? l10n.s.permissionGranted : l10n.s.permissionMissing)
                if !granted {
                    HStack(spacing: 8) {
                        Button(l10n.s.permissionOpenSettings, action: openSettings)
                            .buttonStyle(OnboardingButtonStyle(prominent: false, compact: true))
                        Button(l10n.s.permissionRequest, action: request)
                            .buttonStyle(OnboardingButtonStyle(prominent: true, compact: true))
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: granted)
        }
        .padding(16)
        .onboardingCard(highlighted: granted)
        .onAppear { permissions.setActivePermissionSurface(pollingDemandID, visible: true) }
        .onDisappear { permissions.setActivePermissionSurface(pollingDemandID, visible: false) }
    }

    private func request() {
        if permission == .accessibility {
            permissions.requestAccessibility()
        } else {
            permissions.requestScreenRecording()
        }
    }

    private func openSettings() {
        if permission == .accessibility {
            permissions.openAccessibilitySettings()
        } else {
            permissions.openScreenRecordingSettings()
        }
    }
}

/// The permission's state in words beside the colour, so it never depends on
/// telling green from orange.
private struct StatusPill: View {
    let granted: Bool
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(granted ? Color.green : Color.orange)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.07)))
    }
}

private struct PermissionSketch: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 150, height: 110)
                .blur(radius: 44)
            tile("lock.fill", tint: .white, offset: CGSize(width: -44, height: -10), rotation: -8)
            tile("hand.raised.fill", tint: .blue, offset: CGSize(width: 10, height: 8), rotation: 4)
            tile("checkmark.shield.fill", tint: Theme.brandLime, offset: CGSize(width: 58, height: 26), rotation: 10)
        }
        .frame(width: 190, height: 130)
        .accessibilityHidden(true)
    }

    private func tile(_ symbol: String, tint: Color, offset: CGSize, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(colors: [Color.white.opacity(0.13), Color.white.opacity(0.04)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.9))
            )
            .frame(width: 72, height: 72)
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
    }
}

// MARK: - Step 3: AI preview

/// A preview of AI that is planned but not built. Deliberately without
/// controls: a switch or provider menu here would promise behaviour that does
/// not exist yet.
private struct AIPreviewStep: View {
    @ObservedObject private var l10n = L10n.shared
    private var strings: OnboardingStrings { FeatureStrings.onboarding(l10n.language) }

    var body: some View {
        CenteredScroll {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    OnboardingIconTile(symbol: "sparkles", tint: .purple, size: 52)
                    HStack(spacing: 10) {
                        Text(strings.aiTitle)
                            .font(.system(size: 26, weight: .bold))
                            .accessibilityAddTraits(.isHeader)
                        Text(strings.aiComingSoon)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(OnboardingPalette.purpleText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.purple.opacity(0.2)))
                    }
                    Text(strings.aiBody)
                        .font(.system(size: 13.5))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 480)
                }

                HStack(alignment: .top, spacing: 12) {
                    capability("text.cursor", strings.aiTextTitle, strings.aiTextBody)
                    capability("text.bubble", strings.aiAskTitle, strings.aiAskBody)
                    capability("waveform.path.ecg", strings.aiExplainTitle, strings.aiExplainBody)
                }
                .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 12) {
                    note("cpu", tint: OnboardingPalette.secondaryText,
                         strings.aiWhereTitle, strings.aiWhereBody)
                    note("lock.fill", tint: Theme.brandLime,
                         strings.aiChoiceTitle, strings.aiChoiceBody)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 660)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
    }

    private func capability(_ symbol: String, _ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            OnboardingIconTile(symbol: symbol, tint: OnboardingPalette.purpleText, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onboardingCard()
    }

    private func note(_ symbol: String, tint: Color, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            OnboardingIconTile(symbol: symbol, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onboardingCard()
    }
}

// MARK: - Step 4: done

private struct DoneStep: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var hub: FeatureHubStrings { FeatureStrings.hub(l10n.language) }
    private var strings: OnboardingStrings { FeatureStrings.onboarding(l10n.language) }

    private var installedGroups: [(group: FeatureGroup, count: Int)] {
        _ = features.revision
        return FeatureGroup.allCases.compactMap { group in
            let count = AppFeature.features(in: group).filter(\.isAvailable).count
            return count > 0 ? (group, count) : nil
        }
    }

    var body: some View {
        let total = installedGroups.reduce(0) { $0 + $1.count }
        CenteredScroll {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Theme.brandLime.opacity(0.22))
                        .frame(width: 180, height: 180)
                        .blur(radius: 44)
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Theme.brandGradient)
                        .frame(width: 108, height: 108)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .overlay(BrandMark(width: 58))
                        .shadow(color: Theme.brandLime.opacity(0.35), radius: 24)
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
                        .opacity(appeared || reduceMotion ? 1 : 0)
                }
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(strings.doneTitle)
                        .font(.system(size: 34, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Text(strings.doneBody)
                        .font(.system(size: 14))
                        .foregroundStyle(OnboardingPalette.secondaryText)
                    if total > 0 {
                        Text(String(format: strings.doneInstalledFormat, total))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.brandLime)
                            .monospacedDigit()
                    }
                }

                if !installedGroups.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(installedGroups.prefix(4), id: \.group) { entry in
                            groupTile(entry.group, count: entry.count)
                        }
                    }
                    .frame(maxWidth: 560)
                }

                HStack(spacing: 14) {
                    OnboardingIconTile(symbol: "menubar.arrow.up.rectangle",
                                       tint: Theme.brandLime, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strings.doneFindTitle)
                            .font(.system(size: 14, weight: .semibold))
                        Text(l10n.s.obDoneHint)
                            .font(.system(size: 12))
                            .foregroundStyle(OnboardingPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .onboardingCard(highlighted: true)
                .frame(maxWidth: 560)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
    }

    private func groupTile(_ group: FeatureGroup, count: Int) -> some View {
        VStack(spacing: 8) {
            OnboardingIconTile(symbol: symbol(group), tint: Theme.brandLime, size: 40)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white, .green)
                        .offset(x: 6, y: -6)
                        .accessibilityHidden(true)
                }
            Text(CommandBarCatalog.groupTitle(group, hub: hub))
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .top)
        .onboardingCard()
        .accessibilityElement(children: .combine)
    }

    private func symbol(_ group: FeatureGroup) -> String {
        switch group {
        case .windowsDock: return "macwindow.on.rectangle"
        case .mouseKeyboard: return "keyboard"
        case .clipboardFiles: return "doc.on.clipboard"
        case .sound: return "speaker.wave.2.fill"
        case .energyDisplay: return "bolt.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .monitor: return "gauge.with.dots.needle.50percent"
        }
    }
}

// MARK: - Shared pieces

/// Colours the setup flow shares. Text greys are chosen for contrast on the
/// flow's near-black ground: secondary text stays above 4.5:1.
private enum OnboardingPalette {
    static let secondaryText = Color.white.opacity(0.66)
    static let hairline = Color.white.opacity(0.08)
    static let cardFill = Color.white.opacity(0.045)
    static let cardHover = Color.white.opacity(0.075)
    static let purpleText = Color(red: 0.78, green: 0.62, blue: 1.0)
}

/// Scrolls when content is taller than the step, and centres it vertically
/// when it is not, so short steps do not leave an empty lower half.
private struct CenteredScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height)
            }
        }
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.brandGradient)
                .frame(width: 44, height: 44)
                .overlay(BrandMark(width: 26))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .accessibilityHidden(true)
            Text(AppInfo.name)
                .font(.system(size: 17, weight: .bold))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(OnboardingPalette.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct SelectionMark: View {
    let selected: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(selected ? Theme.brandLime : Color.white.opacity(0.28), lineWidth: 1.5)
            if selected {
                Circle().fill(Theme.brandLime)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(Theme.brandInk)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.15), value: selected)
        .accessibilityHidden(true)
    }
}

private struct OnboardingIconTile: View {
    let symbol: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

private struct OnboardingBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.035, green: 0.04, blue: 0.06),
                                    Color(red: 0.07, green: 0.055, blue: 0.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color.purple.opacity(0.22), .clear],
                           center: .topTrailing, startRadius: 20, endRadius: 420)
            RadialGradient(colors: [Theme.brandLime.opacity(0.06), .clear],
                           center: .bottomLeading, startRadius: 10, endRadius: 360)
        }
        .ignoresSafeArea()
    }
}

/// Capsule buttons for the flow: a lime primary and a quiet secondary, with
/// hover and press feedback that never changes their size in the layout.
private struct OnboardingButtonStyle: ButtonStyle {
    let prominent: Bool
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        StyledButton(configuration: configuration, prominent: prominent, compact: compact)
    }

    private struct StyledButton: View {
        let configuration: ButtonStyleConfiguration
        let prominent: Bool
        let compact: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: compact ? 12 : 14, weight: .semibold))
                .foregroundStyle(prominent ? Theme.brandInk : Color.white)
                .padding(.horizontal, compact ? 12 : 22)
                .padding(.vertical, compact ? 6 : 10)
                .frame(minHeight: compact ? 28 : 40)
                .background(Capsule().fill(fill))
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(prominent ? 0 : 0.12), lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(Capsule())
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: hovering)
        }

        private var fill: Color {
            if prominent {
                return hovering ? Theme.brandLime.opacity(0.88) : Theme.brandLime
            }
            return Color.white.opacity(hovering ? 0.14 : 0.09)
        }
    }
}

/// A whole card that is one choice: hover lifts its fill, press dips it.
private struct OnboardingCardButtonStyle: ButtonStyle {
    let highlighted: Bool

    func makeBody(configuration: Configuration) -> some View {
        CardBody(configuration: configuration, highlighted: highlighted)
    }

    private struct CardBody: View {
        let configuration: ButtonStyleConfiguration
        let highlighted: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(highlighted ? Theme.brandLime.opacity(0.09)
                              : hovering ? OnboardingPalette.cardHover : OnboardingPalette.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(highlighted ? Theme.brandLime.opacity(0.5)
                                      : Color.white.opacity(hovering ? 0.14 : 0.08),
                                      lineWidth: highlighted ? 1.5 : 1)
                )
                .scaleEffect(configuration.isPressed ? 0.99 : 1)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.15), value: hovering)
                .animation(.easeOut(duration: 0.15), value: highlighted)
        }
    }
}

/// A row inside a card: a soft hover fill, no border of its own.
private struct OnboardingRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration)
    }

    private struct RowBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(configuration.isPressed ? 0.08 : hovering ? 0.05 : 0))
                )
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
    }
}

private extension View {
    func onboardingCard(highlighted: Bool = false) -> some View {
        background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(highlighted ? Theme.brandLime.opacity(0.07) : OnboardingPalette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(highlighted ? Theme.brandLime.opacity(0.3) : OnboardingPalette.hairline,
                              lineWidth: 1)
        )
    }
}
