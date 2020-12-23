//
//  AWSS3View.swift
//  SwiftUIAmplify
//
//  Created by hai on 18/12/20.
//  Copyright © 2020 biorithm. All rights reserved.
//

import SwiftUI
import Amplify
import AmplifyPlugins
import Combine

struct ProgressView : View {
    
    @Binding var percent: CGFloat
    
    var body: some View {
        ZStack(alignment: .leading) {
            ZStack(alignment: .trailing){
                Capsule()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 22)
                Text(String(format: "%.0f", self.percent*100)+"%")
                    .font(.caption)
                    .foregroundColor(Color.gray.opacity(0.75))
                    .padding(.trailing)
            }
            
            Capsule()
                .fill(Color(.green))
                .frame(width:self.callPercent(), height: 22)
                .cornerRadius(10)
        }
        .padding([.leading, .trailing], 10)
        .onTapGesture {
            //            self.percent = 0
        }
    }
    
    func callPercent() -> CGFloat{
        let width = UIScreen.main.bounds.width - 20
        return width * self.percent
    }
}

// Image picker and upload
struct ImagePicker : UIViewControllerRepresentable {
    
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    typealias UIViewControllerType = UIImagePickerController
    
    func makeCoordinator() -> ImagePickerCoordinator {
        ImagePickerCoordinator(imagePicker: self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        
    }
}

class ImagePickerCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    let imagePicker: ImagePicker
    
    init(imagePicker: ImagePicker) {
        self.imagePicker = imagePicker
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        imagePicker.presentationMode.wrappedValue.dismiss()
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        imagePicker.presentationMode.wrappedValue.dismiss()
        
        guard let image = info[.originalImage] as? UIImage else {return}
        imagePicker.image = image
    }
}


struct CameraView : View {
    
    @State var shouldShowImagePicker = false
    @State var image: UIImage?
    @State var uploadProgress: CGFloat = 0
    
    var body: some View {
        VStack {
            Image(uiImage: self.image ?? UIImage())
                .resizable()
                .scaledToFit()
            
            Spacer()
            
            ProgressView(percent: self.$uploadProgress)
                .padding([.top], 10)
            
            Button(action: {self.didTapButton()}, label: {
                Image(systemName: self.image == nil ? "camera" : "icloud.and.arrow.up")
                    .font(.largeTitle)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            })
                .sheet(isPresented: self.$shouldShowImagePicker) {
                    ImagePicker(image: self.$image)
            }
            .padding([.bottom, .top], 10)
        }
        .padding([.bottom], 10)
    }
    
    func didTapButton() {
        
        if let image = self.image {
            // upload image
            upload(image)
        } else {
            // pick image
            shouldShowImagePicker.toggle()
        }
    }
    
    func upload(_ image: UIImage){
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {return}
        let key = UUID().uuidString + ".jpg"
        
        _ = Amplify.Storage.uploadData(
            key: key,
            data: imageData,
            progressListener: {progress in
                self.uploadProgress = CGFloat(progress.fractionCompleted)
                print("upload progress - \(progress.fractionCompleted)")
        },
            
            resultListener: {event  in
                switch event {
                case .success:
                    print("uploaded image")
                    
                    // save image to post
                    let post = Post(imageKey: key)
                    self.save(post)
                    self.uploadProgress = 0
                    
                case .failure(let error):
                    print("failed to upaded - \(error)")
                }
        })
    }
    
    func save(_ post : Post) {
        Amplify.DataStore.save(post) {result in
            switch result {
            case .success:
                self.image = nil
                print("post saved")
            case .failure(let error):
                print("failed  to save - \(error)")
            }
        }
    }
}

struct GalleryView : View {
    
    @State var imageCache = [String: UIImage?]()
    
    var body: some View {
        List(imageCache.sorted(by: {$0.key > $1.key}), id: \.key) {key, image in
            Image(uiImage: image ?? UIImage())
                .resizable()
                .scaledToFit()
        }
        .onAppear{
            self.getPosts()
            self.observePosts()
        }
    }
    
    
    
    func getPosts() {
        Amplify.DataStore.query(Post.self) {result in
            switch result {
            case .success(let posts):
                print(posts)
                
                // Download image
                self.downloadImages(for: posts)
                //                self.downloadImage11(for: posts)
                
            case .failure(let error):
                print(error)
            }
        }
    }
    
    func downloadImage11(for posts: [Post]) {
        //        for post in posts {
        
        let key = "958A2283-D536-4724-B739-ED2A695C0079.jpg"
        
        _ = Amplify.Storage.downloadData(key: key, resultListener: { (event) in
            switch event {
            case let .success(data):
                print("completed: \(data)")
                let image = UIImage(data: data)
                
                DispatchQueue.main.async {
                    self.imageCache[key] = image
                }
            case let .failure(storageError):
                print("failed to download image - \(storageError)")
            }
            
        })
        //        }
    }
    
    func downloadImages(for posts: [Post]) {
        for post in posts {
            _ = Amplify.Storage.downloadData(key: post.imageKey) {result in
                switch result {
                case .success(let imageData):
                    let image =  UIImage(data: imageData)
                    
                    DispatchQueue.main.async {
                        // Upload view images
                        self.imageCache[post.imageKey] = image
                    }
                    
                case .failure(let error):
                    print("failed to download image from s3 - \(error)")
                }
            }
        }
    }
    
    
    @State var token: AnyCancellable?
    func observePosts() {
        token = Amplify.DataStore.publisher(for: Post.self).sink(
            receiveCompletion: { print($0) },
            receiveValue: { event in
                do  {
                    let post = try event.decodeModel(as: Post.self)
                    self.downloadImages(for: [post])
                    
                } catch {
                    print(error)
                }
        }
        )
    }
}

struct LogOutButtonView : View {
    
    @State var showingLoginView = false
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        NavigationView {
            Button(action: self.didTapLogOutButton){
                    Text("Log out")
                        .frame(height: 40)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding([.trailing, .leading], 24)
        }
    }
    
    func didTapLogOutButton() {
        showingLoginView.toggle()
        UserDefaults.standard.set(false, forKey: "isSignedIn")
        UserDefaults.standard.synchronize()
        self.sessionManager.signOut()
    }
}


struct AWSS3View : View {
    
    @EnvironmentObject var sessionManager: SessionManager
    var user: AuthUser!
    
    var body: some View {
        TabView {
            CameraView()
                .tabItem{Image(systemName: "camera")}
            
            GalleryView()
                .tabItem{Image(systemName: "photo.on.rectangle")}
            
            DocumentPickerView()
                .tabItem({Image(systemName: "icloud.and.arrow.up.fill")})
            
            LogOutButtonView()
                .tabItem({Image(systemName: "person")})
        }
    }
}

