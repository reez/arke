//
//  UnifiedDestinationDisplayView.swift
//  Arké
//
//  Created by Christoph on 11/19/25.
//

import SwiftUI

struct UnifiedDestinationDisplayView: View {
    let primaryDisplayDestination: DisplayDestination?
    let alternativeDisplayDestinations: [DisplayDestination]
    let primaryDestinationLabel: String
    let isSimpleAddress: Bool
    
    @Binding var isAlternativesExpanded: Bool
    @Binding var selectedDestinationId: UUID?
    
    private var hasAlternativeDestinations: Bool {
        !alternativeDisplayDestinations.isEmpty
    }
    
    var body: some View {
        if let primaryDisplay = primaryDisplayDestination {
            VStack(spacing: 10) {
                // Header with label and optional expand button (skip for simple addresses)
                if !isSimpleAddress {
                    HStack {
                        Text(primaryDestinationLabel)
                            .font(.title2)
                        
                        Spacer()
                        
                        if hasAlternativeDestinations {
                            Button(action: {
                                withAnimation {
                                    isAlternativesExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: isAlternativesExpanded ? "chevron.up" : "chevron.down")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                    Text("View options (\(alternativeDisplayDestinations.count + 1))")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                VStack(spacing: 10) {
                    // Primary destination row
                    PaymentDestinationItem(
                        formatName: primaryDisplay.destination.format.displayName,
                        shortAddress: primaryDisplay.destination.shortAddress,
                        estimatedFee: primaryDisplay.estimatedFee,
                        isSelectable: isAlternativesExpanded,
                        isSelected: selectedDestinationId == primaryDisplay.destination.id,
                        onTap: {
                            selectedDestinationId = primaryDisplay.destination.id
                        },
                        contactName: primaryDisplay.matchedContact?.displayName,
                        contactAvatar: primaryDisplay.matchedContact?.avatarData
                    )
                    
                    // Alternative destinations (when expanded)
                    if isAlternativesExpanded {
                        ForEach(alternativeDisplayDestinations, id: \.destination.id) { displayDest in
                            PaymentDestinationItem(
                                formatName: displayDest.destination.format.displayName,
                                shortAddress: displayDest.destination.shortAddress,
                                estimatedFee: displayDest.estimatedFee,
                                isSelectable: true,
                                isSelected: selectedDestinationId == displayDest.destination.id,
                                onTap: {
                                    withAnimation {
                                        selectedDestinationId = displayDest.destination.id
                                        isAlternativesExpanded = false
                                    }
                                },
                                contactName: displayDest.matchedContact?.displayName,
                                contactAvatar: displayDest.matchedContact?.avatarData
                            )
                        }
                    }
                }
            }
        }
    }
}
