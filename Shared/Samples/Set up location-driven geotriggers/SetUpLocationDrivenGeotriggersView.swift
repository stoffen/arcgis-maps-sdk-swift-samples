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

struct SetUpLocationDrivenGeotriggersView: View {
    /// The view model for the sample.
    @StateObject private var model = Model()
    
    var body: some View {
        // Create a map view to display the map.
        MapView(map: model.map)
            .locationDisplay(model.locationDisplay)
            .alert(isPresented: $model.isShowingAlert, presentingError: model.alertError)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    // Create button.
                    Button("Current Selction") {
                    }
                    .disabled(model.currentSectionBarButtonItem)
                    // Reset button.
                    Button("Point of Interest") {
                    }
                    .disabled(model.pointOfInterestBarButtonItem)
                }
            }
    }
}

private extension SetUpLocationDrivenGeotriggersView {
    /// The view model for the sample.
    class Model: ObservableObject {
        /// A map
        lazy var map = makeMap()
        
        ///
        lazy var locationDataSource = makeDataSource(polylineJSONString: walkingTourPolylineJSON)
        
        /// The location display for the sample
        lazy var locationDisplay = makeLocationDisplay()
        
        /// The name of the current garden section feature. If currently not in any
        /// garden section, it will be `nil`.
        var currentSectionName: String? {
            featureNamesInFenceGeotrigger[sectionFenceGeotriggerName]?.last
        }
        /// The names of nearby point-of-interest features.
        var nearbyPOINames: [String] {
            featureNamesInFenceGeotrigger[poiFenceGeotriggerName] ?? []
        }
        
        /// A dictionary for the feature names in each fence geotrigger.
        /// - Key: The name of a fence geotrigger.
        /// - Value: An array of names of features within the fence.
        var featureNamesInFenceGeotrigger: [String: [String]] = [:] {
            didSet {
                currentSectionBarButtonItem = currentSectionName != nil
                pointOfInterestBarButtonItem = !nearbyPOINames.isEmpty
            }
        }
        
        /// A dictionary for nearby features.
        var nearbyFeatures: [String: ArcGISFeature] = [:]
        /// An array of observers for geotrigger monitor notifications.
        var observers: [NSObjectProtocol] = []
        /// An array of geotrigger monitors.
        var geotriggerMonitors: [GeotriggerMonitor] = []
        
        /// A simulated location data source for demo purposes.
        lazy var simulatedLocationDataSource = locationDataSource
        
        /// A Boolean value indicating whether to show an alert.
        @Published var isShowingAlert = false
        
        /// The error shown in the alert.
        @Published var alertError: Error? {
            didSet { isShowingAlert = alertError != nil }
        }
        
        /// A Boolean indicating
        @Published var currentSectionBarButtonItem = false
        
        /// A Boolean indicating
        @Published var pointOfInterestBarButtonItem = false
        
        /// Create a map.
        func makeMap() -> Map {
            // Load a map with predefined tile basemap, feature styles, and labels.
            let map = Map(item: PortalItem(
                portal: .arcGISOnline(connection: .anonymous),
                id: Item.ID(rawValue: "6ab0e91dc39e478cae4f408e1a36a308")!
            ))
            Task {
                do {
                    try await map.load()
                } catch {
                    alertError = error
                }
            }
            return map
        }
    
        /// Create and start a location display.
        func makeLocationDisplay() -> LocationDisplay {
            let locationDisplay = LocationDisplay(dataSource: locationDataSource)
            locationDisplay.autoPanMode = .recenter
            locationDisplay.initialZoomScale = 1000
            Task {
                do {
                    try await locationDisplay.dataSource.start()
                } catch {
                    alertError = error
                }
            }
            return locationDisplay
        }
        
        /// Create a simulated location data source from a GeoJSON.
        func makeDataSource(polylineJSONString: String) -> SimulatedLocationDataSource {
            // Densify the polyline to control the simulation speed.
            let routePolyline = try? Polyline.fromJSON(polylineJSONString)
            let densifiedRoute = GeometryEngine.geodeticDensify(
                routePolyline!,
                maxSegmentLength: 5.0,
                lengthUnit: .meters,
                curveType: .geodesic
            ) as! Polyline
            let simulatedDataSource = SimulatedLocationDataSource()
            simulatedDataSource.setSimulatedLocations(with: densifiedRoute)
            return simulatedDataSource
        }
        
        /// Start geotriggers.
        func startMonitoring() {
            // Get the service feature tables from the map's operational layers.
            if let operationalLayers = map.operationalLayers as? [FeatureLayer],
               let gardenSectionsLayer = operationalLayers.first(where: { $0.item?.id == Item.ID(rawValue: "1ba816341ea04243832136379b8951d9") }),
               let gardenPOIsLayer = operationalLayers.first(where: { $0.item?.id == Item.ID(rawValue: "7c6280c290c34ae8aeb6b5c4ec841167") }),
               let gardenSections = gardenSectionsLayer.featureTable as? ServiceFeatureTable,
               let gardenPOIs = gardenPOIsLayer.featureTable as? ServiceFeatureTable {
                // Create geotriggers for each of the service feature tables.
                let geotriggerFeed = LocationGeotriggerFeed(locationDataSource: locationDataSource)
                makeGeotrigger(feed: geotriggerFeed, featureTable: gardenSections, bufferDistance: 0.0, fenceGeotriggerName: sectionFenceGeotriggerName)
                makeGeotrigger(feed: geotriggerFeed, featureTable: gardenPOIs, bufferDistance: 10.0, fenceGeotriggerName: poiFenceGeotriggerName)
            }
        }
        
        /// Create a geotrigger monitor and start observing its notifications.
        /// - Parameters:
        ///   - feed: The `AGSGeotriggerFeed` that is monitored for changes.
        ///   - featureTable: The `AGSFeatureTable` that contains the features to use
        ///    in the `AGSFeatureFenceParameters`.
        ///   - bufferDistance: A buffer distance in meters to apply to the features
        ///   when checking if an `AGSFenceGeotrigger` condition is met.
        ///   - fenceGeotriggerName: The name for the `AGSFenceGeotrigger`.
        func makeGeotrigger(feed: GeotriggerFeed, featureTable: ServiceFeatureTable, bufferDistance: Double, fenceGeotriggerName: String) {
            let fenceParameters = FeatureFenceParameters(
                featureTable: featureTable,
                bufferDistance: bufferDistance
            )
            // The Arcade expression in the fence geotrigger returns the value for
            // the "name" field of the feature that triggered the monitor.
            let fenceGeotrigger = FenceGeotrigger(
                feed: feed,
                ruleType: .enterOrExit,
                fenceParameters: fenceParameters,
                messageExpression: ArcadeExpression(expression: "$fenceFeature.name"),
                name: fenceGeotriggerName
            )
            
            // Create and start the geotrigger monitor.
            let geotriggerMonitor = GeotriggerMonitor(geotrigger: fenceGeotrigger)

            Task {
                do {
                    try await geotriggerMonitor.start()
                    geotriggerMonitors.append(geotriggerMonitor)
                } catch {
                    alertError = error
                }
            }
            
             // Observe geotrigger notifications.
             let observer = NotificationCenter.default.addObserver(
             forName: .none,
             object: geotriggerMonitor,
             queue: nil,
             using: { [weak self] note in handleGeotriggerNotification(note) }
             )
             observers.append(observer)
        }
    }
}

/// Handle the notifications posted by `AGSGeotriggerMonitor` when the fence
/// geotrigger condition has been met.
func handleGeotriggerNotification(_ notification: Notification) {
}

private extension SetUpLocationDrivenGeotriggersView {
    static let sectionFenceGeotriggerName = "Section Fence Geotrigger"
    static let poiFenceGeotriggerName = "POI Fence Geotrigger"
    
    /// A path in Santa Barbara Botanic Garden in GeoJSON format.
    static let walkingTourPolylineJSON = #"{"paths":[[[-119.709881177746,34.4570041646846],[-119.709875813328,34.4570152227745],[-119.709869107805,34.4570240692453],[-119.709859720074,34.4570351273326],[-119.709853014551,34.4570539260775],[-119.709847650133,34.4570760422426],[-119.709848991238,34.4570926293626],[-119.70985569676,34.4571103222869],[-119.709873131119,34.4571202745552],[-119.709889224373,34.4571302268223],[-119.709902635418,34.4571357558591],[-119.709910682045,34.4571600836165],[-119.709910682045,34.4571744591062],[-119.709902635418,34.4571833055602],[-119.709889224373,34.4571910462067],[-119.70988251885,34.4571965752394],[-119.70988251885,34.4572032100782],[-119.709889224373,34.4572175855605],[-119.709898612104,34.4572264320099],[-119.709912023149,34.4572341726524],[-119.709901294313,34.4572419132941],[-119.709895929895,34.4572507597409],[-119.709897271,34.4572596061868],[-119.709902635418,34.4572728758539],[-119.709902635418,34.4572828281028],[-119.70990934094,34.457294991961],[-119.709912023149,34.4573038384022],[-119.709886542164,34.4573115790375],[-119.709861061178,34.4573248486963],[-119.709843626819,34.4573414357669],[-119.709836921297,34.4573668692686],[-119.709843626819,34.4573934085666],[-119.709827533565,34.4574055724087],[-119.709791323744,34.4574188420525],[-119.709749749504,34.4574332174977],[-119.709709516369,34.4574431697275],[-119.709734997354,34.4574807670294],[-119.709748062646,34.4575248306656],[-119.709757450378,34.4575635337324],[-119.709770861423,34.457600025179],[-119.709785613572,34.4576387282109],[-119.70980573014,34.4576730080242],[-119.709815117871,34.4577117110223],[-119.709821823394,34.4577504140025],[-119.709821823394,34.4577869053674],[-119.709821823394,34.4578256083127],[-119.70981780008,34.4578609938471],[-119.709819141185,34.457906331541],[-119.70981460448,34.4579890675855],[-119.709818627793,34.4580675790658],[-119.70982667442,34.4581118108532],[-119.709832038838,34.4581471962662],[-119.709834721047,34.4581947453913],[-119.709836062152,34.4582323423548],[-119.709834721047,34.4582787856393],[-119.709805216748,34.4583429215611],[-119.709759619195,34.4584026342716],[-119.709700610597,34.4584612411497],[-119.709645400048,34.4585103926263],[-119.709566274882,34.4585457778704],[-119.709493855239,34.4585944325566],[-119.709458986522,34.458622077252],[-119.709424117805,34.4586198656767],[-119.709386566878,34.4586110193749],[-119.70935438037,34.4586110193749],[-119.709339628221,34.4586231830396],[-119.709324876071,34.4586585682359],[-119.709306100608,34.4586862129101],[-119.709269890786,34.4587171749343],[-119.709244409801,34.4587238096523],[-119.709229657651,34.4587293385835],[-119.709212223293,34.4587459253751],[-119.70919076562,34.4587945799446],[-119.709174672366,34.4588503400161],[-119.709157238008,34.4589288506865],[-119.709153214694,34.4589951976744],[-119.709155896903,34.4590449578807],[-119.70916394353,34.4590958238387],[-119.709186742307,34.4591323146156],[-119.709218928815,34.4591621706939],[-119.709237704278,34.4591831805204],[-119.709241727592,34.4592252001575],[-119.709238133851,34.459258658624],[-119.709219358388,34.4592796684262],[-119.709207288447,34.4592962551085],[-119.709208629552,34.4593084186733],[-119.709271661463,34.4593791884701],[-119.709310553494,34.4594267368937],[-119.709330670062,34.4594510639836],[-119.709353468838,34.4595008239182],[-119.70936285657,34.4595362087426],[-119.709423221989,34.4595943612845],[-119.709455408497,34.4596297460692],[-119.709487595005,34.459665130839],[-119.709507711573,34.4596817174446],[-119.709523804827,34.4596861405389],[-119.709557332439,34.4596894578594],[-119.709586836739,34.4596894578594],[-119.709593542261,34.4596772943501],[-119.709590860052,34.4596496500041],[-119.709572084589,34.4595777746615],[-119.709566720171,34.4595313320996],[-119.709578790112,34.4595136396883],[-119.709590860052,34.4594992646013],[-119.709627069874,34.4594882068404],[-119.709675349636,34.4595567649343],[-119.709735699339,34.4596197941001],[-119.709775932474,34.4596795058974],[-119.709802754564,34.4597126790997],[-119.709832258863,34.4597359003334],[-119.70986712758,34.4597171021923],[-119.70986980979,34.4596839289918],[-119.709865786476,34.4596308518435],[-119.709876515312,34.4595788804365],[-119.70988187973,34.4595346494263],[-119.709879197521,34.4594926299449],[-119.709852375431,34.4594539277723],[-119.709806777878,34.4593953215911],[-119.709767885847,34.4593212344729],[-119.709720947189,34.4592195028005],[-119.709708720088,34.4591478732967],[-119.709710061193,34.4591058536206],[-119.709707378984,34.459079314867],[-119.709652393699,34.4590262373344],[-119.709617524982,34.4589499383221],[-119.709626771268,34.4588695962162],[-119.709683097658,34.4588032491285],[-119.709730036316,34.4587391135603],[-119.709759540615,34.4586993052518],[-119.7097850216,34.4586650258598],[-119.710059948024,34.4587744987075],[-119.710104204473,34.4587932970608],[-119.710128443889,34.4587649224307],[-119.71019415801,34.4587096331253],[-119.710273283176,34.4586731421637],[-119.71031619852,34.4586532379961],[-119.710367160491,34.4586023717685],[-119.710392641477,34.4585747270665],[-119.710432874612,34.4585083797445],[-119.710471766643,34.4584453497398],[-119.710505294256,34.4584165991955],[-119.710575487456,34.4583689119728],[-119.710705574593,34.4583136224052],[-119.710780676446,34.4582627559707],[-119.710839685044,34.4582030431601],[-119.710895995717,34.4581546042213],[-119.710948298793,34.458095997128],[-119.710988531928,34.4580263320391],[-119.711015354018,34.4579511379096],[-119.711011330705,34.4579102234284],[-119.710985849719,34.4578847900921],[-119.710946957688,34.4578715205223],[-119.710779319625,34.4578847900921],[-119.71073908649,34.4578847900921],[-119.7107122644,34.4578604625458],[-119.71069751225,34.4578295002039],[-119.710674713473,34.4578095958352],[-119.710642526965,34.4577996436491],[-119.710614363771,34.457830606002],[-119.71057547174,34.4578571451526],[-119.710539261918,34.4578737321174],[-119.71049500547,34.4578858958895],[-119.710452090125,34.4578836842947],[-119.710413198095,34.4578748379149],[-119.710375647168,34.4578527219614],[-119.710336755138,34.4578350291944],[-119.710299204211,34.4578107016336],[-119.71027506433,34.4577885856631],[-119.710269605616,34.4577886418169],[-119.710240101317,34.4577510446536],[-119.710198527077,34.4576758502763],[-119.710154270628,34.4575984442288],[-119.710112696389,34.4575265671206],[-119.710044300059,34.4574381029023],[-119.709978842634,34.4573543166616],[-119.709966772693,34.4573410470074],[-119.709972137111,34.4573200367174],[-119.70997481932,34.4573023438375],[-119.709973478216,34.4572846509538],[-119.709970796007,34.457259217427],[-119.709931903976,34.4572348896984],[-119.709914469617,34.4572337838924],[-119.709893011945,34.4572171968005],[-119.709884965318,34.4571972922858],[-119.709902232039,34.4571821133624],[-119.70991161977,34.457167737874],[-119.709907596457,34.4571389868898],[-119.709919666397,34.4571235055865],[-119.709922348606,34.4571047068572],[-119.709918325293,34.4570836965077],[-119.709919666397,34.4570648977695],[-119.70992637192,34.4570516280694],[-119.709933077442,34.4570339351326],[-119.709935759651,34.4570151363832],[-119.709927713024,34.4570062899114],[-119.70991161977,34.4570018666751],[-119.709883456576,34.4570040782933]]],"spatialReference":{"wkid":4326,"latestWkid":4326}}"#
}
