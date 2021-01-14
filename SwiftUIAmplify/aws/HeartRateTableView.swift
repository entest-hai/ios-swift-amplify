//
//  SongTableView.swift
//  SwiftUIAmplify
//
//  Created by hai on 12/1/21.
//  Copyright © 2021 biorithm. All rights reserved.
//

import SwiftUI
import Amplify
import Combine
import AmplifyPlugins

struct HeartRateTableView: View {
    var isoformatter = ISO8601DateFormatter.init()
    @State var bufferBeats = [HeartRate]()
    @State var bufferTime = [Temporal.DateTime]()
    @State var bufferMHR: [Double] = [Double]()
    @State var bufferFHR: [Double] = [Double]()
    @State var numMHR: Int = 0
    @State var numFHR: Int = 0
    
    var body: some View {
        NavigationView(){
            List(){
                ForEach((0..<self.bufferMHR.count), id: \.self){ idx in
                    Text("\(self.isoformatter.string(from: self.bufferTime[idx].foundationDate)) mHR: \(String(format: "%1.2f", self.bufferMHR[idx])) fHR: \(String(format: "%1.2f", self.bufferFHR[idx])) ")
                }
            }
            .navigationBarTitle(Text("HeartRate \(self.bufferBeats.count)"))
            .navigationBarItems(trailing: Button(action: {
                self.loadHeartRates()
                self.observeHeartRates()
            }){
                Text("Load")
            })
        }
        .onAppear(perform: {
            
        })
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
                self.numMHR = self.bufferMHR.count
                self.numFHR = self.bufferMHR.count
                print("\(self.bufferTime[0].foundationDate)")
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
