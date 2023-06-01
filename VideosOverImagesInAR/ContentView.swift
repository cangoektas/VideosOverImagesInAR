//
//  ContentView.swift
//  AR
//
//  Created by Can Göktas on 16.02.23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ARViewContainer {
            EmptyView()
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#if DEBUG
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
#endif
