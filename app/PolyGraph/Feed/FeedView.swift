import SwiftUI

/// Tab-ul Noutăți: evenimentele cele mai noi sus. Lista nu se mișcă sub deget: dacă nu e la început,
/// noutățile așteaptă într-o pastilă „3 noutăți ↑” care derulează sus.
struct FeedView: View {
    @Environment(AppStore.self) private var store
    @State private var position = ScrollPosition(edge: .top)

    private var feed: FeedModel { store.feed }

    var body: some View {
        content
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Noutăți")
            .navigationBarTitleDisplayMode(.large)
            .pgSettingsToolbar()
            .refreshable { await feed.poll() }
    }

    @ViewBuilder
    private var content: some View {
        if feed.events.isEmpty && feed.pendingNew.isEmpty {
            if !feed.hasLoaded && feed.lastError == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("feed.loading")
            } else if !feed.hasLoaded, let error = feed.lastError {
                ContentUnavailableView {
                    Label("Nu am putut încărca noutățile", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Încearcă din nou") { Task { await feed.poll() } }
                        .accessibilityIdentifier("feed.retryButton")
                }
                .accessibilityIdentifier("feed.error")
            } else {
                ContentUnavailableView {
                    Label("Nicio noutate încă", systemImage: "bell")
                } description: {
                    Text("Aici apar dozele ratate, alertele noi și ce v-a spus \(store.patient?.name ?? "pacientul").")
                }
                .accessibilityIdentifier("feed.empty")
            }
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.s) {
                ForEach(feed.events) { event in
                    row(event)
                }
            }
            .padding(Spacing.m)
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: Bool.self, of: { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top <= 24
        }, action: { _, atTop in
            feed.setAtTop(atTop)
        })
        .overlay(alignment: .top) {
            if !feed.pendingNew.isEmpty {
                newPill
                    .transition(PgMotion.transition(.move(edge: .top).combined(with: .opacity),
                                                    reduceMotion: PgMotion.isReduceMotionEnabled))
            }
        }
        .pgAnimation(.pgStandard, value: feed.pendingNew.count)
        .accessibilityIdentifier("feed.list")
    }

    @ViewBuilder
    private func row(_ event: FeedEvent) -> some View {
        if let route = route(for: event) {
            NavigationLink(value: route) {
                FeedCard(event: event)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("feed.event.\(event.id)")
        } else {
            FeedCard(event: event)
                .accessibilityIdentifier("feed.event.\(event.id)")
        }
    }

    private func route(for event: FeedEvent) -> CaregiverRoute? {
        if event.type == .checkin { return .checkin(eventID: event.id) }
        if let alertID = event.alertid, store.alert(id: alertID) != nil { return .alert(id: alertID, zoom: false) }
        if let medID = event.medids.first, store.med(id: medID) != nil { return .med(id: medID) }
        return nil
    }

    private var newPill: some View {
        Button {
            feed.showPending()
            withPgAnimation(.pgStandard) { position.scrollTo(edge: .top) }
        } label: {
            Label(Self.countText(feed.pendingNew.count), systemImage: "arrow.up")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.xs)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, Spacing.xs)
        .accessibilityIdentifier("feed.newPill")
    }

    /// „o noutate”, „3 noutăți”, „20 de noutăți”
    static func countText(_ count: Int) -> String {
        switch count {
        case 1: "o noutate"
        case 0, 2...19: "\(count) noutăți"
        default: "\(count) de noutăți"
        }
    }
}

/// Un eveniment din Noutăți: tipul, ora, titlul, simptomele (check-in) și textul.
struct FeedCard: View {
    let event: FeedEvent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Image(systemName: event.type.systemImage)
                    .foregroundStyle(event.severity?.color ?? .secondary)
                    .accessibilityHidden(true)
                Text(event.type.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: Spacing.xs)
                Text(PgFormat.clock(event.at))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Text(event.shortTitle)
                .font(.headline)
                .foregroundStyle(PgColor.textPrimary)
                .multilineTextAlignment(.leading)
            if !event.symptomLabels.isEmpty {
                FlowChips(names: event.symptomLabels)
            }
            Text(event.body)
                .font(.body)
                .foregroundStyle(PgColor.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if let severity = event.severity {
                HStack(spacing: Spacing.xxs) {
                    SeverityDot(severity: severity)
                    Text(severity.label)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Detaliul unui check-in din Noutăți: simptomele, legătura posibilă cu medicamentele și medicamentele.
struct CheckInEventView: View {
    let eventID: String
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if let event = store.feed.event(id: eventID) {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(event.shortTitle)
                                .font(.title3.weight(.semibold))
                            Text("\(PgFormat.longDay(event.at)), ora \(PgFormat.clock(event.at))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !event.symptomLabels.isEmpty {
                                FlowChips(names: event.symptomLabels)
                                    .padding(.top, Spacing.xxs)
                            }
                        }
                        .accessibilityIdentifier("checkinEvent.header")
                    }
                    Section("Ce am observat") {
                        Text(event.body)
                            .accessibilityIdentifier("checkinEvent.body")
                    }
                    if !event.medids.isEmpty {
                        Section("Medicamente") {
                            ForEach(event.medids, id: \.self) { medID in
                                NavigationLink(value: CaregiverRoute.med(id: medID)) {
                                    Text(store.med(id: medID)?.displayName ?? medID)
                                }
                                .accessibilityIdentifier("checkinEvent.med.\(medID)")
                            }
                        }
                    }
                    Section {
                        Text("Nu schimbați singuri tratamentul. Întrebați medicul sau farmacistul.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView("Evenimentul nu mai e în listă", systemImage: "bell.slash")
            }
        }
        .navigationTitle("Check-in")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("checkinEvent")
    }
}
