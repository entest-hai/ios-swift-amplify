//
//  TestSignInSignOutView.swift
//  SwiftUIAmplify
//
//  Created by hai on 23/12/20.
//  Copyright © 2020 biorithm. All rights reserved.
//

import SwiftUI
import Amplify

enum AuthState {
    case signUp
    case login
    case confirmCode(username: String)
    case session(user: AuthUser)
}

final class SessionManager: ObservableObject {
    
    @Published var myState: Int = 0
    @Published var authState: AuthState = .login
    
    func getCurrentAuthUser() {
        if let user = Amplify.Auth.getCurrentUser() {
            authState = .session(user: user)
        } else {
            authState = .login
        }
    }
    
    func showSignUp() {
        authState = .signUp
        myState = 1
    }
    
    func showLogIn() {
        authState = .login
        myState = 0
    }
    
    func signUp(username:  String, email: String, password: String) {
        let attributes = [AuthUserAttribute(.email, value: email)]
        let options = AuthSignUpRequest.Options(userAttributes: attributes)
        
        _ = Amplify.Auth.signUp(username: username, password: password, options: options) {[weak self] result in
            
            switch result {
            case .success(let signUpResult):
                print("Sign up result: ", signUpResult)
                
                switch signUpResult.nextStep {
                case .done:
                    print("Finished sign up")
                    
                case .confirmUser(let detail, _):
                    print(detail ?? "no detail")
                    
                    DispatchQueue.main.async {
                        self?.authState = .confirmCode(username: username)
                    }
                }
                
            case . failure(let error):
                print("SIgn up error",  error)
            }
        }
    }
    
    func login(username: String, password: String) {
        _ = Amplify.Auth.signIn(
            username: username,
            password: password,
            listener: { [weak self] result in
                switch result {
                case .success(let signInResult):
                    print(signInResult)
                    if signInResult.isSignedIn{
                        DispatchQueue.main.async {
                            self?.getCurrentAuthUser()
                        }
                    }
                    
                case .failure(let error):
                    print("Login error: \(error)")
                }
                                    
        })
    }
    
    func signOut() {
        
        _ = Amplify.Auth.signOut(listener: {result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.getCurrentAuthUser()
                }
                
            case .failure(let error):
                print("Sign out error: \(error)")
            }
        })
    }
    
    func confirm(username: String,  code: String) {
        _ = Amplify.Auth.confirmSignUp(
            for: username,
            confirmationCode: code
        ){[weak self] result  in
            switch result {
            case .success(let confirmResult):
                print(confirmResult)
                if confirmResult.isSignupComplete {
                    DispatchQueue.main.async {
                        self?.showLogIn()
                    }
                }
            case .failure(let error):
                print("failed to confirm code: ", error)
            }
        }
    }
}

struct LoginView : View {
    
    @EnvironmentObject var sessionManager: SessionManager
    @State var username = ""
    @State var password = ""
    
    var body: some View {
        
        VStack {
            Spacer()
            TextField("Username", text: $username)
                .frame(height: 40)
                .textFieldStyle(PlainTextFieldStyle())
                .padding([.trailing, .leading], 4)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
            
            
            SecureField("Passowrd", text: $password)
                .frame(height: 40)
                .textFieldStyle(PlainTextFieldStyle())
                .padding([.trailing, .leading],4 )
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
            
            Button(action: {self.sessionManager.login(
                username: self.username,
                password: self.password)}){
                    Text("Login")
                        .frame(height: 40)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
            }
            
            
            Spacer()
            Button("Don't have an account? Sign up", action: {
                self.sessionManager.showSignUp()
            })
        }
        .padding()
    }
}

struct ConfirmationView : View {
    
    @EnvironmentObject var sessionManager: SessionManager
    @State var confirmationCode = ""
    let username: String
    
    var body: some View {
        VStack {
            Text("Username: \(username)")
            TextField("Confirmation Code", text: $confirmationCode)
            Button("Confirm", action: {
                self.sessionManager.confirm(
                    username: self.username,
                    code: self.confirmationCode)
            })
        }
        .padding()
    }
}

struct SignUpView : View {
    
    @EnvironmentObject var sessionManager: SessionManager
    @State var username = ""
    @State var password = ""
    @State var email = ""
    
    var body: some View {
        VStack {
            Spacer()
            TextField("Username", text: $username)
                .frame(height: 40)
                .textFieldStyle(PlainTextFieldStyle())
                .padding([.trailing, .leading], 4)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
            
            TextField("Email", text: $email)
                .frame(height: 40)
                .textFieldStyle(PlainTextFieldStyle())
                .padding([.trailing, .leading], 4)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
            
            SecureField("Password", text: $password)
                .frame(height: 40)
                .textFieldStyle(PlainTextFieldStyle())
                .padding([.trailing, .leading], 4)
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
            
            Button(action: {
                self.sessionManager.signUp(
                    username: self.username,
                    email: self.email,
                    password: self.password)
            }) {
                Text("Signup")
                    .frame(height: 40)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
            
            Button("Already have an account? Log in", action: {
                self.sessionManager.showLogIn()
            })
        }
        .padding()
    }
}

struct SessionView : View {
    
    @EnvironmentObject var sessionManager: SessionManager
    let user : AuthUser!
    
    var body: some View {
        VStack{
            Spacer()
            Text("Session").font(.largeTitle)
            Spacer()
            Button(action: {self.sessionManager.signOut()}) {
                       Text("Logout")
                           .frame(height: 40)
                           .frame(minWidth: 0, maxWidth: .infinity)
                           .background(Color.green)
                           .foregroundColor(.white)
                           .cornerRadius(10)
                   }
            .padding([.trailing, .leading], 20)
        }
    }
}

struct TestSignInSignOutView: View {
    
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        
        switch self.sessionManager.authState {
        case .login:
            return AnyView(LoginView())
        case .signUp:
            return AnyView(SignUpView())
        case .confirmCode(let username):
            return AnyView(ConfirmationView(username: username))
        case .session(let user):
            return AnyView(AWSS3View(user:  user))
            
        }
    }
}

