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

import SwiftUI
import ArcGIS

struct DisplayMapView: View {
    /// A map with imagery basemap.
    ///
    ///basemap: Basemap(url: !)
    ///url: !
    @State private var map = Map(basemap: Basemap(baseLayer: ArcGISTiledLayer(url: URL(string: "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheBasis/MapServer")!)))
    
    var body: some View {
        // Creates a map view to display the map.
        MapView(map: map).task {
            let rasters = ["https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheBilder/MapServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheDybdedata/ImageServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheGraatone/MapServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheGraatone/MapServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheHybrid/MapServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheKyst/MapServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheLandskap/MapServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheOverflate/ImageServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocachePolar/MapServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocachePolar/MapServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheTerreng_ND/ImageServer", "https://services.geodataonline.no/arcgis/rest/services/Geocache_UTM33_EUREF89/GeocacheTerrengskygge/MapServer"]
            let vectors = ["https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheBasis/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheBasisTerreng/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheFinland/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheFinlandGraatone/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheFinlandKanvasMork/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheGraatone/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheGraatoneTerreng/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheHoydekurver/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheKanvas/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheNordenBasis/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheNordenBasisTerreng/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheNordenGraatone/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheNordenKanvasMork/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheOSM2/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocachePolar/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheSverigeTopo50/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheSverigeTopo50Graatone/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheSverigeTopo50Hoydekurver/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheSverigeTopo50KanvasMork/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheSverigeTopo50KanvasMorkTerreng/VectorTileServer", "https://services.geodataonline.no/arcgis/rest/services/GeocacheVector/GeocacheSverigeTopo50Terreng/VectorTileServer"]
            do {
                for r in rasters {
                    let raster = ArcGISTiledLayer(url: URL(string: r)!)
                    try await raster.load()
                    map.addOperationalLayer(raster)
                }
                for v in vectors {
                    let vector = ArcGISVectorTiledLayer(url: URL(string: v)!)
                    try await vector.load()
                    map.addOperationalLayer(vector)
                }
            } catch {
                print("\(error)")
            }
        }
    }
}

#Preview {
    DisplayMapView()
}
