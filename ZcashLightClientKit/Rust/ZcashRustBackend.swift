//
//  ZcashRustBackend.swift
//  ZcashLightClientKit
//
//  Created by Jack Grigg on 5/8/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

class ZcashRustBackend: ZcashRustBackendWelding {
    
    static func lastError() -> RustWeldingError? {
        guard let message = getLastError() else { return nil }
        
        if message.contains("couldn't load Sapling spend parameters") {
            return RustWeldingError.saplingSpendParametersNotFound
        }
        return RustWeldingError.genericError(message: message)
    }
    
    static func getLastError() -> String? {
        let errorLen = zcashlc_last_error_length()
        if errorLen > 0 {
            let error = UnsafeMutablePointer<Int8>.allocate(capacity: Int(errorLen))
            zcashlc_error_message_utf8(error, errorLen)
            zcashlc_clear_last_error()
            return String(validatingUTF8: error)
        } else {
            return nil
        }
    }
    
    /**
    * Sets up the internal structure of the data database.
    */
    static func initDataDb(dbData: URL) throws {
        let dbData = dbData.osStr()
        guard zcashlc_init_data_database(dbData.0, dbData.1) != 0 else {
            if let error = lastError() {
                throw throwDataDbError(error)
            }
            throw RustWeldingError.dataDbInitFailed(message: "unknown error")
        }
    }

    static func initAccountsTable(dbData: URL, seed: [UInt8], accounts: Int32) -> [String]? {
        let dbData = dbData.osStr()
        let extsksCStr = zcashlc_init_accounts_table(dbData.0, dbData.1, seed, UInt(seed.count), accounts)
        if extsksCStr == nil {
            return nil
        }

        let extsks = UnsafeBufferPointer(start: extsksCStr, count: Int(accounts)).compactMap({ (cStr) -> String? in
            guard let str = cStr else { return nil }
            return String(cString: str)
        })
        zcashlc_vec_string_free(extsksCStr, UInt(accounts))
        return extsks
    }

    static func initBlocksTable(dbData: URL, height: Int32, hash: String, time: UInt32, saplingTree: String) throws {
        let dbData = dbData.osStr()
        guard zcashlc_init_blocks_table(dbData.0, dbData.1, height, [CChar](hash.utf8CString), time, [CChar](saplingTree.utf8CString)) != 0 else {
            if let error = lastError() {
                throw throwDataDbError(error)
            }
            throw RustWeldingError.dataDbInitFailed(message: "Unknown Error")
        }
    }

    static func getAddress(dbData: URL, account: Int32) -> String? {
        let dbData = dbData.osStr()

        guard let addressCStr = zcashlc_get_address(dbData.0, dbData.1, account) else { return nil }

        let address = String(validatingUTF8: addressCStr)
        zcashlc_string_free(addressCStr)
        return address
    }

    static func getBalance(dbData: URL, account: Int32) -> Int64 {
        let dbData = dbData.osStr()
        return zcashlc_get_balance(dbData.0, dbData.1, account)
    }

    static func getVerifiedBalance(dbData: URL, account: Int32) -> Int64 {
        let dbData = dbData.osStr()
        return zcashlc_get_verified_balance(dbData.0, dbData.1, account)
    }

    static func getReceivedMemoAsUTF8(dbData: URL, idNote: Int64) -> String? {
        let dbData = dbData.osStr()

        guard let memoCStr = zcashlc_get_received_memo_as_utf8(dbData.0, dbData.1, idNote) else { return  nil }
        
        let memo = String(validatingUTF8: memoCStr)
        zcashlc_string_free(memoCStr)
        return memo
    }

    static func getSentMemoAsUTF8(dbData: URL, idNote: Int64) -> String? {
        let dbData = dbData.osStr()

        guard let memoCStr = zcashlc_get_sent_memo_as_utf8(dbData.0, dbData.1, idNote) else { return nil }

        let memo = String(validatingUTF8: memoCStr)
        zcashlc_string_free(memoCStr)
        return memo
    }

    static func validateCombinedChain(dbCache: URL, dbData: URL) -> Int32 {
        let dbCache = dbCache.osStr()
        let dbData = dbData.osStr()
        return zcashlc_validate_combined_chain(dbCache.0, dbCache.1, dbData.0, dbData.1)
    }

    static func rewindToHeight(dbData: URL, height: Int32) -> Bool {
        let dbData = dbData.osStr()
        return zcashlc_rewind_to_height(dbData.0, dbData.1, height) != 0
    }

    static func scanBlocks(dbCache: URL, dbData: URL) -> Bool {
        let dbCache = dbCache.osStr()
        let dbData = dbData.osStr()
        return zcashlc_scan_blocks(dbCache.0, dbCache.1, dbData.0, dbData.1) != 0
    }

    static func sendToAddress(dbData: URL, account: Int32, extsk: String, to: String, value: Int64, memo: String?, spendParams: URL, outputParams: URL) -> Int64 {
        let dbData = dbData.osStr()
        let spendParams = spendParams.osStr()
        let outputParams = outputParams.osStr()
        let memoBytes = memo ?? ""
        
        return zcashlc_send_to_address(dbData.0, dbData.1, account, extsk, to, value, memoBytes, spendParams.0, spendParams.1, outputParams.0, outputParams.1)
    }
    
}

private extension ZcashRustBackend {
    static func throwDataDbError(_ error: RustWeldingError) -> Error {
        
        if case RustWeldingError.genericError(let message) = error, message.contains("is not empty") {
            return RustWeldingError.dataDbNotEmpty
        }
        return RustWeldingError.dataDbInitFailed(message: error.localizedDescription)
    }
}

private extension URL {
    
    func osStr() -> (String, UInt) {
        let path = self.absoluteString
        return (path, UInt(path.lengthOfBytes(using: .utf8)))
    }
    
}
