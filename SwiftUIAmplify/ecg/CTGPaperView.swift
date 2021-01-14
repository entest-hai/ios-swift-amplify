//
//  CTGPaperView.swift
//  SwiftUIAmplify
//
//  Created by hai on 12/1/21.
//  Copyright © 2021 biorithm. All rights reserved.
//  13 JAN 2021 created SimulatedHeartRateModel and HeartRateTableViewModel 

import SwiftUI
import Amplify
import Combine
import AmplifyPlugins

// TODO constant.swift
let timerPeriod: Int = 1
let maxScreenLength : Int = 4800

// MARK: - Simulate heart rate using timer
// TODO: - Timer in background
class SimulateHeartRateModel : ObservableObject {
    private var constBeats = [Double]()
    @Published var beats = [Double]()
    let numBeatPerUpdate = 20
    var counter: Int = 0
    
    func simulateRealTimeHeartRate(){
        if self.constBeats.count == 0 {
            self.loadHeartRateFromFile()
            self.constBeats = self.beats
            self.beats.removeAll()
        }
        
        if self.constBeats.count > (self.counter + 1) * self.numBeatPerUpdate {
            for i in 0..<self.numBeatPerUpdate {
                self.beats.append(self.constBeats[Int(self.counter * self.numBeatPerUpdate) + i])
            }
            self.counter += 1
        } else {
            //            self.isActive = false
        }
    }
    
    func loadHeartRateFromFile() {
        var allWords = [String]()
        if let startWordsURL = Bundle.main.url(forResource: "heartrate", withExtension: "txt") {
            if let startWords = try? String(contentsOf: startWordsURL) {
                allWords = startWords.components(separatedBy: "\n")
                for i in 0..<allWords.count {
                    let beat = Double(allWords[i]) ?? 0.0
                    self.beats.append(beat==Double.nan ? 0.0 : beat)
                }
            }
        }
        if allWords.isEmpty {
            allWords = ["NaN"]
            print(allWords)
        }
    }
    
}

// MARK: - Observe heart rate tabel from DB
class HeartRateViewModel : ObservableObject {
    var isoformatter = ISO8601DateFormatter.init()
    @Published var bufferBeats = [HeartRate]()
    @Published var bufferMHR = [Double]()
    @Published var bufferTime = [Temporal.DateTime]()
    @Published var bufferFHR = [Double]()
    
    // MARK: - Fetch heart rate from DB
    func loadHeartRateFromDB() {
        Amplify.DataStore.query(HeartRate.self){result in
            switch result {
            case .success(let beats):
                self.bufferBeats = beats.sorted(by: { $0.time![0].foundationDate < $1.time![0].foundationDate })
                for beat in self.bufferBeats {
                    self.bufferFHR.append(contentsOf: beat.fHR ?? [0.0])
                    self.bufferMHR.append(contentsOf: beat.mHR ?? [0.0])
                    self.bufferTime.append(contentsOf: beat.time!)
                }
                print("number of bea \(self.bufferBeats.count)")
            case .failure(let error):
                print(error)
            }
        }
    }
    
    // MARK: - Observe DB table
    @State var token: AnyCancellable?
    func observeHeartRatesDBTable(){
        token = Amplify.DataStore.publisher(for: HeartRate.self).sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print(error)
                }
        }, receiveValue: { event in
            do {
                let beats = try event.decodeModel(as: HeartRate.self)
                self.bufferBeats.append(beats)
                self.bufferBeats = self.bufferBeats.sorted(by: { $0.time![0].foundationDate < $1.time![0].foundationDate })
                
                //TODO: efficient by remove this copy and sort each update
                self.bufferFHR.removeAll()
                self.bufferMHR.removeAll()
                self.bufferTime.removeAll()
                
                for beat in self.bufferBeats {
                    self.bufferFHR.append(contentsOf: beat.fHR ?? [0.0])
                    self.bufferMHR.append(contentsOf: beat.mHR ?? [0.0])
                    self.bufferTime.append(contentsOf: beat.time!)
                }
            } catch {
                print(error)
            }
        })
    }
}

//MARK: - Plot heart rate line
//TODO: Skip when NaN and update DB schema with better DateTime for sorting
struct HeartRateLine : Shape {
    @State var beats: [Double]
    
    // TODO constant
    let heartRatePeriod : Double = 0.25
    let minHeartRate : Double = 30
    let maxHeartRate : Double = 240
    let minTime : Double = 0
    let maxTime : Double = 1200
    
    func heartRateToHeight(beat : Double) -> CGFloat {
        return CGFloat((maxHeartRate - beat) / (maxHeartRate - minHeartRate))
    }
    
    func timeToWidth(time: Double) -> CGFloat {
        return CGFloat((time - minTime) / (maxTime - minTime))
    }
    
    func path(in rect: CGRect) -> Path {
        let offset = self.beats.count < maxScreenLength ? 0 : self.beats.count - maxScreenLength
        var path = Path()
        var prevTime : Double = 0
        var nextTime : Double = 0
        var prevBeat : Double = 150
        var nextBeat : Double = 150
        
        for i in offset..<self.beats.count {
            path.move(to: CGPoint(x: rect.maxX * timeToWidth(time: prevTime),
                                  y: rect.maxY * heartRateToHeight(beat: prevBeat)))
            path.addLine(to: CGPoint(x: rect.maxX * timeToWidth(time: nextTime),
                                     y: rect.maxY * heartRateToHeight(beat: nextBeat)))
            prevTime = nextTime
            nextTime = Double(i - offset) * heartRatePeriod
            prevBeat = nextBeat
            nextBeat = self.beats[i]
        }
        return path
    }
}

// MARK: - Create CTGPaper with given box size using GeometryReader for calculating size
// TODO: - Extract constants and parameters for CTGPaper
struct CTGPaper : View {
    var horizontalSpacing: CGFloat = 20
    var verticalSpacing: CGFloat = 20
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(){
                Path { path in
                    let numberOfHorizontalGridLines = Int(geometry.size.height / self.verticalSpacing)
                    let numberOfVerticalGridLines = Int(geometry.size.width / self.horizontalSpacing)
                    for index in 0...numberOfVerticalGridLines {
                        let vOffset: CGFloat = CGFloat(index) * self.horizontalSpacing
                        path.move(to: CGPoint(x: vOffset, y: 0))
                        path.addLine(to: CGPoint(x: vOffset, y: geometry.size.height))
                    }
                    for index in 0...numberOfHorizontalGridLines {
                        let hOffset: CGFloat = CGFloat(index) * self.verticalSpacing
                        path.move(to: CGPoint(x: 0, y: hOffset))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: hOffset))
                    }
                }
                .stroke(Color.blue, lineWidth: 0.5)
            }
            VStack(spacing: (geometry.size.height - 100)/10){
                ForEach((0 ..< 10).reversed(), id: \.self){idx in
                    Text("\(30 + 20*idx)")
                        .frame(width: 40, height: 10)
                        .font(.system(size: 12))
                }
                Spacer()
            }
            .frame(width: 20)
            .background(Color.blue.opacity(0.5))
            VStack(){
                Spacer()
                HStack(spacing: (geometry.size.width - 800)/10){
                    ForEach((0 ..< 20 ), id: \.self){idx in
                        Text("\(idx)")
                            .frame(width: 40, height: 10)
                            .font(.system(size: 12))
                    }
                    Spacer()
                }
                .frame(height: 20)
                .background(Color.purple.opacity(0.5))
            }
        }
    }
}

// MARK: - Final CTGPaperView with data loaded from observed table 
struct CTGPaperView: View {
    @ObservedObject var heartRateTableModel = HeartRateViewModel()
    @ObservedObject var simulateHeartRateModel = SimulateHeartRateModel()
    var body: some View {
        ZStack(){
            Color.white.opacity(0.2).edgesIgnoringSafeArea(.all)
            ZStack(){
                CTGPaper()
                HeartRateLine(beats: self.bufferFHR)
                    .stroke(Color.red, lineWidth: 1.2)
                HeartRateLine(beats: self.bufferMHR)
                .stroke(Color.black, lineWidth: 1.2)
                VStack(){
                    Text("\(self.bufferFHR.count): beat")
                        .frame(width: 150, height: 30)
                        .background(Color.green.opacity(0.5))
                        .cornerRadius(5)
                    Spacer()
                }
            }
            .onAppear(perform: {
                //                _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
                //                    self.simulateHeartRateModel.simulateRealTimeHeartRate()
                //                })
                //                                        self.simulateHeartRateModel.loadHeartRateFromFile()
                self.loadHeartRateFromDB()
                self.observeHeartRatesDBTable()
            })
        }
    }
    
    var isoformatter = ISO8601DateFormatter.init()
    @State var bufferBeats = [HeartRate]()
    @State var bufferMHR = [Double]()
    @State var bufferTime = [Temporal.DateTime]()
    @State var bufferFHR = [Double]()
       
       // MARK: - Fetch heart rate from DB
       func loadHeartRateFromDB() {
           Amplify.DataStore.query(HeartRate.self){result in
               switch result {
               case .success(let beats):
                   self.bufferBeats = beats.sorted(by: { $0.time![0].foundationDate < $1.time![0].foundationDate })
                   for beat in self.bufferBeats {
                       self.bufferFHR.append(contentsOf: beat.fHR ?? [0.0])
                       self.bufferMHR.append(contentsOf: beat.mHR ?? [0.0])
                       self.bufferTime.append(contentsOf: beat.time!)
                   }
                   print("number of bea \(self.bufferBeats.count)")
               case .failure(let error):
                   print(error)
               }
           }
       }
       
       // MARK: - Observe DB table
       @State var token: AnyCancellable?
       func observeHeartRatesDBTable(){
           token = Amplify.DataStore.publisher(for: HeartRate.self).sink(
               receiveCompletion: { completion in
                   if case .failure(let error) = completion {
                       print(error)
                   }
           }, receiveValue: { event in
               do {
                   let beats = try event.decodeModel(as: HeartRate.self)
                   self.bufferBeats.append(beats)
                   self.bufferBeats = self.bufferBeats.sorted(by: { $0.time![0].foundationDate < $1.time![0].foundationDate })
                   
                   //TODO: efficient by remove this copy and sort each update
                   self.bufferFHR.removeAll()
                   self.bufferMHR.removeAll()
                   self.bufferTime.removeAll()
                   
                   for beat in self.bufferBeats {
                       self.bufferFHR.append(contentsOf: beat.fHR ?? [0.0])
                       self.bufferMHR.append(contentsOf: beat.mHR ?? [0.0])
                       self.bufferTime.append(contentsOf: beat.time!)
                   }
               } catch {
                   print(error)
               }
           })
       }
}

