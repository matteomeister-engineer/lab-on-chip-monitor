// sensor_server.cpp — Lab-on-Chip Environment Monitor + CSV Data Logger
#include "httplib.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <cstdlib>
#include <ctime>
#include <cmath>
#include <string>
#include <vector>
#include <algorithm>
#include <thread>
#include <mutex>
#include <atomic>
#include <chrono>
#include <filesystem>

namespace fs = std::filesystem;

static const std::string LOG_DIR        = "./logs";
static const int         LOG_INTERVAL_S = 1;
static const int         MAX_FILE_ROWS  = 3600;
static const int         MAX_FILES      = 10;

class Sensor {
    double value, target, noise_scale, min_val, max_val;
public:
    Sensor(double initial, double tgt, double noise, double mn, double mx)
        : value(initial), target(tgt), noise_scale(noise), min_val(mn), max_val(mx) {}
    double read() {
        double diff  = target - value;
        double noise = ((double)std::rand() / RAND_MAX * 2.0 - 1.0) * noise_scale;
        value += diff * 0.05 + noise;
        if (value < min_val) value = min_val;
        if (value > max_val) value = max_val;
        return value;
    }
    double current() const { return value; }
    void setTarget(double t) { target = t; }
};

Sensor tempSensor    (36.5, 37.0, 0.04,  30.0,  45.0);
Sensor humiditySensor(93.0, 95.0, 0.15,  60.0, 100.0);
Sensor co2Sensor     (4.8,   5.0, 0.05,   0.0,  20.0);
Sensor o2Sensor      (20.8, 21.0, 0.08,   0.0,  25.0);
Sensor pressureSensor(1012, 1013, 0.30,  900.0, 1100.0);
Sensor phSensor      (7.38,  7.4, 0.008,  6.0,   8.0);
std::mutex sensorMutex;

std::atomic<bool> loggerRunning(false);
std::string       currentPatientId;
std::string       currentLogFile;
std::mutex        loggerMutex;

std::string alarmLevel(double v, double wlo, double whi, double clo, double chi) {
    if (v < clo || v > chi) return "critical";
    if (v < wlo || v > whi) return "warning";
    return "ok";
}

std::string filename_timestamp(const std::tm& t) {
    char buf[32];
    std::strftime(buf, sizeof(buf), "%Y%m%d_%H%M%S", &t);
    return buf;
}

std::string european_timestamp(const std::chrono::system_clock::time_point& tp) {
    std::time_t t  = std::chrono::system_clock::to_time_t(tp);
    std::tm*    tm = std::localtime(&t);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                  tp.time_since_epoch()) % 1000;
    std::ostringstream o;
    o << std::setfill('0') << std::setw(2) << tm->tm_mday  << "/"
      << std::setfill('0') << std::setw(2) << (tm->tm_mon+1) << "/"
      << (tm->tm_year+1900) << " "
      << std::setfill('0') << std::setw(2) << tm->tm_hour << ":"
      << std::setfill('0') << std::setw(2) << tm->tm_min  << ":"
      << std::setfill('0') << std::setw(2) << tm->tm_sec  << "."
      << std::setfill('0') << std::setw(3) << ms.count();
    return o.str();
}

std::string safe_id(const std::string& id) {
    std::string s = id;
    for (char& c : s)
        if (c=='/'||c=='\\'||c==' '||c==':') c='-';
    return s;
}

std::vector<fs::path> sorted_log_files() {
    std::vector<fs::path> files;
    if (!fs::exists(LOG_DIR)) return files;
    for (auto& e : fs::directory_iterator(LOG_DIR))
        if (e.path().extension() == ".csv")
            files.push_back(e.path());
    std::sort(files.begin(), files.end());
    return files;
}

void enforce_file_limit() {
    auto files = sorted_log_files();
    while ((int)files.size() >= MAX_FILES) {
        std::cout << "[Logger] Deleting oldest: " << files.front() << std::endl;
        fs::remove(files.front());
        files.erase(files.begin());
    }
}

std::ofstream open_new_log(const std::string& patient_id, std::string& out_path) {
    fs::create_directories(LOG_DIR);
    enforce_file_limit();
    auto now      = std::chrono::system_clock::now();
    std::time_t t = std::chrono::system_clock::to_time_t(now);
    std::tm* tm   = std::localtime(&t);
    std::string fname = LOG_DIR + "/env_log_"
        + safe_id(patient_id) + "_" + filename_timestamp(*tm) + ".csv";
    out_path = fname;
    std::ofstream f(fname);
    if (!f.is_open()) {
        std::cerr << "[Logger] ERROR: cannot open " << fname << std::endl;
        return f;
    }
    f << "timestamp,patient_id,"
         "temperature_C,humidity_pct,co2_pct,o2_pct,pressure_mbar,ph,"
         "temp_alarm,humidity_alarm,co2_alarm,o2_alarm,pressure_alarm,ph_alarm\n";
    std::cout << "[Logger] New file: " << fname << std::endl;
    return f;
}

void logger_thread(std::string patient_id) {
    std::string path;
    std::ofstream logfile = open_new_log(patient_id, path);
    currentLogFile = path;
    int rows = 0;
    while (loggerRunning.load()) {
        std::this_thread::sleep_for(std::chrono::seconds(LOG_INTERVAL_S));
        if (!loggerRunning.load()) break;
        double temp, humidity, co2, o2, pressure, ph;
        {
            std::lock_guard<std::mutex> lock(sensorMutex);
            temp     = tempSensor.current();
            humidity = humiditySensor.current();
            co2      = co2Sensor.current();
            o2       = o2Sensor.current();
            pressure = pressureSensor.current();
            ph       = phSensor.current();
        }
        auto now       = std::chrono::system_clock::now();
        std::string ts = european_timestamp(now);
        std::string tA  = alarmLevel(temp,     36.5,37.5, 35.0,39.0);
        std::string hA  = alarmLevel(humidity, 90.0,98.0, 80.0,99.9);
        std::string cA  = alarmLevel(co2,       4.5, 5.5,  3.0, 7.0);
        std::string oA  = alarmLevel(o2,       19.0,22.0, 15.0,24.0);
        std::string pA  = alarmLevel(pressure, 1005,1020,  950,1050);
        std::string phA = alarmLevel(ph,        7.2, 7.6,  6.8, 7.8);
        logfile << std::fixed << std::setprecision(3)
                << ts << "," << patient_id << ","
                << temp << "," << humidity << "," << co2 << ","
                << o2   << "," << pressure << "," << ph  << ","
                << tA << "," << hA << "," << cA << ","
                << oA << "," << pA << "," << phA << "\n";
        logfile.flush();
        rows++;
        if (rows >= MAX_FILE_ROWS) {
            logfile.close();
            std::cout << "[Logger] 1h complete - rolling over." << std::endl;
            logfile = open_new_log(patient_id, path);
            currentLogFile = path;
            rows = 0;
        }
    }
    logfile.close();
    std::cout << "[Logger] Stopped: " << path << std::endl;
}

std::string build_env_json() {
    double temp, humidity, co2, o2, pressure, ph;
    {
        std::lock_guard<std::mutex> lock(sensorMutex);
        temp     = tempSensor.read();
        humidity = humiditySensor.read();
        co2      = co2Sensor.read();
        o2       = o2Sensor.read();
        pressure = pressureSensor.read();
        ph       = phSensor.read();
    }
    auto tA  = alarmLevel(temp,     36.5,37.5, 35.0,39.0);
    auto hA  = alarmLevel(humidity, 90.0,98.0, 80.0,99.9);
    auto cA  = alarmLevel(co2,       4.5, 5.5,  3.0, 7.0);
    auto oA  = alarmLevel(o2,       19.0,22.0, 15.0,24.0);
    auto pA  = alarmLevel(pressure, 1005,1020,  950,1050);
    auto phA = alarmLevel(ph,        7.2, 7.6,  6.8, 7.8);
    std::ostringstream j;
    j << std::fixed << std::setprecision(2);
    j << "{\n"
      << "  \"temperature\":{\"value\":"<<temp<<",\"unit\":\"C\",\"target\":37.0,\"alarm\":\""<<tA<<"\"},\n"
      << "  \"humidity\":{\"value\":"<<humidity<<",\"unit\":\"%RH\",\"target\":95.0,\"alarm\":\""<<hA<<"\"},\n"
      << "  \"co2\":{\"value\":"<<co2<<",\"unit\":\"%\",\"target\":5.0,\"alarm\":\""<<cA<<"\"},\n"
      << "  \"o2\":{\"value\":"<<o2<<",\"unit\":\"%\",\"target\":21.0,\"alarm\":\""<<oA<<"\"},\n"
      << "  \"pressure\":{\"value\":"<<pressure<<",\"unit\":\"mbar\",\"target\":1013.0,\"alarm\":\""<<pA<<"\"},\n"
      << "  \"ph\":{\"value\":"<<std::setprecision(3)<<ph<<",\"unit\":\"pH\",\"target\":7.4,\"alarm\":\""<<phA<<"\"}\n"
      << "}";
    std::cout << std::setprecision(2)
              << "T="<<temp<<"C RH="<<humidity<<"% CO2="<<co2<<"% O2="<<o2
              <<"% P="<<pressure<<"mbar pH="<<std::setprecision(3)<<ph<<std::endl;
    return j.str();
}

int main() {
    std::srand(std::time(nullptr));
    httplib::Server server;
    server.set_default_headers({
        {"Access-Control-Allow-Origin",  "*"},
        {"Access-Control-Allow-Methods", "GET, POST, OPTIONS"},
        {"Access-Control-Allow-Headers", "Content-Type"},
    });

    server.Get("/api/environment", [](const httplib::Request&, httplib::Response& res) {
        res.set_content(build_env_json(), "application/json");
    });

    server.Get("/api/temperature", [](const httplib::Request&, httplib::Response& res) {
        double temp;
        { std::lock_guard<std::mutex> lock(sensorMutex); temp = tempSensor.current(); }
        std::ostringstream j;
        j << std::fixed << std::setprecision(2);
        j << "{\"temperature\":"<<temp<<",\"status\":\"active\"}";
        res.set_content(j.str(), "application/json");
    });

    server.Post("/api/logger/start", [](const httplib::Request& req, httplib::Response& res) {
        std::lock_guard<std::mutex> lock(loggerMutex);
        std::string pid = "UNKNOWN";
        const auto& body = req.body;
        auto pos = body.find("\"patient_id\"");
        if (pos != std::string::npos) {
            auto q1 = body.find('"', pos + 13);
            auto q2 = body.find('"', q1 + 1);
            if (q1 != std::string::npos && q2 != std::string::npos)
                pid = body.substr(q1 + 1, q2 - q1 - 1);
        }
        if (loggerRunning.load()) {
            loggerRunning.store(false);
            std::this_thread::sleep_for(std::chrono::milliseconds(1200));
        }
        currentPatientId = pid;
        loggerRunning.store(true);
        std::thread([pid]() { logger_thread(pid); }).detach();
        std::cout << "[Logger] Session started: " << pid << std::endl;
        res.set_content("{\"status\":\"started\",\"patient_id\":\"" + pid + "\"}", "application/json");
    });

    server.Post("/api/logger/stop", [](const httplib::Request&, httplib::Response& res) {
        std::lock_guard<std::mutex> lock(loggerMutex);
        if (loggerRunning.load()) {
            loggerRunning.store(false);
            std::cout << "[Logger] Session stopped: " << currentPatientId << std::endl;
            res.set_content("{\"status\":\"stopped\",\"file\":\"" + currentLogFile + "\"}", "application/json");
        } else {
            res.set_content("{\"status\":\"not_running\"}", "application/json");
        }
    });

    // POST /api/targets — update sensor targets so simulation drifts toward them
    // body: {"temperature":38.0,"humidity":90.0,"co2":5.5,"o2":21.0,"pressure":1013.0,"ph":7.4}
    server.Post("/api/targets", [](const httplib::Request& req, httplib::Response& res) {
        auto parseField = [&](const std::string& field) -> double {
            auto pos = req.body.find("\"" + field + "\"");
            if (pos == std::string::npos) return -1e9;
            auto colon = req.body.find(':', pos);
            if (colon == std::string::npos) return -1e9;
            try { return std::stod(req.body.substr(colon + 1)); }
            catch (...) { return -1e9; }
        };
        std::lock_guard<std::mutex> lock(sensorMutex);
        double t  = parseField("temperature"); if (t  > -1e8) tempSensor.setTarget(t);
        double h  = parseField("humidity");    if (h  > -1e8) humiditySensor.setTarget(h);
        double c  = parseField("co2");         if (c  > -1e8) co2Sensor.setTarget(c);
        double o  = parseField("o2");          if (o  > -1e8) o2Sensor.setTarget(o);
        double p  = parseField("pressure");    if (p  > -1e8) pressureSensor.setTarget(p);
        double ph = parseField("ph");          if (ph > -1e8) phSensor.setTarget(ph);
        std::cout << "[Targets] Updated — T=" << t << " RH=" << h
                  << " CO2=" << c << " O2=" << o
                  << " P=" << p << " pH=" << ph << std::endl;
        res.set_content("{\"status\":\"ok\"}", "application/json");
    });

    server.Get("/api/logs", [](const httplib::Request&, httplib::Response& res) {
        auto files = sorted_log_files();
        std::ostringstream j;
        j << "{\"files\":[";
        for (int i = 0; i < (int)files.size(); i++) {
            j << "\"" << files[i].filename().string() << "\"";
            if (i + 1 < (int)files.size()) j << ",";
        }
        j << "],\"count\":"<<files.size()<<",\"max\":"<<MAX_FILES
          <<",\"active\":"<<(loggerRunning.load()?"true":"false")
          <<",\"patient\":\""<<currentPatientId<<"\"}";
        res.set_content(j.str(), "application/json");
    });

    server.Get("/api/status", [](const httplib::Request&, httplib::Response& res) {
        res.set_content("{\"status\":\"active\",\"sensors\":6,\"logging\":"
            + std::string(loggerRunning.load()?"true":"false") + "}", "application/json");
    });

    std::cout << "Lab-on-Chip Monitor -> http://0.0.0.0:8080" << std::endl;
    std::cout << "CSV logs            -> " << LOG_DIR << "/" << std::endl;
    std::cout << "Start: POST /api/logger/start | Stop: POST /api/logger/stop" << std::endl;
    server.listen("0.0.0.0", 8080);
    return 0;
}
