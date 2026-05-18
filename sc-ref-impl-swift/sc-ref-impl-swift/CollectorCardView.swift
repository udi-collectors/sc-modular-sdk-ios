//  Copyright (c) Experian, 2026. All rights reserved.
//
//  CollectorCardView.swift
//  sc-ref-impl-swift
//
//  Created by Rafael Pires on 03/03/26.
//

import SwiftUI
import UIKit

struct CollectorCardView: View {
    
    let title: String
    let content: String
    let action: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(minHeight: 120, maxHeight: 180)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.4))
            )
            
            HStack {
                Spacer()
                
                Button {
                    action(content)
                } label: {
                    Text("Copy")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
}
