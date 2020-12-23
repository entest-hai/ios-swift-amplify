import SwiftUI
import Amplify
import AmplifyPlugins

class UserAccount : ObservableObject {
    @Published var username : String = ""
    @Published var password : String = ""
}

struct ProfileImageView : View {
    var body: some View {
        NavigationLink (destination: SettingProfileView()){
            Image(systemName: "person")
                .renderingMode(.original)
                .resizable()
                .frame(width:50, height: 50)
                .foregroundColor(.green)
        }
    }
}

struct UserNameView : View {
    
    @Binding var username : String
    @Binding var password : String
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("username", text: self.$username)
                .frame(height: 40)
                .textFieldStyle(PlainTextFieldStyle())
                .padding([.leading, .trailing], 4)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
                .padding([.leading, .trailing], 24)
            
            SecureField("password", text: self.$password)
                .frame(height: 40)
                .textFieldStyle(PlainTextFieldStyle())
                .padding([.leading, .trailing], 4)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
                .padding([.leading, .trailing], 24)
        }
    }
}


struct LonginButtonView  : View {
    
    @State var selection: Int? = nil
    @Binding var username : String
    @Binding var password : String
    @State private var showingAlert = false
    
    var body: some View {
        VStack (spacing: 20) {
        
            NavigationLink(destination: AWSS3View(), tag: 1, selection: $selection) {
                Button(action: self.tapLoginButton) {
                    Text("Login")
                        .frame(height: 40)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding([.leading, .trailing], 24)
                .alert(isPresented: $showingAlert) {
                    Alert(title: Text("empty"),
                          message: Text("enter username and password"),
                          dismissButton: .default(Text("Close")))
                }
            }
            
            Button(action: self.logOutLocally) {
                Text("Logout")
                    .frame(height: 40)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding([.leading, .trailing], 24)
            
        }
    }
    
    func tapLoginButton() {
        if UserDefaults.standard.bool(forKey: "isSignedIn") {
            print("Already signed in ")
            self.selection = 1
        } else {
            if (username.isEmpty || password.isEmpty) {
                self.showingAlert =  true
            } else {
                signIn(username: username, password: password)
            }
        }
    }
    
    func signIn(username: String, password: String) {
        _ = Amplify.Auth.signIn(username: username, password: password) {result in
            switch result {
            case .success:
                UserDefaults.standard.set(true, forKey: "isSignedIn")
                UserDefaults.standard.synchronize()
                
                DispatchQueue.main.async {
                    print("username \(self.username) pass \(self.password)")
                    self.selection = 1
                }
                
            case .failure(let error):
                print("Sign in failed \(error)")
            }
        }
    }
    
    func logOutLocally() {
        Amplify.Auth.signOut() { result in
            switch result {
            case .success:
                UserDefaults.standard.set(false, forKey: "isSignedIn")
                print("Successfully signed out")
            case .failure(let error):
                print("Sign out failed with error \(error)")
            }
        }
    }
}



struct SettingProfileView : View {
    var body: some View {
        Text("Set profile image")
    }
}

struct ContentView : View {
    
    @State var username : String = ""
    @State var password : String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                ProfileImageView()
                    .padding(.top, 150)
                
                UserNameView(username: $username, password: $password)
                    .padding(.top, 50)
                
                Spacer()
                
                LonginButtonView(username: $username, password: $password)
                    .padding(.bottom,10)
                
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
