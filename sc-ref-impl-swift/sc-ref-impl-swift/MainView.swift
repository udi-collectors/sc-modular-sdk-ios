//  Copyright (c) Experian, 2026. All rights reserved.

import SwiftUI
import ModularSDK
import Core

struct MainView: View {
    
    @State var payload: String = ""
    
    @StateObject var viewModel = MainViewModel()
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("ModularSDK - Ref - impl").font(.title)
            HStack {
                ActionButton(title: "Start", backgroundColor: .blue) {
                    Task {
                        await viewModel.startCollect()
                    }
                }
                ActionButton(title: "End", backgroundColor: .blue.opacity(0.5)) {
                    viewModel.endCollect()
                }
                BorderActionButton(title: "Configure") {
                    Task {
                        await viewModel.config()
                        await viewModel.initialize()
                    }
                    
                }
            }
            ForEach(ModulesLoader.modulesLoaded, id: \.self) { sdk in
                CollectorCardView(title: formmat(sdk), content: sdk == "load_collector" ? viewModel.payload : viewModel.payloadDi, action: { payload in
                    viewModel.copy(payload)
                })
            }
            
            
        }
        .padding()
        
    }
    
    private func formmat(_ text: String) -> String {
        return text.replacingOccurrences(of: "load_", with: "").capitalized
    }
}

#Preview {
    MainView()
}
