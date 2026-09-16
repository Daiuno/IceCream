//
//  BackgroundWorker.swift
//  IceCream
//
//  Created by Kit Forge on 5/9/19.
//

import Foundation
import RealmSwift

// Based on https://academy.realm.io/posts/realm-notifications-on-background-threads-with-swift/
// Tweaked a little by Yue Cai

class BackgroundWorker: NSObject {

    static let shared = BackgroundWorker()

    private static let workerThreadFlagKey = "IceCream.BackgroundWorker.isWorkerThread"

    private let callLock = NSLock()
    private var thread: Thread?
    private var block: (() -> Void)?
    /// Retained for the lifetime of the worker so `perform(_:on:with:waitUntilDone:modes:)`
    /// does not enumerate a temporary Swift Array.
    private let runLoopModes: [String] = [RunLoop.Mode.default.rawValue]

    func start(_ block: @escaping () -> Void) {
        // CloudKit callbacks must still wait for Realm writes on this thread
        // (`waitUntilDone` semantics). Re-entry cannot take `callLock` while a
        // caller is blocked in `perform`.
        if isOnWorkerThread() {
            block()
            return
        }

        callLock.lock()
        defer { callLock.unlock() }

        if isOnWorkerThread() {
            block()
            return
        }

        ensureThread()
        guard let thread else { return }

        self.block = block
        perform(#selector(runBlock),
                on: thread,
                with: nil,
                waitUntilDone: true,
                modes: runLoopModes)
        self.block = nil
    }

    func stop() {
        thread?.cancel()
    }

    @objc private func runBlock() {
        block?()
    }

    private func isOnWorkerThread() -> Bool {
        if Thread.current.threadDictionary[Self.workerThreadFlagKey] as? Bool == true {
            return true
        }
        guard let thread else { return false }
        return Thread.current === thread
    }

    private func ensureThread() {
        if thread != nil { return }
        let worker = Thread { [weak self] in
            Thread.current.threadDictionary[BackgroundWorker.workerThreadFlagKey] = true
            guard let self = self, let thread = self.thread else {
                Thread.exit()
                return
            }
            while !thread.isCancelled {
                RunLoop.current.run(
                    mode: .default,
                    before: Date.distantFuture)
            }
            Thread.exit()
        }
        worker.name = "IceCream.BackgroundWorker"
        thread = worker
        worker.start()
    }
}
