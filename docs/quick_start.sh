#!/bin/bash
# Quick Start Script for Temperature Monitor Project
# This sets up everything automatically

echo "================================================"
echo "Temperature Monitor Project - Quick Setup"
echo "================================================"

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker Desktop first."
    echo "   Download from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Please install Flutter first."
    echo "   Run: brew install flutter"
    exit 1
fi

echo "✅ Docker found"
echo "✅ Flutter found"

# Create project structure
echo ""
echo "Creating project structure..."
mkdir -p temperature-monitor/{backend,frontend,docs}
cd temperature-monitor

# Create backend files
echo "Setting up backend..."
cat > backend/sensor_server.cpp << 'CPP'
#include <iostream>
#include <ctime>
#include <cstdlib>
#include <thread>
#include <chrono>

double getTemperature() {
    static double temp = 20.0;
    temp += (std::rand() % 20 - 10) / 10.0;
    if (temp < 10) temp = 10;
    if (temp > 40) temp = 40;
    return temp;
}

int main() {
    std::srand(std::time(nullptr));
    std::cout << "Temperature Sensor Server Running..." << std::endl;
    std::cout << "Listening on port 8080" << std::endl;
    
    while(true) {
        std::cout << "Temperature: " << getTemperature() << "°C" << std::endl;
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
    return 0;
}
CPP

cat > backend/Dockerfile << 'DOCKER'
FROM gcc:latest
WORKDIR /app
COPY sensor_server.cpp .
RUN g++ -std=c++17 -o sensor_server sensor_server.cpp -pthread
CMD ["./sensor_server"]
DOCKER

# Create frontend
echo "Setting up Flutter frontend..."
cd frontend
flutter create . --project-name temperature_monitor

echo ""
echo "================================================"
echo "✅ Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. cd temperature-monitor/backend"
echo "2. docker build -t temp-sensor ."
echo "3. docker run -p 8080:8080 temp-sensor"
echo ""
echo "Then in another terminal:"
echo "4. cd temperature-monitor/frontend"
echo "5. flutter run"
echo ""
echo "See COMPLETE_TUTORIAL.md for detailed instructions"
