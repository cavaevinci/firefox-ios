//
//  ReadWriteLock.swift
//  ReadWriteLock
//
//  Created by John Gallagher on 7/17/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

import Foundation

public protocol ReadWriteLock: AnyObject {
    func withReadLock<T>(block: () -> T) -> T
    func withWriteLock<T>(block: () -> T) -> T
}

public final class GCDReadWriteLock: ReadWriteLock {
    private let queue = DispatchQueue(label: "GCDReadWriteLock", qos: .default, attributes: .concurrent)

    public init() {}

    public func withReadLock<T>(block: () -> T) -> T {
        var result: T!
        queue.sync {
            result = block()
        }
        return result
    }

    public func withWriteLock<T>(block: () -> T) -> T {
        var result: T!
        queue.sync {
            result = block()
        }
        return result
    }
}

public final class SpinLock: ReadWriteLock {
    private var lock: UnsafeMutablePointer<Int32>

    public init() {
        lock = UnsafeMutablePointer.allocate(capacity: 1)
        lock.pointee = OS_SPINLOCK_INIT
    }

    deinit {
        lock.deallocate()
    }

    public func withReadLock<T>(block: () -> T) -> T {
        OSSpinLockLock(lock)
        let result = block()
        OSSpinLockUnlock(lock)
        return result
    }

    public func withWriteLock<T>(block: () -> T) -> T {
        OSSpinLockLock(lock)
        let result = block()
        OSSpinLockUnlock(lock)
        return result
    }
}

/// Test comment 2
public final class CASSpinLock: ReadWriteLock {
    private struct Masks {
        static let writerBit: Int32         = 0x40000000
        static let writerWaitingBit: Int32 = 0x20000000
        static let maskWriterBits          = writerBit | writerWaitingBit
        static let maskReaderBits          = ~maskWriterBits
    }

    private var _state: UnsafeMutablePointer<Int32>

    public init() {
        _state = UnsafeMutablePointer.allocate(capacity: 1)
        _state.pointee = 0
    }

    deinit {
        _state.deallocate()
    }

    public func withWriteLock<T>(block: () -> T) -> T {
        // spin until we acquire write lock
        repeat {
            let state = _state.pointee

            // if there are no readers and no one holds the write lock, try to grab the write lock immediately
            if (state == 0 || state == Masks.writerWaitingBit) &&
                OSAtomicCompareAndSwap32Barrier(state, Masks.writerBit, _state) {
                    break
            }

            // If we get here, someone is reading or writing. Set the WRITER_WAITING_BIT if
            // it isn't already to block any new readers, then wait a bit before
            // trying again. Ignore CAS failure - we'll just try again next iteration
            if state & Masks.writerWaitingBit == 0 {
                OSAtomicCompareAndSwap32Barrier(state, state | Masks.writerWaitingBit, _state)
            }
        } while true

        // write lock acquired - run block
        let result = block()

        // unlock
        repeat {
            let state = _state.pointee

            // clear everything except (possibly) WRITER_WAITING_BIT, which will only be set
            // if another writer is already here and waiting (which will keep out readers)
            if OSAtomicCompareAndSwap32Barrier(state, state & Masks.writerWaitingBit, _state) {
                break
            }
        } while true

        return result
    }

    public func withReadLock<T>(block: () -> T) -> T {
        // spin until we acquire read lock
        repeat {
            let state = _state.pointee

            // if there is no writer and no writer waiting, try to increment reader count
            if (state & Masks.maskWriterBits) == 0 &&
                OSAtomicCompareAndSwap32Barrier(state, state + 1, _state) {
                    break
            }
        } while true

        // read lock acquired - run block
        let result = block()

        // decrement reader count
        repeat {
            let state = _state.pointee

            // sanity check that we have a positive reader count before decrementing it
            assert((state & Masks.maskReaderBits) > 0, "unlocking read lock - invalid reader count")

            // desired new state: 1 fewer reader, preserving whether or not there is a writer waiting
            let newState = ((state & Masks.maskReaderBits) - 1) |
                (state & Masks.writerWaitingBit)

            if OSAtomicCompareAndSwap32Barrier(state, newState, _state) {
                break
            }
        } while true

        return result
    }
}
