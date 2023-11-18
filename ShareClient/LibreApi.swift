//
//  LibreLinkApi.swift
//  Type Zero
//
//  Created by Sam King on 11/27/22.
//  Copyright © 2022 Sam King. All rights reserved.
//

import Foundation

protocol LibreApiService {
    func login(email: String, password: String) async -> (String?, LibreApiError?)
    func connections(token: String) async -> (String?, LibreApiError?)
    func readings(token: String, patientId: String) async -> ([ShareGlucose]?, LibreApiError?)
}

struct NetworkLibreApiService: LibreApiService {
    func login(email: String, password: String) async -> (String?, LibreApiError?) {
        print("libre login")
        let (response, error) = await loginApi(email: email, password: password)
        
        guard let response = response else {
            return (nil, error)
        }
        
        let (updateResponse, updateError) = await updateAccountApi(token: response.data.authTicket.token)
        
        guard let updateResponse = updateResponse else {
            return (nil, updateError)
        }
                    
        return (updateResponse.ticket.token, error)
    }
    
    func connections(token: String) async -> (String?, LibreApiError?) {
        print("libre connections")
        let (response, error) = await connectionsApi(token: token)
        guard let response = response else { return (nil, error) }
        
        // XXX FIXME: we're just going to pick the first one for now
        guard let patient = response.data.first else { return (nil, error) }
        
        return (patient.patientId, error)
    }
    
    func readings(token: String, patientId: String) async -> ([ShareGlucose]?, LibreApiError?) {
        print("libre readings")
        let (response, error) = await graphApi(token: token, patientId: patientId)
        guard let response = response else {
            if let error = error {
                print("Couldn't download readings \(error)")
            } else {
                print("Couldn't download readings, nil error")
            }
            return (nil, error)
        }

        let estimatedReading = response.data.connection.glucoseMeasurement.toGlucoseReading().map({ [$0] }) ?? []
        let graphReadings = response.data.graphData.compactMap { $0.toGlucoseReading() }
        return (graphReadings + estimatedReading, nil)
    }
    
    func loginApi(email: String, password: String) async -> (LibreApiObjects.LoginResponse?, LibreApiError?) {
        return await withCheckedContinuation { continuation in
            LibreApi.login(email: email, password: password) { (response, error) in
                continuation.resume(returning: (response, error))
            }
        }
    }
    
    func updateAccountApi(token: String) async -> (LibreApiObjects.UpdateAccountResponse?, LibreApiError?) {
        return await withCheckedContinuation { continuation in
            LibreApi.updateAccount(token: token) { (response, error) in
                continuation.resume(returning: (response, error))
            }
        }
    }
    
    func connectionsApi(token: String) async -> (LibreApiObjects.ConnectionsResponse?, LibreApiError?) {
        return await withCheckedContinuation { continuation in
            LibreApi.connections(token: token) { (response, error) in
                continuation.resume(returning: (response, error))
            }
        }
    }
    
    func graphApi(token: String, patientId: String) async -> (LibreApiObjects.GraphResponse?, LibreApiError?) {
        return await withCheckedContinuation { continuation in
            LibreApi.graph(token: token, patientId: patientId) { (response, error) in
                continuation.resume(returning: (response, error))
            }
        }
    }
}

enum LibreApiError: Error {
    case defaultError
    case encodingError
    case decodingError
    case apiError
    case loginApiError
    case noActivePatient
    case noToken
}

extension LibreApiError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .defaultError:
            return NSLocalizedString("An unknown error occurred", comment: "default_error")
        case .encodingError:
            return NSLocalizedString("Unable to encode the API data", comment: "encoding_error")
        case .decodingError:
            return NSLocalizedString("Unable to decode the API data", comment: "decoding_error")
        case .apiError:
            return NSLocalizedString("API Error", comment: "api_error")
        case .loginApiError:
            return NSLocalizedString("Could not login, incorrect email or password", comment: "login_api_error")
        case .noActivePatient:
            return NSLocalizedString("No active patient saved", comment: "no_active_patient")
        case .noToken:
            return NSLocalizedString("No token found for login session", comment: "no_token")
        }
    }
}


struct LibreApi {
    
    static let baseUrl = "https://api-us.libreview.io"
    static let appVersion = "4.7.0"
    static func configuration(token: String?) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        
        var headers = ["content-type": "application/json",
                       "product": "llu.ios",
                       "version": appVersion]
        
        if let libreToken = token {
            if let decodedData = Data(base64Encoded: libreToken) {
                print(String(data: decodedData, encoding: .utf8) ?? "Nil")
            }
            headers["Authorization"] = "Bearer \(libreToken)"
        }
        
        config.httpAdditionalHeaders = headers
        return config
    }
    
    static func post<RequestType, ResponseType>(token: String?, endpoint: String, requestData: RequestType, completion: @escaping ((_ response: ResponseType?, _ error: LibreApiError?, _ apiErrorObject: LibreApiObjects.ApiError?) -> Void)) where RequestType: Encodable, ResponseType: Decodable {
        guard let url = URL(string: baseUrl + endpoint) else {
            DispatchQueue.main.async { completion(nil, .defaultError, nil) }
            return
        }
        
        let session = URLSession(configuration: configuration(token: token))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let encoder = JSONEncoder()
        guard let jsonRequestData = try? encoder.encode(requestData) else {
            DispatchQueue.main.async { completion(nil, .encodingError, nil) }
            return
        }
        
        session.uploadTask(with: request, from: jsonRequestData) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async { completion(nil, .apiError, nil) }
                return
            }

            let decoder = JSONDecoder()
            guard let jsonResponseData = try? decoder.decode(ResponseType.self, from: data) else {
                // see if we got an error object, return it if we did
                print(String(data: data, encoding: .utf8)!)
                guard let apiError = try? decoder.decode(LibreApiObjects.ApiError.self, from: data) else {
                    DispatchQueue.main.async { completion(nil, .decodingError, nil) }
                    return
                }
                DispatchQueue.main.async { completion(nil, .apiError, apiError) }
                return
            }
            
            DispatchQueue.main.async { completion(jsonResponseData, nil, nil) }
            
        }.resume()
    }
    
    static func get<ResponseType>(token: String?, endpoint: String, completion: @escaping ((_ response: ResponseType?, _ error: LibreApiError?, _ apiErrorObject: LibreApiObjects.ApiError?) -> Void)) where ResponseType: Decodable {
        
        guard let url = URL(string: baseUrl + endpoint) else {
            DispatchQueue.main.async { completion(nil, .defaultError, nil) }
            return
        }
        
        let session = URLSession(configuration: configuration(token: token))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        session.dataTask(with: url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async { completion(nil, .apiError, nil) }
                return
            }

            let decoder = JSONDecoder()
            guard let jsonResponseData = try? decoder.decode(ResponseType.self, from: data) else {
                print(String(data: data, encoding: .utf8)!)
                // see if we got an error object, return it if we did
                guard let apiError = try? decoder.decode(LibreApiObjects.ApiError.self, from: data) else {
                    DispatchQueue.main.async { completion(nil, .decodingError, nil) }
                    return
                }
                DispatchQueue.main.async { completion(nil, .apiError, apiError) }
                return
            }
            
            DispatchQueue.main.async { completion(jsonResponseData, nil, nil) }
        }.resume()
    }
    
    static func login(email: String, password: String, completion: @escaping (_ response: LibreApiObjects.LoginResponse?, _ error: LibreApiError?) -> Void) {
        let endpoint = "/llu/auth/login"
        let loginRequest = LibreApiObjects.LoginRequest(email: email, password: password)
        
        post(token: nil, endpoint: endpoint, requestData: loginRequest) { (response, error, apiError) in
            if error == .apiError && apiError?.status == 2 {
                completion(nil, .loginApiError)
            } else {
                completion(response, error)
            }
        }
    }
    
    static func updateAccount(token: String, completion: @escaping (_ response: LibreApiObjects.UpdateAccountResponse?, _ error: LibreApiError?) -> Void) {
        let endpoint = "/llu/user/updateaccount"
        let updateRequest = LibreApiObjects.UpdateAccountRequest(appVersion: appVersion)
        
        post(token: token, endpoint: endpoint, requestData: updateRequest) { (response, error, apiError) in
            completion(response, error)
        }
    }
    
    static func connections(token: String, completion: @escaping (_ response: LibreApiObjects.ConnectionsResponse?, _ error: LibreApiError?) -> Void) {
        let endpoint = "/llu/connections"

        get(token: token, endpoint: endpoint) { (response, error, apiError) in
            completion(response, error)
        }
    }
    
    static func graph(token: String, patientId: String, completion: @escaping (_ response: LibreApiObjects.GraphResponse?, _ error: LibreApiError?) -> Void) {
        let endpoint = "/llu/connections/\(patientId)/graph"

        get(token: token, endpoint: endpoint) { (response, error, apiError) in
            completion(response, error)
        }
    }
}
