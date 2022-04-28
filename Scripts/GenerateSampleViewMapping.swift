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

// This script reads from the `Samples.plist` property list file and generates a
// string that is the dictionary representation of type `[String: AnyView]`, and
// replaces the stub in the template file, so that all the sample SwiftUI views
// are available when the project compiles.
//
// It takes 3 arguments.
// The first is a path to a plist file defining the samples.
// The second is a path to the template file, i.e. *.tache.
// The third is a path to output generated file.
//
// The program will parse the input file, look for an empty dictionary,
// i.e.: [:], and replace it with the generated string representation.

import Foundation

// MARK: Model

struct Sample: Decodable {
    let displayName: String
    let description: String
    let viewName: String
    let dependencies: [String]?
}

// MARK: Script Entry

let arguments = CommandLine.arguments

guard arguments.count == 4 else {
    print("Invalid number of arguments")
    exit(1)
}

let samplesPlistURL = URL(fileURLWithPath: arguments[1], isDirectory: false)
let templateURL = URL(fileURLWithPath: arguments[2], isDirectory: false)
let outputFileURL = URL(fileURLWithPath: arguments[3], isDirectory: false)

let samples: [Sample] = {
    do {
        let data = try Data(contentsOf: samplesPlistURL)
        return try PropertyListDecoder().decode([Sample].self, from: data)
    } catch {
        print("Error decoding Samples.plist: \(error)")
        exit(1)
    }
}()

let entries = samples.map { sample in "\"\(sample.displayName)\": AnyView(\(sample.viewName)())" }.joined(separator: ", ")
let dictionaryRepresentation = "[\(entries)]"

do {
    let file = try String(contentsOf: templateURL, encoding: .utf8)
    let content = file.replacingOccurrences(of: "[:]", with: dictionaryRepresentation)
    try content.write(to: outputFileURL, atomically: true, encoding: .utf8)
} catch {
    print("Error reading or writing template file: \(error)")
    exit(1)
}
