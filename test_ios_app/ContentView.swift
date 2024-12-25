import SwiftUI
import CoreBluetooth

// BluetoothManager class to handle Bluetooth operations
class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []  // Store discovered peripherals
    var connectedPeripheral: CBPeripheral?  // Store the connected peripheral
    var receivedData: String = ""  // Store received data to display
    var isConnected: Bool = false
    
    // Define the service and characteristic UUIDs for your device
    let serviceUUID = CBUUID(string: "19b10000-0000-0000-0000-000000000001")
    let accelerometerXCharacteristicUUID = CBUUID(string: "19b10000-0000-0000-0000-000000000002")
    let accelerometerYCharacteristicUUID = CBUUID(string: "19b10000-0000-0000-0000-000000000003")
    let accelerometerZCharacteristicUUID = CBUUID(string: "19b10000-0000-0000-0000-000000000004")
    let forceCharacteristicUUID = CBUUID(string: "19b10000-0000-0000-0000-000000000005")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // Handle the state change for Bluetooth
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on.")
            // Now that Bluetooth is on, the app is ready to scan when requested
        case .poweredOff:
            print("Bluetooth is powered off.")
        case .unauthorized:
            print("Bluetooth is unauthorized.")
        case .unsupported:
            print("Bluetooth is unsupported on this device.")
        default:
            print("Bluetooth is in an unknown state.")
        }
    }
    
    // Handle discovered peripherals
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
        // Only add the device with the name you are looking for
        if peripheral.name == "TechPolo_Mallet" {
            discoveredPeripherals.append(peripheral)
            connectToPeripheral(peripheral)  // Connect to the discovered peripheral directly
        }
    }
    
    // Handle successful connection to peripheral
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Successfully connected to peripheral: \(peripheral.name ?? "Unknown")")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])  // Discover specific service
        isConnected = true
    }
    
    // Handle failed connection
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to peripheral: \(peripheral.name ?? "Unknown"), error: \(error?.localizedDescription ?? "Unknown error")")
        isConnected = false
    }
    
    // Handle disconnection
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(peripheral.name ?? "Unknown")")
        isConnected = false
        // Attempt to reconnect if disconnected
        centralManager.connect(peripheral, options: nil)
    }
    
    // Handle discovered services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        for service in peripheral.services ?? [] {
            print("Discovered service: \(service.uuid)")
            // Once services are discovered, discover characteristics
            peripheral.discoverCharacteristics([accelerometerXCharacteristicUUID, accelerometerYCharacteristicUUID, accelerometerZCharacteristicUUID, forceCharacteristicUUID], for: service)
        }
    }
    
    // Handle discovered characteristics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        for characteristic in service.characteristics ?? [] {
            print("Discovered characteristic: \(characteristic.uuid)")
            if characteristic.uuid == accelerometerXCharacteristicUUID ||
                characteristic.uuid == accelerometerYCharacteristicUUID ||
                characteristic.uuid == accelerometerZCharacteristicUUID ||
                characteristic.uuid == forceCharacteristicUUID {
                
                peripheral.setNotifyValue(true, for: characteristic)  // Enable notifications
            }
        }
    }
    
    // Handle received data from peripheral
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error reading characteristic: \(error.localizedDescription)")
            return
        }
        
        if let value = characteristic.value {
            if characteristic.uuid == accelerometerXCharacteristicUUID {
                let x = value.withUnsafeBytes { $0.load(as: Float.self) }
                print("Received X Acceleration: \(x)")
            } else if characteristic.uuid == accelerometerYCharacteristicUUID {
                let y = value.withUnsafeBytes { $0.load(as: Float.self) }
                print("Received Y Acceleration: \(y)")
            } else if characteristic.uuid == accelerometerZCharacteristicUUID {
                let z = value.withUnsafeBytes { $0.load(as: Float.self) }
                print("Received Z Acceleration: \(z)")
            } else if characteristic.uuid == forceCharacteristicUUID {
                let force = value.withUnsafeBytes { $0.load(as: Float.self) }
                print("Received Force: \(force)")
            }
        }
    }
    
    // Start scanning for peripherals
    func startScanning() {
        print("Starting Bluetooth scan...")
        discoveredPeripherals.removeAll()  // Clear the list before scanning
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    // Stop scanning for peripherals
    func stopScanning() {
        print("Stopping Bluetooth scan...")
        centralManager.stopScan()
    }
    
    // Connect to a specific peripheral
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        print("Connecting to \(peripheral.name ?? "Unknown")...")
        centralManager.stopScan()  // Stop scanning when we attempt to connect
        centralManager.connect(peripheral, options: nil)
    }
}

struct ContentView: View {
    @State private var bluetoothManager = BluetoothManager()
    @State private var isScanning = false
    @State private var connectionLog: [String] = []  // Log of connection activity
    
    var body: some View {
        VStack {
            // Main content (Image, Text, Button)
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Polo Tech Test App")
                .font(.title)
                .foregroundColor(.primary)
            
            // Connect to Bluetooth button
            Button("Connect to Arduino via BT") {
                if !isScanning {
                    bluetoothManager.startScanning()
                    isScanning = true
                    connectionLog.append("Starting Bluetooth scan...")
                }
            }
            .buttonStyle(.borderedProminent)
            
            // Display log of connection activity
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(connectionLog, id: \.self) { log in
                        Text(log)
                            .font(.body)
                            .foregroundColor(.gray)
                            .padding(5)
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .onAppear {
            // Add additional setup if needed
        }
        .onDisappear {
            bluetoothManager.stopScanning()  // Ensure scanning is stopped when leaving view
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
