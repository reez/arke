//
//  SheetDestinationDisplayView.swift
//  Arké
//
//  Created by Christoph on 11/19/25.
//

import SwiftUI

struct SheetDestinationDisplayView: View {
    let primaryDisplayDestination: DisplayDestination?
    let alternativeDisplayDestinations: [DisplayDestination]
    let primaryDestinationLabel: String
    let isSimpleAddress: Bool
    let showMatchedContact: Bool
    let formatNameOverride: String?
    
    @Binding var selectedDestinationId: UUID?
    @State private var isSheetPresented = false
    
    private var hasAlternativeDestinations: Bool {
        !alternativeDisplayDestinations.isEmpty
    }
    
    var body: some View {
        if let primaryDisplay = primaryDisplayDestination {
            VStack(spacing: 10) {
                /*
                // Header with label (skip for simple addresses)
                if !isSimpleAddress {
                    HStack {
                        Text(primaryDestinationLabel)
                            .font(.title2)
                        
                        Spacer()
                    }
                }
                */
                
                // Primary/Selected destination display
                Button {
                    if hasAlternativeDestinations {
                        isSheetPresented = true
                    }
                } label: {
                    PaymentDestinationItem(
                        formatName: formatNameOverride ?? primaryDisplay.destination.format.simplifiedDisplayName,
                        shortAddress: primaryDisplay.destination.shortAddress,
                        estimatedFee: nil, // primaryDisplay.estimatedFee
                        isSelectable: false,
                        isSelected: false,
                        onTap: {},
                        contactName: primaryDisplay.matchedContact?.displayName,
                        contactAvatar: primaryDisplay.matchedContact?.avatarData,
                        viable: primaryDisplay.viable,
                        viabilityReason: primaryDisplay.viabilityReason,
                        showMatchedContact: showMatchedContact
                    )
                    .overlay(alignment: .trailing) {
                        if hasAlternativeDestinations {
                            Image(systemName: "chevron.down")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.trailing, 20)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!hasAlternativeDestinations)
            }
            .sheet(isPresented: $isSheetPresented) {
                DestinationSelectionSheet(
                    allDestinations: [primaryDisplay] + alternativeDisplayDestinations,
                    selectedDestinationId: $selectedDestinationId,
                    showMatchedContact: showMatchedContact,
                    onDismiss: {
                        isSheetPresented = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Destination Selection Sheet

private struct DestinationSelectionSheet: View {
    let allDestinations: [DisplayDestination]
    @Binding var selectedDestinationId: UUID?
    let showMatchedContact: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(allDestinations, id: \.destination.id) { displayDest in
                        Button {
                            selectedDestinationId = displayDest.destination.id
                            onDismiss()
                        } label: {
                            PaymentDestinationItem(
                                formatName: displayDest.destination.format.simplifiedDisplayName,
                                shortAddress: displayDest.destination.shortAddress,
                                estimatedFee: displayDest.estimatedFee,
                                isSelectable: true,
                                isSelected: selectedDestinationId == displayDest.destination.id,
                                onTap: {
                                    selectedDestinationId = displayDest.destination.id
                                    onDismiss()
                                },
                                contactName: displayDest.matchedContact?.displayName,
                                contactAvatar: displayDest.matchedContact?.avatarData,
                                viable: displayDest.viable,
                                viabilityReason: displayDest.viabilityReason,
                                showMatchedContact: showMatchedContact
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!displayDest.viable)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Payment Method")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                /*
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
                */
            }
        }
    }
}

#Preview("Single Destination") {
    @Previewable @State var selectedId: UUID? = UUID()
    
    let destination = PaymentDestination(
        format: .bitcoin,
        network: .signet,
        address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
    )
    
    let displayDest = DisplayDestination(
        destination: destination,
        estimatedFee: 250,
        balanceSourceName: "Bitcoin",
        matchedContact: nil,
        viable: true,
        viabilityReason: "Available",
        availableBalance: nil
    )
    
    SheetDestinationDisplayView(
        primaryDisplayDestination: displayDest,
        alternativeDisplayDestinations: [],
        primaryDestinationLabel: "Address",
        isSimpleAddress: true,
        showMatchedContact: true,
        formatNameOverride: nil,
        selectedDestinationId: $selectedId
    )
    .padding()
}

#Preview("Multiple Destinations") {
    @Previewable @State var selectedId: UUID? = UUID()
    
    let primary = PaymentDestination(
        format: .bitcoin,
        network: .signet,
        address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
    )
    
    let alt1 = PaymentDestination(
        format: .ark,
        network: .signet,
        address: "tark1pm6sr0fpzqqpu4k5llkn6wdswx48fwjjujgu4gm679lqwudrzghz7a2rx7wuup9cpqq6ssw20"
    )
    
    let alt2 = PaymentDestination(
        format: .lightningInvoice,
        network: .signet,
        address: "lnbc10u1p3pj257pp5yztkwjcz5ftl5laxkav23zmzekaw37zk6kmv80pk4xaev5qhtz7qdqqcqzpgxqyz5vqsp5usyc4lk9chsfp53kvcnvq456szcrzt6aedw3njzdmy0xdkk2lryfrsq9qyyssqd93t9qn7gm3r9uj4k7t9kqvwk7l0v4r"
    )
    
    let primaryDisplay = DisplayDestination(
        destination: primary,
        estimatedFee: 250,
        balanceSourceName: "Bitcoin",
        matchedContact: nil,
        viable: true,
        viabilityReason: "Available",
        availableBalance: 100000
    )
    
    let alt1Display = DisplayDestination(
        destination: alt1,
        estimatedFee: 0,
        balanceSourceName: "Ark",
        matchedContact: nil,
        viable: true,
        viabilityReason: "Available",
        availableBalance: 50000
    )
    
    let alt2Display = DisplayDestination(
        destination: alt2,
        estimatedFee: 50,
        balanceSourceName: "Lightning",
        matchedContact: nil,
        viable: false,
        viabilityReason: "Ark server not connected",
        availableBalance: nil
    )
    
    SheetDestinationDisplayView(
        primaryDisplayDestination: primaryDisplay,
        alternativeDisplayDestinations: [alt1Display, alt2Display],
        primaryDestinationLabel: "Address",
        isSimpleAddress: false,
        showMatchedContact: true,
        formatNameOverride: nil,
        selectedDestinationId: $selectedId
    )
    .padding()
}
