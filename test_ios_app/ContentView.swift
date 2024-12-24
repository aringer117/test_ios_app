import SwiftUI
import CoreBluetooth
import Charts

// BluetoothManager class to handle Bluetooth operations
class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []  // Store discovered peripherals
    var connectedPeripheral: CBPeripheral?
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
        // Add peripheral to the list if it's not already added
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
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
            peripheral.discoverCharacteristics(nil, for: service)  // Discover all characteristics
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
            if characteristic.uuid == accelerometerXCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == accelerometerYCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == accelerometerZCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == forceCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
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
        centralManager.stopScan()  // Stop scanning when we attempt to connect
        centralManager.connect(peripheral, options: nil)
    }
}

struct ContentView: View {
    // State variables to hold data for the three graphs
    @State private var graph1Data: [(x: Double, y: Double)] = []
    @State private var graph2Data: [(x: Double, y: Double)] = []
    @State private var graph3Data: [(x: Double, y: Double)] = []
    
    // Timer for updating the data
    @State private var timer: Timer? = nil
    
    // To keep track of time for the x-axis (time in seconds)
    @State private var time: Double = 0
    
    // BluetoothManager instance
    @State private var bluetoothManager = BluetoothManager()
    @State private var isScanning = false // Track scanning state
    @State private var selectedPeripheral: CBPeripheral?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Main content (Image, Text, Button)
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Polo Tech Test App")
                    .font(.title)
                    .foregroundColor(.primary)
                
                // Connect to Bluetooth button
                Button("Connect to UUT via BT") {
                    if !isScanning {
                        bluetoothManager.startScanning()
                        isScanning = true
                    }
                }
                .buttonStyle(.borderedProminent)
                
                // Display the list of discovered devices
                if isScanning && !bluetoothManager.discoveredPeripherals.isEmpty {
                    List(bluetoothManager.discoveredPeripherals, id: \.identifier) { peripheral in
                        Text(peripheral.name ?? "Unnamed Device")
                            .onTapGesture {
                                bluetoothManager.connectToPeripheral(peripheral)
                                selectedPeripheral = peripheral
                                isScanning = false  // Stop scanning after a device is selected
                            }
                    }
                    .frame(height: 200)
                    .padding()
                }
                
                // Status Circles (4)
                HStack(spacing: 16) {
                    ForEach(0..<4) { number in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Text("\(number)")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                            .shadow(radius: 2)
                    }
                }
                .padding(.top, 20)
                
                // Graphs (3)
                VStack(spacing: 5) {
                    // Graph 1
                    Chart {
                        ForEach(graph1Data, id: \.x) { entry in
                            LineMark(
                                x: .value("Time", entry.x),
                                y: .value("Value", entry.y)
                            )
                            .foregroundStyle(Color.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .padding()
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .shadow(radius: 5)

                    // Graph 2
                    Chart {
                        ForEach(graph2Data, id: \.x) { entry in
                            LineMark(
                                x: .value("Time", entry.x),
                                y: .value("Value", entry.y)
                            )
                            .foregroundStyle(Color.green)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .padding()
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .shadow(radius: 5)
                    
                    // Graph 3
                    Chart {
                        ForEach(graph3Data, id: \.x) { entry in
                            LineMark(
                                x: .value("Time", entry.x),
                                y: .value("Value", entry.y)
                            )
                            .foregroundStyle(Color.red)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .padding()
                    .frame(height: 200)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .shadow(radius: 5)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 2)
        }
        .onAppear {
            startStreamingData()  // Start streaming data when the view appears
        }
        .onDisappear {
            stopStreamingData()   // Stop streaming data when the view disappears
        }
    }
    
    // Function to start streaming fake data
    private func startStreamingData() {
        // Create a timer to update the data every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Generate random data for each graph
            let randomValue1 = Double.random(in: 0...100)
            let randomValue2 = Double.random(in: 0...100)
            let randomValue3 = Double.random(in: 0...100)
            
            // Increment time by 1 second
            time += 1
            
            // Append new data entries to their respective data arrays
            graph1Data.append((x: time, y: randomValue1))
            graph2Data.append((x: time, y: randomValue2))
            graph3Data.append((x: time, y: randomValue3))
            
            // Keep only the last 50 entries (to simulate scrolling effect)
            if graph1Data.count > 50 { graph1Data.removeFirst() }
            if graph2Data.count > 50 { graph2Data.removeFirst() }
            if graph3Data.count > 50 { graph3Data.removeFirst() }
        }
    }
    
    // Function to stop streaming data when the view disappears
    private func stopStreamingData() {
        timer?.invalidate()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView() // This will show the ContentView in the preview
    }
}

