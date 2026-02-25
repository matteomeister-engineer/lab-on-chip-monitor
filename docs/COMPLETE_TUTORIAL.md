# Temperature Monitor Project - Complete Tutorial
## Learn Torizon + Flutter for Medical Device Development

This project simulates a medical device monitoring system similar to TheraMe!'s IVD platform.

## 🎯 Learning Objectives

By completing this project, you'll learn:
- ✅ Torizon embedded Linux basics
- ✅ Docker containerization for embedded systems
- ✅ C++ backend development
- ✅ Flutter UI development
- ✅ REST API communication
- ✅ System architecture for medical devices

## 📁 Project Structure

```
temperature-monitor/
├── backend/
│   ├── sensor_server.cpp      # C++ sensor reader
│   ├── Dockerfile             # Container definition
│   └── CMakeLists.txt         # Build configuration
├── frontend/
│   ├── lib/
│   │   └── main.dart          # Flutter app
│   ├── pubspec.yaml           # Dependencies
│   └── README.md
├── docker-compose.yml         # Multi-container orchestration
└── docs/
    ├── SETUP.md               # Setup instructions
    └── ARCHITECTURE.md        # System design
```

## 🚀 Quick Start (30 minutes)

### Option A: Simulated (No Hardware Required)

1. **Install Prerequisites**
   ```bash
   # Install Docker Desktop
   # Download from: https://www.docker.com/products/docker-desktop
   
   # Install Flutter
   brew install flutter
   flutter doctor
   ```

2. **Clone/Create Project**
   ```bash
   mkdir temperature-monitor
   cd temperature-monitor
   
   # Create backend
   mkdir backend
   cd backend
   # Copy sensor_server.cpp and Dockerfile here
   
   # Create frontend
   cd ..
   flutter create frontend
   cd frontend/lib
   # Replace main.dart with our code
   ```

3. **Build Backend Container**
   ```bash
   cd backend
   docker build -t temp-sensor .
   docker run -p 8080:8080 temp-sensor
   ```

4. **Run Flutter App**
   ```bash
   cd ../frontend
   # Edit main.dart: change apiUrl to "http://localhost:8080/api/temperature"
   flutter run
   ```

### Option B: With Raspberry Pi + Torizon

1. **Flash Raspberry Pi**
   - Download Torizon Easy Installer
   - Flash to SD card using Balena Etcher
   - Boot Raspberry Pi
   - Note the IP address

2. **Deploy Backend**
   ```bash
   # Build on your Mac
   docker build -t temp-sensor ./backend
   
   # Save image
   docker save temp-sensor | gzip > temp-sensor.tar.gz
   
   # Copy to Raspberry Pi
   scp temp-sensor.tar.gz torizon@<PI_IP>:/home/torizon/
   
   # SSH to Pi and load
   ssh torizon@<PI_IP>
   docker load < temp-sensor.tar.gz
   docker run -d -p 8080:8080 temp-sensor
   ```

3. **Run Flutter App**
   ```bash
   # On your Mac
   cd frontend
   # Edit main.dart: change apiUrl to "http://<PI_IP>:8080/api/temperature"
   flutter run
   ```

## 📚 Detailed Learning Path

### Week 1: Torizon Basics
- [ ] Install Docker Desktop
- [ ] Understand containers vs VMs
- [ ] Build simple C++ "Hello World" container
- [ ] Learn docker-compose basics

### Week 2: Backend Development
- [ ] Write C++ sensor simulator
- [ ] Add REST API using cpp-httplib
- [ ] Implement JSON responses
- [ ] Test with curl/Postman

### Week 3: Flutter UI
- [ ] Create basic Flutter app
- [ ] Add HTTP requests
- [ ] Display temperature data
- [ ] Add real-time updates

### Week 4: Integration & Polish
- [ ] Connect Flutter to backend
- [ ] Add charts (fl_chart library)
- [ ] Implement alerts
- [ ] Add data logging

## 🎓 Key Concepts Explained

### 1. Why Containers on Embedded Devices?

**Traditional Approach:**
```
[Raspberry Pi]
  └─ Monolithic application
     - Hard to update
     - One bug crashes everything
     - Difficult to test
```

**Torizon/Container Approach:**
```
[Raspberry Pi with Torizon]
  ├─ Container 1: Sensor Backend (C++)
  ├─ Container 2: Database (PostgreSQL)
  ├─ Container 3: MQTT Broker
  └─ Container 4: Web UI
     - Easy updates (replace one container)
     - Isolated failures
     - Test containers independently
```

### 2. Flutter Architecture

```
┌────────────────────────────────┐
│      Flutter App (Dart)        │
│  ┌──────────────────────────┐  │
│  │   Widgets (UI)           │  │
│  │   - Stateful/Stateless   │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │   Business Logic         │  │
│  │   - State Management     │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │   Data Layer             │  │
│  │   - HTTP, MQTT, WebSoket │  │
│  └──────────────────────────┘  │
└───────────┬────────────────────┘
            │ REST API / MQTT
┌───────────▼────────────────────┐
│   C++ Backend (Torizon)        │
│   - Sensor reading             │
│   - Data processing            │
│   - Hardware control           │
└────────────────────────────────┘
```

### 3. Communication Patterns

**REST API (Simple, request-response):**
```dart
// Flutter
final response = await http.get(Uri.parse('$apiUrl/temperature'));
```

**MQTT (Pub/Sub, real-time):**
```dart
// Flutter subscribes
client.subscribe('sensors/temperature', MqttQos.atLeastOnce);

// Backend publishes
// C++ publishes: topic="sensors/temperature", payload="23.5"
```

**WebSocket (Bidirectional, real-time):**
```dart
// Flutter
final channel = WebSocketChannel.connect(Uri.parse('ws://192.168.1.100:8080'));
channel.stream.listen((data) {
  // Handle real-time updates
});
```

## 🛠 Extending the Project

### Easy Extensions:
1. **Add Multiple Sensors**
   - Humidity sensor
   - Pressure sensor
   - Show all on dashboard

2. **Data Logging**
   - Save to SQLite/PostgreSQL
   - Export to CSV
   - View historical data

3. **Alerts/Notifications**
   - Set temperature thresholds
   - Email/push notifications
   - Visual/audio alarms

### Medium Extensions:
4. **Real-time Charting**
   - Use fl_chart library
   - Show last 60 seconds
   - Zoom/pan capabilities

5. **Remote Configuration**
   - Change sensor update rate
   - Calibration settings
   - Device identification

6. **User Authentication**
   - Login screen
   - Role-based access
   - Audit logging

### Advanced Extensions:
7. **OTA Updates**
   - Remote container updates
   - Rollback capabilities
   - Update scheduling

8. **Multi-Device Support**
   - Multiple sensors/devices
   - Central monitoring dashboard
   - Device discovery

9. **Computer Vision Integration**
   - Add camera feed
   - Image processing (OpenCV)
   - Similar to TheraMe!'s microfluidic chip imaging

## 🎯 Relating to TheraMe! Job

This project teaches you skills directly applicable to TheraMe!:

| Project Component | TheraMe! Equivalent |
|-------------------|---------------------|
| Temperature sensor | Microfluidic sensors |
| C++ backend | Instrument supervision |
| Flutter UI | User interface layer |
| Docker containers | Torizon deployment |
| REST API | IPC communication |
| Data visualization | Test results display |
| Alerts | Diagnostic alerts |

## 📖 Resources

### Torizon
- Torizon Documentation: https://developer.toradex.com/torizon
- Toradex YouTube Channel (excellent tutorials)
- Torizon IDE Extension for VS Code

### Flutter
- Official Flutter Documentation: https://flutter.dev
- Flutter Codelabs (interactive tutorials)
- "Flutter in Action" book by Eric Windmill

### C++ for Embedded
- cpp-httplib: https://github.com/yhirose/cpp-httplib
- Modern C++ for embedded systems
- MQTT C++ client: https://github.com/eclipse/paho.mqtt.cpp

### Docker
- Docker documentation: https://docs.docker.com
- Docker for beginners (YouTube)
- Docker Compose tutorial

## 💡 Pro Tips

1. **Start Simple**: Get basic communication working first, add features later
2. **Use Simulators**: Don't wait for hardware, simulate sensors with random data
3. **Test Incrementally**: Test each layer independently before integration
4. **Document as You Go**: Keep notes on issues and solutions
5. **Version Control**: Use git from day one

## ⏱ Time Investment

- **Basic working system**: 2-3 weekends
- **Polished with charts/UI**: 1 month evenings/weekends
- **Production-ready with tests**: 2-3 months

## 🎓 Next Steps After This Project

1. **Medical Device Compliance**
   - Learn IEC 62304 (software lifecycle)
   - Study FDA/MDR requirements
   - Understand risk management (ISO 14971)

2. **Advanced Topics**
   - Real-time operating systems (RTOS)
   - CAN bus communication
   - Wireless protocols (BLE, WiFi)

3. **Apply to TheraMe!**
   - Include this project in your portfolio
   - Demonstrate understanding of their stack
   - Show you can learn new technologies quickly

Good luck! 🚀
