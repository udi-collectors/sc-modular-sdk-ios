//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ButtonView.swift
//  sc-ref-impl-swift
//
//  Created by Rafael Pires on 03/03/26.
//

import SwiftUI

struct ActionButton: View {
    
    let title: String
    let backgroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .clipShape(Capsule())
        }
    }
}

struct BorderActionButton: View {
    
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )
        }
    }
}
