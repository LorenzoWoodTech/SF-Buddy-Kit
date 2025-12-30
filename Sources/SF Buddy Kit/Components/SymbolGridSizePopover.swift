//
//  SymbolGridSizePopover.swift
//  SFBuddyKit
//
//  Created by Lorenzo Wood on 12/1/25.
//


import SwiftUI

public struct SymbolGridSizePopover: View {
    @Binding public var selectedGridSize: SymbolGridSize
    @Environment(\.dismiss) private var dismiss
    
    public init(selectedGridSize: Binding<SymbolGridSize>) {
        self._selectedGridSize = selectedGridSize
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Grid Size")
                .font(.caption)
                .fontWeight(.medium)
            
            VStack(spacing: 4) {
                ForEach(SymbolGridSize.allCases) { size in
                    Button {
                        selectedGridSize = size
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: size.iconName)
                                .font(.caption)
                            Text(size.displayName)
                                .font(.caption)
                            Spacer()
                            if selectedGridSize == size {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(selectedGridSize == size ? Color.accentColor.opacity(0.1) : Color.clear, 
                                   in: RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .frame(minWidth: 140)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}