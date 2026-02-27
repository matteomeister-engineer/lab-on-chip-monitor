#include "httplib.h"
#include <opencv2/opencv.hpp>
#include <iostream>
#include <vector>
#include <algorithm>
#include <cstdlib>
#include <ctime>
#include <cmath>
#include <sstream>
#include <iomanip>
#include <string>

struct DrugEntry { std::string name, category; double survival_rate; };

static const std::vector<DrugEntry> DRUGS = {
    {"Paclitaxel",       "Taxane",               0.18},
    {"Doxorubicin",      "Anthracycline",         0.22},
    {"Cisplatin",        "Platinum agent",        0.30},
    {"Gemcitabine",      "Antimetabolite",        0.42},
    {"Cyclophosphamide", "Alkylating agent",      0.38},
    {"Carboplatin",      "Platinum agent",        0.35},
    {"Vincristine",      "Vinca alkaloid",        0.45},
    {"Methotrexate",     "Antimetabolite",        0.50},
    {"Fluorouracil",     "Antimetabolite",        0.55},
    {"Irinotecan",       "Topoisomerase inh.",    0.40},
    {"Etoposide",        "Topoisomerase inh.",    0.48},
    {"Oxaliplatin",      "Platinum agent",        0.33},
    {"Docetaxel",        "Taxane",                0.20},
    {"Imatinib",         "Tyrosine kinase inh.",  0.28},
    {"Trastuzumab",      "Monoclonal antibody",   0.36},
    {"Bevacizumab",      "Anti-angiogenic",       0.60},
    {"Pemetrexed",       "Antimetabolite",        0.52},
    {"Temozolomide",     "Alkylating agent",      0.44},
    {"Erlotinib",        "EGFR inhibitor",        0.32},
    {"Control (None)",   "Negative control",      0.92},
};

struct WellResult {
    int well_index, total_cells, alive_cells, dead_cells;
    std::string drug_name, drug_category, frame_b64;
    double viability, efficacy;
};

cv::Mat generate_well_frame(double survival_rate, int width=320, int height=320) {
    cv::Mat frame(height, width, CV_8UC1, cv::Scalar(12));
    cv::Mat noise(height, width, CV_8UC1);
    cv::randn(noise, 4, 2);
    frame += noise;
    int num_cells = 25 + std::rand() % 15;
    for (int i = 0; i < num_cells; i++) {
        double cx = 20 + std::rand() % (width  - 40);
        double cy = 20 + std::rand() % (height - 40);
        double r  = 7  + std::rand() % 10;
        bool alive = ((double)std::rand() / RAND_MAX) < survival_rate;
        int intensity = alive ? (150 + std::rand() % 90) : (20 + std::rand() % 30);
        double dr = alive ? r : r * 0.70;
        for (int dy = -(int)dr-4; dy <= (int)dr+4; dy++) {
            for (int dx = -(int)dr-4; dx <= (int)dr+4; dx++) {
                int px=(int)cx+dx, py=(int)cy+dy;
                if (px<0||px>=width||py<0||py>=height) continue;
                double dist=std::sqrt(dx*dx+dy*dy);
                if (dist>dr+4) continue;
                double falloff=std::exp(-0.5*std::pow(dist/dr,2));
                int val=std::min(255,(int)(frame.at<uchar>(py,px)+intensity*falloff));
                frame.at<uchar>(py,px)=(uchar)val;
            }
        }
    }
    return frame;
}

std::vector<cv::KeyPoint> detect_blobs(const cv::Mat& frame) {
    cv::SimpleBlobDetector::Params p;
    p.filterByColor=true; p.blobColor=255;
    p.filterByArea=true; p.minArea=30; p.maxArea=3000;
    p.filterByCircularity=true; p.minCircularity=0.3;
    p.filterByConvexity=true; p.minConvexity=0.5;
    p.minThreshold=25; p.maxThreshold=220; p.thresholdStep=10;
    auto det=cv::SimpleBlobDetector::create(p);
    std::vector<cv::KeyPoint> kps;
    det->detect(frame,kps);
    return kps;
}

bool classify_blob(const cv::Mat& frame, const cv::KeyPoint& kp) {
    cv::Mat mask=cv::Mat::zeros(frame.size(),CV_8UC1);
    cv::circle(mask,cv::Point((int)kp.pt.x,(int)kp.pt.y),std::max(3,(int)(kp.size/2)),255,-1);
    return cv::mean(frame,mask)[0]>75.0;
}

cv::Mat annotate_well(const cv::Mat& gray, const std::vector<cv::KeyPoint>& kps,
                      const std::string& drug, double efficacy) {
    cv::Mat bgr;
    cv::cvtColor(gray,bgr,cv::COLOR_GRAY2BGR);
    for (auto& kp:kps) {
        bool a=classify_blob(gray,kp);
        cv::Scalar col=a?cv::Scalar(60,200,60):cv::Scalar(60,60,220);
        cv::circle(bgr,cv::Point((int)kp.pt.x,(int)kp.pt.y),(int)(kp.size/2)+2,col,2);
    }
    std::string label=drug.size()>14?drug.substr(0,14):drug;
    cv::putText(bgr,label,cv::Point(4,15),cv::FONT_HERSHEY_SIMPLEX,0.38,cv::Scalar(200,200,200),1);
    std::ostringstream eff;
    eff<<std::fixed<<std::setprecision(0)<<efficacy<<"% eff.";
    cv::putText(bgr,eff.str(),cv::Point(4,bgr.rows-5),cv::FONT_HERSHEY_SIMPLEX,0.35,cv::Scalar(100,220,100),1);
    return bgr;
}

std::string b64(const std::vector<uchar>& data) {
    static const char* T="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string out; out.reserve(((data.size()+2)/3)*4);
    for (size_t i=0;i<data.size();i+=3) {
        uint32_t v=(uint32_t)data[i]<<16;
        if(i+1<data.size()) v|=(uint32_t)data[i+1]<<8;
        if(i+2<data.size()) v|=data[i+2];
        out+=T[(v>>18)&63]; out+=T[(v>>12)&63];
        out+=(i+1<data.size())?T[(v>>6)&63]:'=';
        out+=(i+2<data.size())?T[v&63]:'=';
    }
    return out;
}

std::string run_full_analysis() {
    std::vector<WellResult> wells;
    for (int i=0;i<(int)DRUGS.size();i++) {
        const auto& d=DRUGS[i];
        cv::Mat frame=generate_well_frame(d.survival_rate);
        auto kps=detect_blobs(frame);
        int alive=0,dead=0;
        for (auto& kp:kps) classify_blob(frame,kp)?alive++:dead++;
        int total=alive+dead;
        double viability=total>0?(100.0*alive/total):0.0;
        double efficacy=100.0-viability;
        cv::Mat ann=annotate_well(frame,kps,d.name,efficacy);
        std::vector<uchar> buf;
        cv::imencode(".png",ann,buf);
        WellResult w;
        w.well_index=i; w.drug_name=d.name; w.drug_category=d.category;
        w.total_cells=total; w.alive_cells=alive; w.dead_cells=dead;
        w.viability=viability; w.efficacy=efficacy; w.frame_b64=b64(buf);
        wells.push_back(w);
        std::cout<<"  Well "<<std::setw(2)<<i<<" ["<<d.name<<"] efficacy="
                 <<std::fixed<<std::setprecision(1)<<efficacy<<"%"<<std::endl;
    }
    std::vector<WellResult*> ranked;
    for (auto& w:wells) ranked.push_back(&w);
    std::sort(ranked.begin(),ranked.end(),[](const WellResult* a,const WellResult* b){return a->efficacy>b->efficacy;});
    std::ostringstream j;
    j<<std::fixed<<std::setprecision(1);
    j<<"{\n";
    j<<"  \"best_drug\":\""<<ranked[0]->drug_name<<"\",\n";
    j<<"  \"best_efficacy\":"<<ranked[0]->efficacy<<",\n";
    j<<"  \"best_category\":\""<<ranked[0]->drug_category<<"\",\n";
    j<<"  \"ranked\":[\n";
    for (int r=0;r<std::min(5,(int)ranked.size());r++) {
        auto* w=ranked[r];
        j<<"    {\"rank\":"<<(r+1)<<",\"drug\":\""<<w->drug_name<<"\",\"category\":\""
         <<w->drug_category<<"\",\"efficacy\":"<<w->efficacy<<",\"viability\":"
         <<w->viability<<",\"well_index\":"<<w->well_index<<"}";
        if(r<4) j<<",";
        j<<"\n";
    }
    j<<"  ],\n";
    j<<"  \"wells\":[\n";
    for (int i=0;i<(int)wells.size();i++) {
        const auto& w=wells[i];
        j<<"    {\"well_index\":"<<w.well_index<<",\"drug\":\""<<w.drug_name
         <<"\",\"category\":\""<<w.drug_category<<"\",\"total_cells\":"<<w.total_cells
         <<",\"alive_cells\":"<<w.alive_cells<<",\"dead_cells\":"<<w.dead_cells
         <<",\"viability\":"<<w.viability<<",\"efficacy\":"<<w.efficacy
         <<",\"frame_b64\":\""<<w.frame_b64<<"\"}";
        if(i+1<(int)wells.size()) j<<",";
        j<<"\n";
    }
    j<<"  ]\n}";
    return j.str();
}

int main() {
    std::srand(std::time(nullptr));
    httplib::Server server;
    server.set_default_headers({
        {"Access-Control-Allow-Origin","*"},
        {"Access-Control-Allow-Methods","GET, OPTIONS"},
        {"Access-Control-Allow-Headers","Content-Type"},
    });
    server.Get("/api/analyze",[](const httplib::Request&,httplib::Response& res){
        std::cout<<"\nRunning 20-well oncology analysis..."<<std::endl;
        std::string json=run_full_analysis();
        std::cout<<"Complete."<<std::endl;
        res.set_content(json,"application/json");
    });
    server.Get("/api/status",[](const httplib::Request&,httplib::Response& res){
        res.set_content("{\"status\":\"active\",\"wells\":20}","application/json");
    });
    std::cout<<"Oncology analyzer on http://0.0.0.0:8081"<<std::endl;
    int port = 8081;  // fallback for local dev

if (std::getenv("PORT")) {
    port = std::stoi(std::getenv("PORT"));
}

server.listen("0.0.0.0", port);
    return 0;
}
