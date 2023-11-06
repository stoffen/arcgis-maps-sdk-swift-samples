// Copyright 2023 Esri
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
import SwiftUI
import UniformTypeIdentifiers

struct FindRouteInMobileMapPackageView: View {
    /// The view model for the view.
    @StateObject private var model = Model()
    
    /// A Boolean value indicating whether the file importer interface is showing.
    @State private var fileImporterIsShowing = false
    
    /// The file URLs imported from the file importer pointing to local "mmpk" files.
    @State private var importedFileURLs: [URL]?
    
    var body: some View {
        List {
            // Create a list section for each map package.
            ForEach(model.mapPackages.enumeratedArray(), id: \.offset) { (offset, mapPackage) in
                Section {
                    MobileMapListView(mapPackage: mapPackage)
                } header: {
                    Text(mapPackage.item?.title.titleCased ?? "Mobile Map Package \(offset + 1)")
                }
            }
        }
        .toolbar {
            // The button used to import mobile map packages.
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Add Package") {
                    fileImporterIsShowing = true
                }
                .fileImporter(
                    isPresented: $fileImporterIsShowing,
                    allowedContentTypes: [.mmpk],
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let fileURLs):
                        importedFileURLs = fileURLs
                    case .failure(let error):
                        model.error = error
                    }
                }
            }
        }
        .task {
            // When the sample first loads, load all the mobile map packages in the bundle.
            guard model.mapPackages.isEmpty,
                  let bundleMapPackageURLs = Bundle.main.urls(
                    forResourcesWithExtension: "mmpk",
                    subdirectory: nil
                  )
            else { return }
            
            await model.addMapPackages(from: bundleMapPackageURLs)
        }
        .task(id: importedFileURLs) {
            // When new file URLs are imported, use them to import the mobile map package.
            guard let importedFileURLs else { return }
            
            await model.importMapPackages(from: importedFileURLs)
            self.importedFileURLs = nil
        }
        .alert(isPresented: $model.errorAlertIsShowing, presentingError: model.error)
    }
}

private extension FindRouteInMobileMapPackageView {
    /// A list of the maps in a given map package.
    struct MobileMapListView: View {
        /// The mobile map package containing the maps.
        let mapPackage: MobileMapPackage
        
        var body: some View {
            // Create a list row for each map in the map package.
            ForEach(mapPackage.maps.enumeratedArray(), id: \.offset) { (offset, map) in
                let mapName = map.item?.name.titleCased ?? "Map \(offset + 1)"
                
                // The navigation link to the map.
                NavigationLink {
                    Group {
                        if let locatorTask = mapPackage.locatorTask {
                            MobileMapView(map: map, locatorTask: locatorTask)
                        } else {
                            MapView(map: map)
                        }
                    }
                    .navigationTitle(mapName)
                } label: {
                    HStack {
                        // The image of the map for the row.
                        Image(uiImage: map.item?.thumbnail?.image ?? UIImage(systemName: "questionmark")!)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                            .overlay {
                                // The symbols indicating the map's functionality.
                                VStack {
                                    HStack {
                                        if !map.transportationNetworks.isEmpty {
                                            // The symbol indicating whether the map can route.
                                            Image(systemName: "arrow.triangle.turn.up.right.circle")
                                        }
                                        Spacer()
                                        if mapPackage.locatorTask != nil {
                                            // The symbol indicating whether the map can geocode.
                                            Image(systemName: "mappin.circle")
                                        }
                                    }
                                    .padding(2)
                                    Spacer()
                                }
                            }
                        
                        Text(mapName)
                    }
                }
            }
        }
    }
}

private extension Collection {
    /// Enumerates a collection as an array of (n, x) pairs, where n represents a consecutive integer
    /// starting at zero and x represents an element of the collection..
    /// - Returns: An array of pairs enumerating the collection.
    func enumeratedArray() -> [(offset: Int, element: Self.Element)] {
        return Array(self.enumerated())
    }
}

private extension String {
    /// A copy of a camel cased string broken into words with capital letters.
    var titleCased: String {
        // Break string into words if needed.
        let words: String
        if !self.trimmingCharacters(in: .whitespacesAndNewlines).contains(" ") {
            words = self.replacingOccurrences(
                of: "([A-Z])",
                with: " $1",
                options: .regularExpression
            )
        } else {
            words = self
        }
        
        return words
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
    }
}

private extension UTType {
    /// A type that represents a mobile map package file.
    static let mmpk = UTType(filenameExtension: "mmpk")!
}
