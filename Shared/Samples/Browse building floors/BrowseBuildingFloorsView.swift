// Copyright 2022 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArcGIS
import ArcGISToolkit
import SwiftUI

struct BrowseBuildingFloorsView: View {
    /// A Boolean value indicating whether to show an alert.
    @State private var isShowingAlert = false
    
    /// The error shown in the alert.
    @State private var error: Error? {
        didSet { isShowingAlert = error != nil }
    }
    
    /// The current viewpoint of the map.
    @State private var viewpoint: Viewpoint?
    
    /// A Boolean value indicating whether the map is being navigated.
    @State private var isMapNavigating = false
    
    /// A Boolean value indicating whether the map is loaded.
    @State private var isMapLoaded = false
    
    /// The model used to store the geo model and other expensive objects
    /// used in this view.
    private class Model: ObservableObject {
        /// A floor-aware web map of Building L on the Esri Redlands campus.
        let map = Map(
            item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: .esriBuildingL
            )
        )
    }
    
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        MapView(map: model.map)
            .onViewpointChanged(kind: .centerAndScale) { viewpoint = $0 }
            .onNavigatingChanged { isMapNavigating = $0 }
            .alert(isPresented: $isShowingAlert, presentingError: error)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .overlay(alignment: .bottomTrailing) {
                if isMapLoaded,
                   let floorManager = model.map.floorManager {
                    FloorFilter(
                        floorManager: floorManager,
                        alignment: .bottomTrailing,
                        viewpoint: $viewpoint,
                        isNavigating: $isMapNavigating
                    )
                    .frame(
                        maxWidth: 400,
                        maxHeight: 400
                    )
                    .padding(.toolkitDefault)
                    .padding(.bottom, 27)
                }
            }
            .task {
                do {
                    try await model.map.load()
                    isMapLoaded = true
                } catch {
                    self.error = error
                }
            }
    }
}

private extension PortalItem.ID {
    /// A portal item of Building L's floors on the Esri Redlands campus.
    static var esriBuildingL: Self { Self("f133a698536f44c8884ad81f80b6cfc7")! }
}
