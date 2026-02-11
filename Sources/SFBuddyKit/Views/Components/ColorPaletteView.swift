//
//  ColorPalettePopoverView.swift
//  SFBuddyKit
//
//  Created by Lorenzo Wood on 2/10/26.
//

import SwiftUI

struct ColorPaletteView: View {
    @Binding var selectedColor: Color

    private let firstRow: [(String, Color)] = [
        ("Red", .red),
        ("Orange", .orange),
        ("Yellow", .yellow),
        ("Green", .green),
        ("Mint", .mint),
        ("Teal", .teal),
        ("Cyan", .cyan),
        ("Blue", .blue)
    ]
    
    private let secondRow: [(String, Color)] = [
        ("Indigo", .indigo),
        ("Purple", .purple),
        ("Pink", .pink),
        ("Brown", .brown),
        ("Gray", .gray),
        ("Primary", .primary),
        ("Secondary", .secondary)
    ]
    
    var body: some View {
        Menu {
            ControlGroup {
                ForEach(firstRow, id: \.0) { colorName, color in
                    Button {
                        selectedColor = color
                    } label: {
                        Label(colorName, systemImage: selectedColor == color ? "circle.fill" : "circle")
                    }
                    .tint(color)
                }
            }
            .controlGroupStyle(.palette)
            
            ControlGroup {
                ForEach(secondRow, id: \.0) { colorName, color in
                    Button {
                        selectedColor = color
                    } label: {
                        Label(colorName, systemImage: selectedColor == color ? "circle.fill" : "circle")
                    }
                    .tint(color)
                }
            }
            .controlGroupStyle(.palette)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(selectedColor)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .strokeBorder(.primary.opacity(0.3), lineWidth: 0.5)
                    )
                Text("Colors")
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selectedColor: Color = .blue
    
    ColorPaletteView(selectedColor: $selectedColor)
        .padding()
}
