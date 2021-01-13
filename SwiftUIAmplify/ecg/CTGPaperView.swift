//
//  CTGPaperView.swift
//  SwiftUIAmplify
//
//  Created by hai on 12/1/21.
//  Copyright © 2021 biorithm. All rights reserved.
//

import SwiftUI
import Amplify
import Combine
import AmplifyPlugins

// TODO constant.swift
let timerPeriod: Int = 1
let maxScreenLength : Int = 4800

struct HeartRateLine : Shape {
    @State var beats: [Double]
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

struct CTGGrid : Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for i in 0...20 {
            let stepY = CGFloat(i) * rect.maxY / 20
            path.move(to: CGPoint(x: 0, y: stepY))
            path.addLine(to: CGPoint(x:UIScreen.main.bounds.width,y: stepY))
        }
        
        for i in 0...40 {
            let stepX = CGFloat(i) * rect.maxX / 40
            path.move(to: CGPoint(x: stepX, y: 0))
            path.addLine(to: CGPoint(x: stepX, y: rect.maxY))
        }
        return path
    }
}

struct HeartRateAxis : View {
    var body: some View {
        VStack(spacing: UIScreen.main.bounds.height / 18.2){
                ForEach((0...10).reversed(), id: \.self) {i in
                    Text("\(30 + i * 20)")
                        .font(.system(size: 12))
                }
            }
        }
}

struct TimeAxis : View {
    var body: some View {
        HStack(spacing: UIScreen.main.bounds.width / 30){
            ForEach((1...20), id: \.self) {i in
                Text("\(i)")
                    .font(.system(size: 12))
            }
        }
    }
}

struct CTGPaperView: View {
    //
    var isoformatter = ISO8601DateFormatter.init()
    @State var bufferBeats = [HeartRate]()
    @State var bufferTime = [Temporal.DateTime]()
    @State var bufferMHR: [Double] = [Double]()
    @State var bufferFHR: [Double] = [Double]()
    
    let numBeatPerUpdate: Int = 20
    @State private var isActive = false
    @State var constBeats: [Double] = [150]
    let timer = Timer.publish(every: TimeInterval(timerPeriod),
                              on: .main, in: .common).autoconnect()
    @State var counter: Int = 0
    @State var beats: [Double] = [150]
    var body: some View {
        ZStack(){
            Color.white.opacity(0.2).edgesIgnoringSafeArea(.all)
            ZStack(){
                CTGGrid()
                    .stroke(Color.blue, lineWidth: 0.3)
                HStack(){
                    HeartRateAxis()
                    Spacer()
                }
                VStack(){
                    Spacer()
                    TimeAxis()
                        .padding(.leading, 5)
                }
                
                HeartRateLine(beats: self.bufferMHR)
                    .stroke(Color.red, lineWidth: 1.2)
            }
            .onAppear(perform: {
                self.loadHeartRates()
                self.observeHeartRates()
//                self.constBeats = self.loadHeartRateFromFile()
//                self.beats = self.constBeats
            })
                .onReceive(timer, perform: {_ in
                    guard self.isActive else {return}
                    self.counter = self.counter + 1
                    self.simulateRealTimeHeartRate()
                })
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.willResignActiveNotification)){_ in
                        self.isActive = false
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification)){_ in
                    self.isActive = true
            }
        }
    }
    
    func loadHeartRate() {
        for i in 0...100 {
            self.beats.append(Double(150 + i))
        }
    }
    
    func loadHeartRateFromFile() -> [Double] {
        var allWords = [String]()
        var beats = [Double]()
        
        if let startWordsURL = Bundle.main.url(forResource: "heartrate", withExtension: "txt") {
            if let startWords = try? String(contentsOf: startWordsURL) {
                allWords = startWords.components(separatedBy: "\n")
                for i in 0..<allWords.count {
                    let beat = Double(allWords[i]) ?? 0.0
                    beats.append(beat==Double.nan ? 0.0 : beat)
                }
            }
        }
        if allWords.isEmpty {
            allWords = ["NaN"]
            print(allWords)
        }
        return beats
    }
    
    func simulateRealTimeHeartRate(){
        print(self.beats.count)
        if self.constBeats.count > (self.counter + 1) * self.numBeatPerUpdate {
            for i in 0..<self.numBeatPerUpdate {
                self.beats.append(self.constBeats[Int(self.counter * self.numBeatPerUpdate) + i])
            }
        } else {
            self.isActive = false
        }
    }
    
     func loadHeartRates() {
           Amplify.DataStore.query(HeartRate.self){result in
               switch result {
               case .success(let beats):
                   self.bufferBeats = beats.sorted(by: { $0.time![0].foundationDate > $1.time![0].foundationDate })
                   for beat in self.bufferBeats {
                       self.bufferFHR.append(contentsOf: beat.fHR ?? [0.0])
                       self.bufferMHR.append(contentsOf: beat.mHR ?? [0.0])
                       self.bufferTime.append(contentsOf: beat.time!)
                   }
               case .failure(let error):
                   print(error)
               }
           }
       }
    
    @State var token: AnyCancellable?
     func observeHeartRates(){
         token = Amplify.DataStore.publisher(for: HeartRate.self).sink(
             receiveCompletion: {
             print($0)
         }, receiveValue: { event in
             do {
                 let beats = try event.decodeModel(as: HeartRate.self)
                 self.bufferBeats.append(beats)
                 self.bufferBeats = self.bufferBeats.sorted(by: { $0.time![0].foundationDate > $1.time![0].foundationDate })
                 
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

