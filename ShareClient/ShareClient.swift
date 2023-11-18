//
//  ShareClient.h
//  ShareClient
//
//  Created by Mark Wilson on 5/7/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import Foundation

public struct ShareGlucose {
    public let glucose: UInt16
    public let trend: UInt8
    public let timestamp: Date
}

public enum ShareError: Error {
    case httpError(Error)
    // some possible values of errorCode:
    // SSO_AuthenticateAccountNotFound
    // SSO_AuthenticatePasswordInvalid
    // SSO_AuthenticateMaxAttemptsExceeed
    case loginError(errorCode: String)
    case fetchError
    case dataError(reason: String)
    case dateError
}


public enum KnownShareServers: String {
    case US="https://share2.dexcom.com"
    case NON_US="https://shareous1.dexcom.com"
}


public class ShareClient {
    public let username: String
    public let password: String

    private let shareServer:String
    private var token: String?
    private var patientId: String?
    private let libreApiService = NetworkLibreApiService()
    
    public init(username: String, password: String, shareServer:String=KnownShareServers.US.rawValue) {
        self.username = username
        self.password = password
        self.shareServer = shareServer
    }
    public convenience init(username: String, password: String, shareServer:KnownShareServers=KnownShareServers.US) {

        self.init(username: username, password: password, shareServer:shareServer.rawValue)

    }

    public func fetchLast(_ n: Int, callback: @escaping (ShareError?, [ShareGlucose]?) -> Void) {
        fetchLastWithRetries(n, callback: callback)
    }

    private func ensureToken(_ callback: @escaping (ShareError?) -> Void) {
        if token != nil && patientId != nil {
            callback(nil)
        } else {
            Task {
                let (token, _) = await libreApiService.login(email: username, password: password)
                guard let token = token else {
                    callback(ShareError.loginError(errorCode: "SSO_AuthenticatePasswordInvalid"))
                    return
                }
                
                self.token = token
                let (patientId, _) = await libreApiService.connections(token: token)
                guard let patientId = patientId else {
                    callback(ShareError.fetchError)
                    return
                }
                self.patientId = patientId
                callback(nil)
            }
        }
    }

    private func fetchLastWithRetries(_ n: Int, callback: @escaping (ShareError?, [ShareGlucose]?) -> Void) {
        ensureToken() { [weak self] (error) in
            guard let self = self else { callback(.fetchError, nil); return }
            guard error == nil else {
                callback(error, nil)
                return
            }

            guard let token = self.token, let patientId = patientId else {
                callback(.fetchError, nil)
                return
            }

            Task {
                let (readings, _) = await self.libreApiService.readings(token: token, patientId: patientId)
                guard let readings = readings else {
                    callback(.fetchError, nil)
                    return
                }
                
                if readings.count <= n {
                    callback(nil, readings)
                } else {
                    callback(nil, readings.dropFirst(readings.count - n).map { $0 })
                }
            }
        }
    }
}
