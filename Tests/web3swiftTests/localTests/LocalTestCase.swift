import Foundation
import XCTest
import BigInt
import Web3Core

import web3swift

// SuperClass that all local tests should be derived from
// while this class does show up in the navigator, it has no associated tests
class LocalTestCase: XCTestCase {

    static let url = URL(string: "http://127.0.0.1:8545")!
    static let keyStoreManager: KeystoreManager = KeystoreManager([try! EthereumKeystoreV3(password: "web3swift")!])

    override func setUp() async throws {
        let web3 = try await Web3.new(LocalTestCase.url)
        let block = try await web3.eth.blockNumber()
        guard block < 25 else { return }

        let allAddresses = try await web3.eth.ownedAccounts()
        let address = try XCTUnwrap(allAddresses.first)
        let contract = try XCTUnwrap(
            web3.contract(Web3.Utils.coldWalletABI, at: address, abiVersion: 2)
        )
        let value = try XCTUnwrap(Utilities.parseToBigUInt("1.0", units: .ether))
        let policies = Policies(
            noncePolicy: .pending,
            gasLimitPolicy: .manual(78_423),
            gasPricePolicy: .manual(20_000_000_000)
        )

        for _ in block..<25 {
            let writeTransaction = try XCTUnwrap(
                contract.createWriteOperation("fallback")
            )
            writeTransaction.transaction.from = address
            writeTransaction.transaction.value = value

            _ = try await writeTransaction.writeToChain(
                password: "",
                policies: policies,
                sendRaw: false
            )
        }
    }

    func deployContract(bytecode: Data, abiString: String) async throws -> TransactionReceipt {
        let web3 = try await Web3.new(LocalTestCase.url)
        let allAddresses = try await web3.eth.ownedAccounts()
        let contract = web3.contract(abiString, at: nil, abiVersion: 2)!

        let parameters: [Any] = []
        // MARK: Writing Data flow
        let deployTx = contract.prepareDeploy(bytecode: bytecode, parameters: parameters)!
        deployTx.transaction.from = allAddresses[0]
        let policies = Policies(gasLimitPolicy: .manual(3000000))
        let result = try await deployTx.writeToChain(password: "web3swift", policies: policies, sendRaw: false)
        let txHash = result.hash.stripHexPrefix()
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let receipt = try await web3.eth.transactionReceipt(Data.fromHex(txHash)!)
        return receipt
    }
}
