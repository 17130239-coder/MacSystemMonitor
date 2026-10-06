import XCTest

final class CPUTests: XCTestCase {
    func testUsageIsBusyOverTotalDelta() {
        let a = CPUTicks(user: 100, system: 50, idle: 850, nice: 0)
        let b = CPUTicks(user: 150, system: 70, idle: 930, nice: 0)
        // busy delta = 50 + 20 = 70, total delta = 150
        XCTAssertEqual(CPUUsageCalculator.usage(from: a, to: b)!, 70.0 / 150.0 * 100, accuracy: 0.0001)
    }

    func testNiceCountsAsBusy() {
        let a = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let b = CPUTicks(user: 0, system: 0, idle: 50, nice: 50)
        XCTAssertEqual(CPUUsageCalculator.usage(from: a, to: b)!, 50, accuracy: 0.0001)
    }

    func testFullyBusyAndFullyIdle() {
        let a = CPUTicks(user: 10, system: 10, idle: 10, nice: 0)
        XCTAssertEqual(CPUUsageCalculator.usage(from: a, to: CPUTicks(user: 110, system: 10, idle: 10, nice: 0))!, 100, accuracy: 0.0001)
        XCTAssertEqual(CPUUsageCalculator.usage(from: a, to: CPUTicks(user: 10, system: 10, idle: 110, nice: 0))!, 0, accuracy: 0.0001)
    }

    func testNoElapsedTimeOrCounterRegressionYieldsNil() {
        let a = CPUTicks(user: 10, system: 10, idle: 10, nice: 0)
        XCTAssertNil(CPUUsageCalculator.usage(from: a, to: a))
        XCTAssertNil(CPUUsageCalculator.usage(from: a, to: CPUTicks(user: 5, system: 10, idle: 20, nice: 0)))
    }

    func testServiceUsesBaselineThenReportsUsage() {
        let source = MockCPUSource([
            CPUTicks(user: 0, system: 0, idle: 0, nice: 0),      // baseline taken in init
            CPUTicks(user: 25, system: 0, idle: 75, nice: 0),
        ])
        let service = CPUService(source: source, smoothing: 1)
        XCTAssertEqual(service.sample().value!, 25, accuracy: 0.0001)
    }

    func testServiceSmoothingDampsSpikes() {
        let source = MockCPUSource([
            CPUTicks(user: 0, system: 0, idle: 0, nice: 0),
            CPUTicks(user: 0, system: 0, idle: 100, nice: 0),       // 0 %
            CPUTicks(user: 100, system: 0, idle: 100, nice: 0),     // 100 % raw
        ])
        let service = CPUService(source: source, smoothing: 0.5)
        _ = service.sample()
        XCTAssertEqual(service.sample().value!, 50, accuracy: 0.0001)
    }

    func testServiceReportsErrorWhenSourceFails() {
        let service = CPUService(source: MockCPUSource([CPUTicks(user: 0, system: 0, idle: 0, nice: 0), nil]))
        let value = service.sample()
        XCTAssertEqual(value.availability, .error)
        XCTAssertNil(value.value)
    }

    /// Smoke test against the real kernel: must return a sane number, never crash.
    func testHostSourceReturnsTicks() {
        let ticks = HostCPUTickSource().readTicks()
        XCTAssertNotNil(ticks)
        XCTAssertGreaterThan(ticks?.total ?? 0, 0)
    }
}

final class MemoryTests: XCTestCase {
    func testUsedIsAppPlusWiredPlusCompressed() {
        let s = VMStatistics(internalPages: 1000, purgeablePages: 100, wiredPages: 200, compressedPages: 50, pageSize: 16384)
        XCTAssertEqual(MemoryCalculator.usedBytes(s), (900 + 200 + 50) * 16384)
    }

    func testPurgeableLargerThanInternalDoesNotUnderflow() {
        let s = VMStatistics(internalPages: 10, purgeablePages: 50, wiredPages: 5, compressedPages: 5, pageSize: 4096)
        XCTAssertEqual(MemoryCalculator.usedBytes(s), 10 * 4096)
    }

    func testServicePercentage() {
        let pages = (8 * Fixtures.gib) / 16384
        let s = VMStatistics(internalPages: pages, purgeablePages: 0, wiredPages: 0, compressedPages: 0, pageSize: 16384)
        let value = MemoryService(source: MockVM(stats: s), totalBytes: 16 * Fixtures.gib).sample().value!
        XCTAssertEqual(value.percent, 50, accuracy: 0.0001)
        XCTAssertEqual(value.totalBytes, 16 * Fixtures.gib)
    }

    func testUsedIsClampedToTotal() {
        let s = VMStatistics(internalPages: 1_000_000, purgeablePages: 0, wiredPages: 0, compressedPages: 0, pageSize: 16384)
        let value = MemoryService(source: MockVM(stats: s), totalBytes: Fixtures.gib).sample().value!
        XCTAssertEqual(value.percent, 100, accuracy: 0.0001)
    }

    func testSourceFailureIsAnErrorNotACrash() {
        let v = MemoryService(source: MockVM(stats: nil), totalBytes: Fixtures.gib).sample()
        XCTAssertEqual(v.availability, .error)
    }

    func testMemoryStringFormatting() {
        XCTAssertEqual(ByteFormatter.memoryString(used: UInt64(8.4 * Double(Fixtures.gib)), total: 16 * Fixtures.gib), "8.4 / 16 GB")
        XCTAssertEqual(ByteFormatter.memoryString(used: UInt64(12.7 * Double(Fixtures.gib)), total: 32 * Fixtures.gib), "12.7 / 32 GB")
        XCTAssertEqual(ByteFormatter.memoryString(used: 8 * Fixtures.gib, total: 16 * Fixtures.gib), "8 / 16 GB")
    }

    func testRealTotalIsDetected() {
        XCTAssertEqual(MemoryService().sample().value?.totalBytes, ProcessInfo.processInfo.physicalMemory)
    }
}
