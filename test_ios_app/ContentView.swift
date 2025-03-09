import SwiftUI
import CoreBluetooth
import CloudKit

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var discoveredPeripherals: [CBPeripheral] = []  // Store discovered peripherals
    var connectedPeripheral: CBPeripheral?  // Store the connected peripheral
    var receivedData: String = ""  // Store received data to display
    var isConnected: Bool = false
    
    // Define the service and characteristic UUIDs for your device
    let serviceUUID                          = CBUUID(string: "36942633-E957-1222-ABC6-DCEA49C770E4")
    let accelerometerXCharacteristicUUID     = CBUUID(string: "6E400007-B5A3-F393-E0A9-E50E24DCCA9E")
    let accelerometerYCharacteristicUUID     = CBUUID(string: "6E400008-B5A3-F393-E0A9-E50E24DCCA9E")
    let accelerometerZCharacteristicUUID     = CBUUID(string: "6E400009-B5A3-F393-E0A9-E50E24DCCA9E")
    let forceCharacteristicUUID              = CBUUID(string: "6E400010-B5A3-F393-E0A9-E50E24DCCA9E")
    let batteryPercentageCharacteristicUUID  = CBUUID(string:"6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    let batteryVoltageCharacteristicUUID     = CBUUID(string:"6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    let batteryChargeLevelCharacteristicUUID = CBUUID(string:"6E400004-B5A3-F393-E0A9-E50E24DCCA9E")
    let runsOnBatteryCharacteristicUUID      = CBUUID(string:"6E400005-B5A3-F393-E0A9-E50E24DCCA9E")
    let isChargingCharacteristicUUID         = CBUUID(string:"6E400006-B5A3-F393-E0A9-E50E24DCCA9E")

   
    var xAcceleration: Float?
    var yAcceleration: Float?
    var zAcceleration: Float?
    var force: Float?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // Handle the state change for Bluetooth
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on.")
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
        print("Discovered peripheral: \(peripheral.identifier.uuidString ?? "Unknown") \(peripheral.name)")
        if peripheral.identifier.uuidString == "36942633-E957-1222-ABC6-DCEA49C770E4" {
            discoveredPeripherals.append(peripheral)
            connectToPeripheral(peripheral)  // Connect to the discovered peripheral directly
        }
    }
    
    // Discover services after connecting
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    // Discover characteristics after discovering services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Trying to find services?")
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == serviceUUID {
                print("Discovered service: \(service.uuid)")
                peripheral.discoverCharacteristics([accelerometerXCharacteristicUUID, accelerometerYCharacteristicUUID, accelerometerZCharacteristicUUID, forceCharacteristicUUID], for: service)
            }
        }
    }
    // Subscribe to characteristic notifications
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print("Trying to find charateristics")
            if [accelerometerXCharacteristicUUID, accelerometerYCharacteristicUUID, accelerometerZCharacteristicUUID, forceCharacteristicUUID].contains(characteristic.uuid) {
                print("Subscribing to characteristic: \(characteristic.uuid)")
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic) // Force read value
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
                xAcceleration = value.withUnsafeBytes { $0.load(as: Float.self) }
                receivedData = "X Acceleration: \(xAcceleration ?? 0.0)"
            } else if characteristic.uuid == accelerometerYCharacteristicUUID {
                yAcceleration = value.withUnsafeBytes { $0.load(as: Float.self) }
                receivedData = "Y Acceleration: \(yAcceleration ?? 0.0)"
            } else if characteristic.uuid == accelerometerZCharacteristicUUID {
                zAcceleration = value.withUnsafeBytes { $0.load(as: Float.self) }
                receivedData = "Z Acceleration: \(zAcceleration ?? 0.0)"
            } else if characteristic.uuid == forceCharacteristicUUID {
                force = value.withUnsafeBytes { $0.load(as: Float.self) }
                receivedData = "Force: \(force ?? 0.0)"
            }
        }
    }

    // Function to save data to CloudKit
    func saveDataToCloud() {
        // Access the custom container "iCloud.test_bucket"
        let container = CKContainer(identifier: "iCloud.test_bucket")
        // Access the public CloudKit database for the custom container
        let database = container.publicCloudDatabase
        let record = CKRecord(recordType: "Mallet_Hits")
        //Fake Data
        let x: Float = 1.00
        let y: Float = 4.00
        let z: Float = 7.00
        let force: Float = 12.00
        record["Force"] = force as CKRecordValue
        //record["IMU_xyz"] = [Double(x), Double(y), Double(z)] as CKRecordValue
        record["IMU_xyz"] = [
               Double(x), Double(y), Double(z),
               Double(x), Double(y), Double(z),
               Double(x), Double(y), Double(z)
           ] as CKRecordValue
    
        // Save the record to CloudKit
        database.save(record) { savedRecord, error in
            if let error = error {
                print("Error saving record to CloudKit: \(error.localizedDescription)")
            } else {
                print("Successfully saved record to CloudKit: \(String(describing: savedRecord))")
            }
        }
    }

    
    // Fetch the last 10 records for the current user
    func fetchRecentUserRecords(completion: @escaping ([CKRecord]) -> Void) {
        let container = CKContainer(identifier: "iCloud.test_bucket")
        let database = container.publicCloudDatabase
        
        // Fetch the current user record ID
        container.fetchUserRecordID { recordID, error in
            guard let userRecordID = recordID else {
                print("Error fetching user record ID: \(error?.localizedDescription ?? "Unknown")")
                completion([])
                return
            }
            
            // Create a reference to the user record
            let reference = CKRecord.Reference(recordID: userRecordID, action: .none)
            
            // Set up a query with a predicate that filters by the user's ID
            let userPredicate = NSPredicate(format: "creatorUserRecordID == %@", reference)
            let query = CKQuery(recordType: "Mallet_Hits", predicate: userPredicate)
            let sortDescriptor = NSSortDescriptor(key: "___createTime", ascending: false)
            query.sortDescriptors = [sortDescriptor]
            
            let queryOperation = CKQueryOperation(query: query)
            queryOperation.resultsLimit = 10  // Limit the results to 10 records
            var fetchedRecords: [CKRecord] = []  // Array to store the fetched records
            
            // Use the recordMatchedBlock to handle each fetched record
            queryOperation.recordMatchedBlock = { (recordID, result) in
                switch result {
                case .success(let record):
                    print("Fetched record: \(record)")
                    fetchedRecords.append(record)  // Store the fetched record
                case .failure(let error):
                    print("Failed to fetch record with ID \(recordID): \(error.localizedDescription)")
                }
            }
            
            queryOperation.queryCompletionBlock = { cursor, error in
                            if let error = error {
                                print("Error fetching records: \(error.localizedDescription)")
                            }
                            DispatchQueue.main.async {
                                completion(fetchedRecords)
                            }
                        }
            
            // Execute the query operation
            database.add(queryOperation)
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
        print("Connected!")
    }
    
    // Reset and reconnect to the peripheral
    func resetAndReconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            stopScanning()
            startScanning()  // Restart scanning to reconnect
        }
    }
}

struct ContentView: View {
    @State private var bluetoothManager = BluetoothManager()
    @State private var isScanning = false
    @State private var connectionLog: [String] = []  // Log of connection activity
    @State private var records: [CKRecord] = []  // Store the fetched records
    @State private var isAnimating = false  // Animation flag
    
    // Create a basic rotation animation for the mallet image
    @State private var rotation: Double = 0.0
    
    var body: some View {
        VStack {
            Image(systemName: "pencil.circle.fill") // Placeholder for mallet image
                .resizable()
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(rotation))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)
                .onAppear {
                    rotation = 360
                }
            
            Text("Polo Tech Test App")
                .font(.title)
                .foregroundColor(.primary)
            
            Button("Connect to Arduino via BT") {
                if !isScanning {
                    bluetoothManager.startScanning()
                    isScanning = true
                    connectionLog.append("Starting Bluetooth scan...")
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Reset BLE & Reconnect") {
                bluetoothManager.resetAndReconnect()
                connectionLog.append("Reset BLE and trying to reconnect...")
            }
            .buttonStyle(.bordered)
            .padding(.top)
            
            Button("Save Data to CloudKit") {
                bluetoothManager.saveDataToCloud()  // Save Bluetooth data to CloudKit
                connectionLog.append("Saving data to CloudKit...")
            }
            .buttonStyle(.bordered)
            .padding(.top)
            
            Button("Fetch Recent Records") {
                bluetoothManager.fetchRecentUserRecords { fetchedRecords in
                    self.records = fetchedRecords
                    connectionLog.append("Fetched recent records from CloudKit...")
                }
            }
            .buttonStyle(.bordered)
            .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(records, id: \.recordID) { record in
                        VStack(alignment: .leading) {
                            Text("Mallet Hit Record")
                                .font(.headline)
                            Text("Force: \(record["Force"] as? Float ?? 0.0) N")
                            Text("IMU Data: \(record["IMU_xyz"] as? [Double] ?? [])")
                            Divider()
                        }
                        .padding(.vertical)
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

