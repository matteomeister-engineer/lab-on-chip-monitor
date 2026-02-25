FROM gcc:latest

WORKDIR /app

COPY sensor_server.cpp .
COPY httplib.h .

RUN g++ -std=c++17 -O2 -o sensor_server sensor_server.cpp -pthread -lstdc++fs

VOLUME ["/app/logs"]

CMD ["./sensor_server"]
