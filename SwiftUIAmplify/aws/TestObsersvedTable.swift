//
//  SongTableView.swift
//  SwiftUIAmplify
//
//  Created by hai on 12/1/21.
//  Copyright © 2021 biorithm. All rights reserved.
//  Refactor in ObservbaleObject works for Xcode 12 @StateObject

import SwiftUI
import Amplify
import Combine
import AmplifyPlugins

struct TestHeartRateTableView: View {
    var isoformatter = ISO8601DateFormatter.init()
    @State var heartRateModel = HeartRateViewModel()
    var body: some View {
        NavigationView(){
            List(){
                ForEach((0..<self.heartRateModel.bufferFHR.count), id: \.self){ idx in
                    Text("\(self.isoformatter.string(from: self.heartRateModel.bufferTime[idx].foundationDate)) mHR: \(String(format: "%1.2f", self.heartRateModel.bufferMHR[idx])) fHR: \(String(format: "%1.2f", self.heartRateModel.bufferFHR[idx])) ")
                }
            }
            .navigationBarTitle(Text("HeartRate \(self.heartRateModel.bufferBeats.count)"))
            .navigationBarItems(trailing: Button(action: {
                
            }){
                Text("Load")
            })
        }
        .onAppear(perform: {
//            self.heartRateModel.loadHeartRateFromDB()
            self.heartRateModel.observeHeartRatesDBTable()
        })
    }
}

