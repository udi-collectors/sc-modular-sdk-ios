//  Copyright (c) Experian, 2026. All rights reserved.
//
//  MainViewModel.swift
//  sc-ref-impl-swift
//
//  Created by Rafael Pires on 03/03/26.
//

import SwiftUI
import Core

enum ViewState {
    case loading
    case succeded
    case failed
    case `void`
}

@Observable class MainViewModel: ObservableObject {

    var payload: String = ""
    var payloadDi: String = ""
    var viewState: ViewState = .void
    var errorMessage: String?
    
    private let modularSDK = ModularOrchestrator.shared
    
    func startCollect() async {
        do {
            payload = "Collecting..."
            payloadDi = "Collecting DI..."
            try await modularSDK.startCollect()
            payload = "Collected"
            payloadDi = "DI Collected"
        } catch {
            
        }
    }
    
    func endCollect() {
        Task {
            let result = await modularSDK.endCollect()
            
            payload = result.value(ModuleKeys.udi)?.payload ?? ""
            payloadDi = result.value(ModuleKeys.di)?.0 ?? ""
        }
    }
    
    func config() async {
        do {
            payload = "Configuring..."
            payloadDi = "Configuring..."
            try await modularSDK.configure { builder in
                builder.setConfig(for: ModuleKeys.udi, config: UDIConfig(url: "teste teste"))
                builder.setConfig(for: ModuleKeys.di, config: nil)
            }
            payload = "Configured."
            payloadDi = "Configured"
        } catch {
            
        }
        
    }
    
    func initialize() async {
        payload = "Initializing..."
        await modularSDK.initialize()
        payload = "Initialized"
    }
    
    
    func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
    
}
