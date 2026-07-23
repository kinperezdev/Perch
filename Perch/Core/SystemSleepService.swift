import IOKit
import IOKit.pwr_mgt

enum SystemSleepService {
    @MainActor
    static func sleepMac() {
        let connection = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        guard connection != IO_OBJECT_NULL else { return }
        defer { IOServiceClose(connection) }
        IOPMSleepSystem(connection)
    }
}
