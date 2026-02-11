//
//  SymbolColorPickerPopover.swift
//  SFBuddyKit
//
//  Created by Lorenzo Wood on 2/10/26.
//


import SwiftUI

struct ColorPalettePopoverView: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss

    private let systemColors: [(String, Color)] = [
        ("Red", .red),
        ("Orange", .orange),
        ("Yellow", .yellow),
        ("Green", .green),
        ("Mint", .mint),
        ("Teal", .teal),
        ("Cyan", .cyan),
        ("Blue", .blue),
        ("Indigo", .indigo),
        ("Purple", .purple),
        ("Pink", .pink),
        ("Brown", .brown),
        ("Gray", .gray),
        ("Primary", .primary),
        ("Secondary", .secondary),
        ("Accent", .accentColor)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(20), spacing: 3), count: 8), spacing: 3) {
                ForEach(systemColors, id: \.0) { colorName, color in
                    Button {
                        selectedColor = color
                        dismiss()
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .strokeBorder(selectedColor == color ? .primary : Color.clear, lineWidth: 1.5)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(.primary.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(colorName)
                }
            }
        }
        .padding(12)
        .frame(width: 200)
        .background(RoundedRectangle(cornerRadius: 6).fill(.regularMaterial))
    }
}
