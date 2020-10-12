//
//  main.swift
//  CovidExtractor
//
// This extracts the data from the US and the global cities,
// and produces json versions with an index with basic information,
// and then a detailed separate file with the last 20 days of confirmed
// and death cases.
//
// additionally this needs to aggregate state data (for the US) and
// country data (international)
//
//  Created by Miguel de Icaza on 10/8/20.
//

// Scenarios:
//   countryRegion == "US" && admin = nil, this is a state in "provinceState"
//   countryRegion == "US", state is provinceState, county is "admin"
//   otherwise Country == specified, provinceRegion is the subregioin
import Foundation
import SwiftCSV

func populateDeathUS (slot: inout TrackedLocation, row: [String])
{
    slot.admin = row [5]
    slot.proviceState = row [6]
    slot.countryRegion = row [7]
    slot.lat = row [8]
    slot.long = row [9]
    //slot.title = "\(slot.admin!), \(slot.proviceState!)"
}

var statesLocations: [String:TrackedLocation] = [:]
var statesSnapshots: [String:Snapshot] = [:]

func extractUS (_ fdeaths: CSV, _ fcases: CSV)
{
    // Now populate the data
    for r in fdeaths.enumeratedRows {
        let key = r [4] // fips
        
        if key == "" {
            continue
        }

        let provinceState = r [6]
        var slot = gd.globals [key] ?? TrackedLocation ()
        var stateSlot = gd.globals [provinceState] ?? TrackedLocation ()
        populateDeathUS(slot: &slot, row: r)
        stateSlot.proviceState = provinceState
        stateSlot.countryRegion = r [7]
        stateSlot.lat = r [8]
        stateSlot.long = r [9]
        //stateSlot.title = provinceState
        gd.globals [key] = slot
        gd.globals [provinceState] = stateSlot
        
        var snapshot = sd.snapshots [key] ?? Snapshot ()
        var stateSnapshot = sd.snapshots [provinceState] ?? Snapshot ()
        snapshot.lastDeaths = Array (r [12...].map { Int ($0)! })
        if let stateArray = stateSnapshot.lastDeaths {
            for i in 0..<stateArray.count {
                stateSnapshot.lastDeaths [i] += snapshot.lastDeaths [i]
            }
        } else {
            stateSnapshot.lastDeaths = snapshot.lastDeaths
        }
        sd.snapshots [key] = snapshot
        sd.snapshots [provinceState] = stateSnapshot
    }
    
    for r in fcases.enumeratedRows {
        let key = r [4]
        if key == "" {
            continue
        }
        let provinceState = r [6]
        var snapshot = sd.snapshots [key]!
        var stateSnapshot = sd.snapshots [provinceState]!
        snapshot.lastConfirmed = Array (r [11...].map { Int ($0)! })
        if let stateArray = stateSnapshot.lastConfirmed {
            for i in 0..<stateArray.count {
                stateSnapshot.lastConfirmed [i] += snapshot.lastConfirmed [i]
            }
        } else {
            stateSnapshot.lastConfirmed = snapshot.lastConfirmed
        }
        sd.snapshots [key] = snapshot
        sd.snapshots [provinceState] = stateSnapshot
    }
}

func validateUS (_ fdeaths: CSV, _ fcases: CSV)
{
    // Validate that the columns match, to catch any ambiguities on the data
    if fdeaths.enumeratedColumns.count != fcases.enumeratedColumns.count+1{
        print ("The tables do not match, deaths is supposed to have an additional column")
        abort ()
    }
    let ccases = fcases.enumeratedColumns
    let cdeathts = fdeaths.enumeratedColumns
    for i in 0..<fcases.enumeratedColumns.count-11 {
        let hcase = ccases [i+11].header
        let hdeath = cdeathts [i+12].header
        if hcase != hdeath {
            print ("Different columns at \(i) \(hcase) and \(hdeath)")
            abort ()
        }
    }
    print ("Columns match")
}

func populateDeathWorld (slot: inout TrackedLocation, row: [String])
{
    //slot.admin = ""
    slot.proviceState = row [0]
    slot.countryRegion = row [1]
    slot.lat = row [2]
    slot.long = row [3]
}

func makeWorldKey (_ r: [String]) -> String
{
    if r [0] == "" {
        return r [1]
    }
    return "\(r[0]), \(r[1])"
}
func extractWorld (_ n: Int, _ fdeaths: CSV, _ fcases: CSV)
{
//
//    var stateSnapshot = sd.snapshots [provinceState] ?? Snapshot ()
//    snapshot.lastDeaths = Array (r [r.count-n..<r.count].map { Int ($0)! })
//    if let stateArray = stateSnapshot.lastDeaths {
//        for i in 0..<stateArray.count {
//            stateSnapshot.lastDeaths [i] += snapshot.lastDeaths [i]
//        }
//    } else {
//        stateSnapshot.lastDeaths = snapshot.lastDeaths
//    }
    // Now populate the data
    for r in fdeaths.enumeratedRows {
        let key = makeWorldKey(r)
        
        var slot = gd.globals [key] ?? TrackedLocation ()
        populateDeathWorld(slot: &slot, row: r)
        gd.globals [key] = slot
        
        var snapshot = sd.snapshots [key] ?? Snapshot ()
        snapshot.lastDeaths = Array (r [4...].map { Int($0)! })
        sd.snapshots [key] = snapshot
    }
    
    for r in fcases.enumeratedRows {
        let key = makeWorldKey(r)

        var snapshot = sd.snapshots [key]!
        snapshot.lastConfirmed = Array (r [4...].map { Int($0)! })
        sd.snapshots [key] = snapshot
        
    }
}

func saveData ()
{
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted
    let global = try! encoder.encode(gd)
    try! global.write(to: URL(fileURLWithPath: "/Users/miguel/cvs/CovidGraphs/global"))
    
    let data = try! encoder.encode (sd)
    try! data.write (to: URL(fileURLWithPath: "/tmp/individual"))
    
    for x in sd.snapshots {
        var y = IndividualSnapshot (snapshot: x.value)
        let small = try! encoder.encode (y)
        try! small.write (to: URL(fileURLWithPath: "/tmp/ind/\(x.key)"))
        
    }
}

// validate that we got data for everything
func validateData ()
{
    for (_, slot) in sd.snapshots {
        if slot.lastConfirmed.count != slot.lastDeaths.count {
            print ("They do not have data")
        }
    }
}

let prefix = "/Users/miguel/cvs/"
let deaths = "COVID-19/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_deaths_US.csv"
let cases = "COVID-19/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_US.csv"
let deathsWorld = "COVID-19/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_deaths_global.csv"
let casesWorld = "COVID-19/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_global.csv"

let days = 40
var fdeaths = try! CSV(url: URL(fileURLWithPath: prefix + deaths))
var fcases = try! CSV(url: URL(fileURLWithPath: prefix + cases))

gd = GlobalData()
sd = SnapshotData()
validateUS(fdeaths, fcases)

extractUS (fdeaths, fcases)

fdeaths = try! CSV(url: URL(fileURLWithPath: prefix + deathsWorld))
fcases = try! CSV(url: URL(fileURLWithPath: prefix + casesWorld))
extractWorld (days, fdeaths, fcases)

validateData ()

saveData()
