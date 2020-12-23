//
//  DocumentPickerView.swift
//  SwiftUIAmplify
//
//  Created by hai on 22/12/20.
//  Copyright © 2020 biorithm. All rights reserved.
//

import SwiftUI
import CoreServices
import Amplify

//curl 'https://bln9cf30wj.execute-api.ap-southeast-1.amazonaws.com/default/pythontest?filename=s3://biorithm-testing-data/racer-06-oct/A204.csv'

let apiGateWayURL = "https://bln9cf30wj.execute-api.ap-southeast-1.amazonaws.com/default/pythontest?filename="
var s3URL = "s3://femom-sqi-ios-aps1114348-dev/public/"

struct SQIAPIOutput: Codable {
    let pass: Int
    let recordname: String
}


struct UploadProgressView : View {
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
                .frame(width: self.callPercent(), height: 22)
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


struct DocumentPicker : UIViewControllerRepresentable {
    
    @Binding var url : URL?
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeCoordinator() -> DocumentPickerCoordinator {
        DocumentPickerCoordinator(documentPicker: self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) ->
        UIDocumentPickerViewController {
            let picker = UIDocumentPickerViewController.init(documentTypes:
                [kUTTypeText as String,  kUTTypeUTF8PlainText as String, kUTTypeData as String], in: .import)
            picker.allowsMultipleSelection = false
            picker.delegate = context.coordinator
            return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController,
                                context: UIViewControllerRepresentableContext<DocumentPicker>) {
    }
}

class DocumentPickerCoordinator : NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {
    
    let documentPicker : DocumentPicker
    init(documentPicker: DocumentPicker) {
        self.documentPicker = documentPicker
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        documentPicker.presentationMode.wrappedValue.dismiss()
        documentPicker.url = urls[0]
        documentPicker.image = UIImage()
        
        print("\(urls[0])")
    }
}

struct DocumentPickerView: View {
    @State var shouldShowDocumentPicker = false
    @State var image : UIImage?
    @State var url : URL?
    @State var uploadProgress: CGFloat = 0
    @State var testResult: String = ""
    @State var testResults = [String]()
    @State var count: Int = 0
    
    var body: some View {
            VStack {
                List() {
                    ForEach(testResults, id: \.self) {result in
                        Text(result)
                            .lineLimit(1)
                            .frame(alignment: .leading)
                    }
                }
                
                UploadProgressView(percent: self.$uploadProgress)
                
                Spacer()
                Button(action: {self.didTapButton()}, label: {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                })
                    .sheet(isPresented: self.$shouldShowDocumentPicker) {
                        DocumentPicker(url: self.$url, image: self.$image)
                }
                .padding([.top, .bottom], 10)
            }
            .padding([.bottom], 10)
    }
    
    func didTapButton() {
        if let url = self.url {
            // upload image
            self.upload(url)
        } else {
            // pick image
            shouldShowDocumentPicker.toggle()
        }
    }
    
    func upload(_ filename: URL){
        let key = UUID().uuidString + ".csv"
        self.testResult = key
        self.testResults.append(self.testResult)
        
        Amplify.Storage.uploadFile(
            key: key,
            local: filename,
            progressListener: {progress in
                self.uploadProgress = CGFloat(progress.fractionCompleted)
                print("\(self.uploadProgress)")
        },
            resultListener: {event in
                switch event {
                case .success:
                    print("Completed upload \(key)")
                    
                    // SQI API call
                    self.callSQIAPI(from: apiGateWayURL+s3URL+String(key))
                    
                case let .failure(storageError):
                    print("Failed to upload \(storageError)")
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
    
    func callSQIAPI(from url: String) {
        URLSession.shared.dataTask(with: URL(string: url)!, completionHandler: {data, testResult, error in
            
            guard let data = data, error == nil else {
                print("error something wrong")
                return
            }
            
            // have data
            var result: SQIAPIOutput?
            do {
                result = try JSONDecoder().decode(SQIAPIOutput.self, from: data)
            } catch {
                print("failed to convert byte data to json \(error)")
            }
            
            guard let json = result else {
                return
            }
            
            self.testResult = "\(json.pass==1 ? "PASS" : "FAIL") - \(json.recordname) "
            self.testResults[self.count] = self.testResult
            self.count = self.count + 1
            self.url = nil
            self.uploadProgress = 0
            
        }).resume()
    }
}


////
////  DocumentPickerView.swift
////  SwiftUIAmplify
////
////  Created by hai on 22/12/20.
////  Copyright © 2020 biorithm. All rights reserved.
////
//
//import SwiftUI
//import CoreServices
//import Amplify
//
//let apiGateWayURL = "https://bln9cf30wj.execute-api.ap-southeast-1.amazonaws.com/default/pythontest?filename="
//var s3URL = "s3://biorithm-testing-data/racer-06-oct/A204.csv"
//
//struct SQIAPIOutput: Codable {
//    let pass: Int
//    let recordname: String
//}
//
//struct DocumentPicker : UIViewControllerRepresentable {
//
//    @Binding var url : URL?
//    @Binding var image: UIImage?
//    @Environment(\.presentationMode) var presentationMode
//
//    func makeCoordinator() -> DocumentPickerCoordinator {
//        DocumentPickerCoordinator(documentPicker: self)
//    }
//
//    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) ->
//        UIDocumentPickerViewController {
//            let picker = UIDocumentPickerViewController.init(documentTypes:
//                [kUTTypeText as String,  kUTTypeUTF8PlainText as String, kUTTypeData as String], in: .import)
//            picker.allowsMultipleSelection = false
//            picker.delegate = context.coordinator
//            return picker
//    }
//
//    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController,
//                                context: UIViewControllerRepresentableContext<DocumentPicker>) {
//    }
//}
//
//class DocumentPickerCoordinator : NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {
//
//    let documentPicker : DocumentPicker
//    init(documentPicker: DocumentPicker) {
//        self.documentPicker = documentPicker
//    }
//
//    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
//
//        documentPicker.presentationMode.wrappedValue.dismiss()
//        documentPicker.url = urls[0]
//        documentPicker.image = UIImage()
//
//        print("\(urls[0])")
//    }
//}
//
//struct DocumentPickerView: View {
//    @State var shouldShowDocumentPicker = false
//    @State var image : UIImage?
//    @State var url : URL?
//    @State var uploadProgress: CGFloat = 0
//    @State var testResult: String = ""
//    @State var testResults = [String]()
//
//    var body: some View {
//        VStack {
//            Image(uiImage: self.image ?? UIImage())
//                .resizable()
//                .scaledToFit()
//
//            ProgressView(percent: self.$uploadProgress)
//
//            Spacer()
//            Button(action: {self.didTapButton()}, label: {
//                Image(systemName: "icloud.and.arrow.up.fill")
//                    .font(.largeTitle)
//                    .padding()
//                    .background(Color.purple)
//                    .foregroundColor(.white)
//                    .clipShape(Circle())
//            })
//                .sheet(isPresented: self.$shouldShowDocumentPicker) {
//                    DocumentPicker(url: self.$url, image: self.$image)
//            }
//            Spacer()
//            Text("Test Result: \(self.testResult)")
//
//        }
//    }
//
//    func didTapButton() {
//        if let url = self.url {
//            // upload image
//            self.upload(url)
//        } else {
//            // pick image
//            shouldShowDocumentPicker.toggle()
//        }
//    }
//
//    func upload(_ filename: URL){
//        let key = UUID().uuidString + ".csv"
//        Amplify.Storage.uploadFile(
//            key: key,
//            local: filename,
//            progressListener: {progress in
//                self.uploadProgress = CGFloat(progress.fractionCompleted)
//        },
//            resultListener: {event in
//                switch event {
//                case .success:
//                    print("Completed upload \(key)")
//
//                    // SQI API call
////                    self.callSQIAPI(from: apiGateWayURL+s3URL)
//
//                case let .failure(storageError):
//                    print("Failed to upload \(storageError)")
//                }
//        })
//
//    }
//
//    func save(_ post : Post) {
//        Amplify.DataStore.save(post) {result in
//            switch result {
//            case .success:
//                self.image = nil
//                print("post saved")
//            case .failure(let error):
//                print("failed  to save - \(error)")
//            }
//        }
//    }
//
//    func callSQIAPI(from url: String) {
//        URLSession.shared.dataTask(with: URL(string: url)!, completionHandler: {data, testResult, error in
//
//            guard let data = data, error == nil else {
//                print("error something wrong")
//                return
//            }
//
//            // have data
//            var result: SQIAPIOutput?
//            do {
//                result = try JSONDecoder().decode(SQIAPIOutput.self, from: data)
//            } catch {
//                print("failed to convert byte data to json \(error)")
//            }
//
//            guard let json = result else {
//                return
//            }
//
//            self.testResult = "FILE: \(json.recordname) PASS: \(json.pass)"
//            self.testResults.append(self.testResult)
//
//        }).resume()
//    }
//}
