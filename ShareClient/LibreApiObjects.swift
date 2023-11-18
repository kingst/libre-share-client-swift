//
//  LibreLinkObjects.swift
//  Type Zero
//
//  Created by Sam King on 11/27/22.
//  Copyright © 2022 Sam King. All rights reserved.
//

import Foundation

struct LibreApiObjects {
    struct LoginRequest: Codable {
        let email: String
        let password: String
    }
    
    struct UpdateAccountRequest: Encodable {
        let appVersion: String
        let phoneLanguage = "en-US"
        let uiLanguage = "en-US"
        let communicationLanguage = "en-US"
    }
    
    struct UpdateAccountResponse: Codable {
        let ticket: LoginAuthTicketResponse
    }
    
    struct LoginUserResponse: Codable {
        //let firstName: String
        //let lastName: String
        //let email: String
    }
    
    struct LoginAuthTicketResponse: Codable {
        let token: String
        let expires: Int64
        let duration: Int64
    }
    
    struct LoginDataResponse: Codable {
        let user: LoginUserResponse
        let authTicket: LoginAuthTicketResponse
    }
    
    struct LoginResponse: Codable {
        let status: Int64
        let data: LoginDataResponse
    }
    
    struct ApiErrorPayload: Codable {
        let message: String
    }
    
    struct ApiError: Codable {
        let status: Int64
        let error: ApiErrorPayload
    }
    
    struct Sensor: Codable {
        let deviceId: String
        let sn: String
        let a: Int64
    }
    
    struct GlucoseMeasurement: Codable {
        let factoryTimestamp: String
        let timestamp: String
        let valueInMgPerDl: Int64
        
        enum CodingKeys: String, CodingKey {
            case factoryTimestamp = "FactoryTimestamp"
            case timestamp = "Timestamp"
            case valueInMgPerDl = "ValueInMgPerDl"
        }
        
        func createdInUtc() -> Date? {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.dateFormat = "MM/dd/yyyy hh:mm:ss a"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            return dateFormatter.date(from: self.factoryTimestamp)
        }
    }
    
    struct Patient: Codable {
        let patientId: String
        let firstName: String
        let lastName: String
        let sensor: Sensor
        let targetHigh: Int
        let targetLow: Int
        let glucoseMeasurement: GlucoseMeasurement
    }
    
    struct ConnectionsResponse: Codable {
        let status: Int64
        let data: [Patient]
    }
    
    struct GraphData: Codable {
        let connection: Patient
        let graphData: [GlucoseMeasurement]
    }
    
    struct GraphResponse: Codable {
        let status: Int64
        let data: GraphData
    }
}

extension LibreApiObjects.GlucoseMeasurement {
    func toGlucoseReading() -> ShareGlucose? {
        let readingInMlDl = UInt16(self.valueInMgPerDl)
        guard let created = self.createdInUtc() else { assertionFailure(); return nil }
        return ShareGlucose(glucose: readingInMlDl, trend: 0, timestamp: created)
    }
}
