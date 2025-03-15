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
    let setUUID = CBUUID(string: "02D958BD-11B0-D9A1-A97A-95C9B3E21341")
    let serviceUUID                          = CBUUID(string: "495466aa-3694-4781-8a49-7141290d95b1")
    let accelerometerXCharacteristicUUID     = CBUUID(string: "eba3df49-861e-4f80-9def-f7ea68ef39d7")
    let accelerometerYCharacteristicUUID     = CBUUID(string: "9b3ed2d6-554e-4e23-898b-e15eb1f72dec")
    let accelerometerZCharacteristicUUID     = CBUUID(string: "621e4bf0-4906-42b7-8111-6d59e4b6e5bd")
    let forceCharacteristicUUID              = CBUUID(string: "8e5416d8-14c0-4a7e-9304-0128d912d500")
    //let batteryPercentageCharacteristicUUID  = CBUUID(string:"6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    //let batteryVoltageCharacteristicUUID     = CBUUID(string:"6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    //let batteryChargeLevelCharacteristicUUID = CBUUID(string:"6E400004-B5A3-F393-E0A9-E50E24DCCA9E")
    //let runsOnBatteryCharacteristicUUID      = CBUUID(string:"6E400005-B5A3-F393-E0A9-E50E24DCCA9E")
    //let isChargingCharacteristicUUID         = CBUUID(string:"6E400006-B5A3-F393-E0A9-E50E24DCCA9E")

   
    var xAcceleration: Float?
    var yAcceleration: Float?
    var zAcceleration: Float?
    var force: Float?
    
    // Store the most recent complete set of values
    var lastSavedX: Float?
    var lastSavedY: Float?
    var lastSavedZ: Float?
    var lastSavedForce: Float?

    // Flags to track new updates
    var newX = false
    var newY = false
    var newZ = false
    var newForce = false

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
        if peripheral.identifier.uuidString == "02D958BD-11B0-D9A1-A97A-95C9B3E21341" {
            discoveredPeripherals.append(peripheral)
            connectToPeripheral(peripheral)  // Connect to the discovered peripheral directly
        }
    }
    
    // Discover services after connecting
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        connectedPeripheral = peripheral
        peripheral.delegate = self
        print("Requesting service discovery for \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices([serviceUUID])
        
    }

    // Discover characteristics after discovering services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("🔍 Checking discovered services for \(peripheral.name ?? "Unknown")")
        
        if let error = error {
            print("❌ Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services, !services.isEmpty else {
            print("⚠️ No services found on \(peripheral.name ?? "Unknown")")
            return
        }

        print("✅ Found \(services.count) services on \(peripheral.name ?? "Unknown")")

        for service in services {
            print("📡 Discovered service: \(service.uuid)")

            if service.uuid == serviceUUID {
                print("🎯 Target service found, discovering characteristics...")
                peripheral.discoverCharacteristics(nil, for: service)  // Discover all characteristics
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
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("⚠️ Disconnected from \(peripheral.name ?? "Unknown")")

        if let error = error {
            print("❌ Disconnection error: \(error.localizedDescription)")
        } else {
            print("ℹ️ Peripheral disconnected normally.")
        }

        // Automatically try to reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🔄 Attempting to reconnect...")
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    

        
    
    
    

    // Handle received data from peripheral
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
                print("Error reading characteristic: \(error.localizedDescription)")
                return
            }

            print("Accel Data received!")
            
            if let value = characteristic.value {
                var receivedData = ""

                if characteristic.uuid == accelerometerXCharacteristicUUID {
                    xAcceleration = value.withUnsafeBytes { $0.load(as: Float.self) }
                    newX = true
                    receivedData = "X Acceleration: \(xAcceleration ?? 0.0)"
                } else if characteristic.uuid == accelerometerYCharacteristicUUID {
                    yAcceleration = value.withUnsafeBytes { $0.load(as: Float.self) }
                    newY = true
                    receivedData = "Y Acceleration: \(yAcceleration ?? 0.0)"
                } else if characteristic.uuid == accelerometerZCharacteristicUUID {
                    zAcceleration = value.withUnsafeBytes { $0.load(as: Float.self) }
                    newZ = true
                    receivedData = "Z Acceleration: \(zAcceleration ?? 0.0)"
                } else if characteristic.uuid == forceCharacteristicUUID {
                    force = value.withUnsafeBytes { $0.load(as: Float.self) }
                    newForce = true
                    receivedData = "Force: \(force ?? 0.0)"
                }

                print(receivedData)

                // Check if we have a full new set of data
                if newX, newY, newZ, newForce,
                   let x = xAcceleration, let y = yAcceleration, let z = zAcceleration, let f = force {
                    
                    // Ensure the new set is different from the last saved one
                    if x != lastSavedX || y != lastSavedY || z != lastSavedZ || f != lastSavedForce {
                        saveDataToCloud(x: x, y: y, z: z, force: f)

                        // Store this set as the last saved one
                        lastSavedX = x
                        lastSavedY = y
                        lastSavedZ = z
                        lastSavedForce = f

                        print("Saved new full data set to CloudKit.")

                    } else {
                        print("Duplicate data detected. Skipping save to CloudKit.")
                    }

                    // Reset flags to wait for the next full set
                    newX = false
                    newY = false
                    newZ = false
                    newForce = false
                }
            }
    }

    // Function to save data to CloudKit
    func saveDataToCloud(x: Float, y: Float, z: Float, force: Float) {
        // Access the custom container "iCloud.test_bucket"
        let container = CKContainer(identifier: "iCloud.test_bucket")
        // Access the public CloudKit database for the custom container
        let database = container.publicCloudDatabase
        let record = CKRecord(recordType: "Mallet_Hits")
      
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
                bluetoothManager.saveDataToCloud(x:42.0,y:42.0,z:42.0,force:100.0)  // Save Bluetooth data to CloudKit
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

