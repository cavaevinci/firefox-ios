//
//  Deferred.swift
//  AsyncNetworkServer
//
//  Created by John Gallagher on 7/19/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation

// TODO: Replace this with a class var
public var deferredDefaultQueue = DispatchQueue.global(qos: .default)

open class Deferred<T> {
    typealias UponBlock = (DispatchQueue, (T) -> Void)
    private typealias Protected = (protectedValue: T?, uponBlocks: [UponBlock])

    private var protected: LockProtected<Protected>
    private let defaultQueue: DispatchQueue

    public init(value: T? = nil, defaultQueue: DispatchQueue = deferredDefaultQueue) {
        protected = LockProtected(item: (value, []))
        self.defaultQueue = defaultQueue
    }

    // Check whether or not the receiver is filled
    public var isFilled: Bool {
        return protected.withReadLock { $0.protectedValue != nil }
    }

    private func _fill(value: T, assertIfFilled: Bool) {
        let (filledValue, blocks) = protected.withWriteLock { data -> (T, [UponBlock]) in
            if assertIfFilled {
                precondition(data.protectedValue == nil, "Cannot fill an already-filled Deferred")
                data.protectedValue = value
            } else if data.protectedValue == nil {
                data.protectedValue = value
            }
            let blocks = data.uponBlocks
            data.uponBlocks.removeAll(keepingCapacity: false)
            return (data.protectedValue!, blocks)
        }
        for (queue, block) in blocks {
            queue.async { block(filledValue) }
        }
    }

    open func fill(_ value: T) {
        _fill(value: value, assertIfFilled: true)
    }

    public func fillIfUnfilled(_ value: T) {
        _fill(value: value, assertIfFilled: false)
    }

    public func peek() -> T? {
        return protected.withReadLock { $0.protectedValue }
    }

    public func uponQueue(_ queue: DispatchQueue, block: @escaping (T) -> Void) {
        let maybeValue: T? = protected.withWriteLock { data in
            if data.protectedValue == nil {
                data.uponBlocks.append( (queue, block) )
            }
            return data.protectedValue
        }
        if let value = maybeValue {
            queue.async { block(value) }
        }
    }
}

extension Deferred {
    public var value: T {
        // fast path - return if already filled
        if let val = peek() {
            return val
        }

        // slow path - block until filled
        let group = DispatchGroup()
        var result: T!
        group.enter()
        self.upon { result = $0; group.leave() }
        _ = group.wait(timeout: .distantFuture)
        return result
    }
}

extension Deferred {
    public func bindQueue<U>(_ queue: DispatchQueue, fnc: @escaping (T) -> Deferred<U>) -> Deferred<U> {
        let deff = Deferred<U>()
        self.uponQueue(queue) {
            fnc($0).uponQueue(queue) {
                deff.fill($0)
            }
        }
        return deff
    }

    public func mapQueue<U>(_ queue: DispatchQueue, fnc: @escaping (T) -> U) -> Deferred<U> {
        return bindQueue(queue) { firstValue in Deferred<U>(value: fnc(firstValue)) }
    }
}

extension Deferred {
    public func upon(_ block: @escaping (T) -> Void) {
        uponQueue(defaultQueue, block: block)
    }

    public func bind<U>(_ fnc: @escaping (T) -> Deferred<U>) -> Deferred<U> {
        return bindQueue(defaultQueue, fnc: fnc)
    }

    public func map<U>(_ fnc: @escaping (T) -> U) -> Deferred<U> {
        return mapQueue(defaultQueue, fnc: fnc)
    }
}

extension Deferred {
    public func both<U>(_ other: Deferred<U>) -> Deferred<(T, U)> {
        return self.bind { firstValue in other.map { secondValue in (firstValue, secondValue) } }
    }
}

public func all<T>(_ deferreds: [Deferred<T>]) -> Deferred<[T]> {
    if deferreds.count == 0 {
        return Deferred(value: [])
    }

    let combined = Deferred<[T]>()
    var results: [T] = []
    results.reserveCapacity(deferreds.count)

    var block: ((T) -> Void)!
    block = { firstValue in
        results.append(firstValue)
        if results.count == deferreds.count {
            combined.fill(results)
        } else {
            deferreds[results.count].upon(block)
        }
    }
    deferreds[0].upon(block)

    return combined
}

public func any<T>(_ deferreds: [Deferred<T>]) -> Deferred<Deferred<T>> {
    let combined = Deferred<Deferred<T>>()
    for deffs in deferreds {
        deffs.upon { _ in combined.fillIfUnfilled(deffs) }
    }
    return combined
}
