//
//  CircularBuffer.swift
//  OralableApp
//
//  Created: Refactoring - Performance Optimization
//  Purpose: O(1) append/remove for fixed-size history buffers
//

import Foundation

/// A high-performance circular buffer for storing fixed-size collections
/// Replaces inefficient array.removeFirst() operations with O(1) append
/// Note: Changed to class to work properly with @Published properties
class CircularBuffer<T> {
    // MARK: - Private Properties

    private var buffer: [T]
    private var writeIndex: Int = 0
    private let capacity: Int
    private var count: Int = 0

    // MARK: - Initialization

    /// Creates a circular buffer with the specified capacity
    /// - Parameter capacity: Maximum number of elements to store
    init(capacity: Int) {
        precondition(capacity > 0, "Capacity must be greater than zero")
        self.capacity = capacity
        self.buffer = []
        self.buffer.reserveCapacity(capacity)
    }

    // MARK: - Public Methods

    /// Appends an element to the buffer in O(1) time
    /// If buffer is full, overwrites the oldest element
    /// - Parameter element: Element to append
    func append(_ element: T) {
        if count < capacity {
            buffer.append(element)
            count += 1
            writeIndex = count % capacity
        } else {
            buffer[writeIndex] = element
            writeIndex = (writeIndex + 1) % capacity
        }
    }

    /// Returns all elements in chronological order
    var all: [T] {
        guard count > 0 else { return [] }

        if count < capacity {
            return buffer
        } else {
            // Elements from writeIndex to end, then from start to writeIndex
            return Array(buffer[writeIndex...]) + Array(buffer[..<writeIndex])
        }
    }

    /// Returns the last element added
    var last: T? {
        guard count > 0 else { return nil }
        let lastIndex = writeIndex == 0 ? capacity - 1 : writeIndex - 1
        return buffer[lastIndex]
    }

    /// Returns the first element (oldest)
    var first: T? {
        guard count > 0 else { return nil }
        return count < capacity ? buffer.first : buffer[writeIndex]
    }

    /// Number of elements currently in the buffer
    var currentCount: Int {
        count
    }

    /// Whether the buffer is empty
    var isEmpty: Bool {
        count == 0
    }

    /// Whether the buffer is at capacity
    var isFull: Bool {
        count >= capacity
    }

    /// Removes all elements from the buffer
    func removeAll() {
        buffer.removeAll(keepingCapacity: true)
        writeIndex = 0
        count = 0
    }
}

// MARK: - Collection Conformance

extension CircularBuffer: Collection {
    typealias Index = Int

    var startIndex: Int { 0 }
    var endIndex: Int { count }

    subscript(position: Int) -> T {
        precondition(position >= 0 && position < count, "Index out of bounds")

        if count < capacity {
            return buffer[position]
        } else {
            let actualIndex = (writeIndex + position) % capacity
            return buffer[actualIndex]
        }
    }

    func index(after i: Int) -> Int {
        return i + 1
    }
}

// MARK: - Sequence Conformance

extension CircularBuffer: Sequence {
    func makeIterator() -> Array<T>.Iterator {
        return all.makeIterator()
    }
}

// MARK: - CustomStringConvertible

extension CircularBuffer: CustomStringConvertible {
    var description: String {
        return "CircularBuffer(capacity: \(capacity), count: \(count), elements: \(all))"
    }
}
