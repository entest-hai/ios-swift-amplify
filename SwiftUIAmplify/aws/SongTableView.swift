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

struct MySong: Identifiable {
    let id = UUID()
    let title: String
    let owner: String
    let like: Int
}

struct SongTableView: View {
    @State var songs = [MySong]()
    var body: some View {
        NavigationView(){
            List(){
                ForEach(self.songs){ song in
                    HStack(){
                        Image(systemName: "person")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .background(Color.purple)
                            .clipShape(Circle())
                        Text(song.title)
                            .fontWeight(.bold)
                        Text(song.owner)
                        Text("\(song.like)")
                    }
                    .frame(height: 50)
                }
            }
            .navigationBarTitle(Text("Song"))
            .navigationBarItems(trailing: Button(action: {
                self.loadSongs()
                self.observeSongTable()
            }){
                Text("Load")
            })
        }
        .onAppear(perform: {
            
        })
    }
    
    func loadSongs() {
        Amplify.DataStore.query(Song.self){result in
            switch result {
            case .success(let songs):
                for song in songs {
                    self.songs.append(MySong(title: song.title, owner: song.owner, like: song.like))
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    @State var token: AnyCancellable?
    func observeSongTable(){
        token = Amplify.DataStore.publisher(for: Song.self).sink(
            receiveCompletion: {
            print($0)
        }, receiveValue: { event in
            do {
                let song = try event.decodeModel(as: Song.self)
                self.songs.append(MySong(title: song.title, owner: song.owner, like: song.like))
            } catch {
                print(error)
            }
        })
    }
}
