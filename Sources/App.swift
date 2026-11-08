
import SwiftUI
import UIKit
import GoogleSignIn

@main
struct G526CameraDriveApp: App {

    @StateObject private var appModel = CameraAppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if appModel.isLoggedIn {
                    ContentView(model: appModel)
                } else {
                    LoginView(model: appModel)
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}

struct LoginView: View {

    @ObservedObject var model: CameraAppModel

    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 24) {

            Image(systemName: "camera.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue)

            Text("G526 Drive Kamerası")
                .font(.largeTitle.bold())

            Text("Fotoğraflarınızı Google Drive'a kaydetmek için Google hesabınızla giriş yapın.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                signIn()
            } label: {
                HStack {
                    if isSigningIn {
                        ProgressView()
                            .tint(.white)
                    }

                    Image(systemName: "person.crop.circle.badge.checkmark")

                    Text("Google ile Giriş Yap")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSigningIn)
            .padding(.horizontal, 28)

            if !model.statusMessage.isEmpty {
                Text(model.statusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            restoreSignIn()
        }
    }

    private func restoreSignIn() {

        guard let clientID = Bundle.main.object(
            forInfoDictionaryKey: "GIDClientID"
        ) as? String,
        !clientID.isEmpty,
        !clientID.contains("$(") else {

            model.statusMessage = "Google Client ID yapılandırılmamış."
            return
        }

        GIDSignIn.sharedInstance.configuration =
            GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.restorePreviousSignIn {
            user, error in

            DispatchQueue.main.async {
                if let user {
                    model.setGoogleUser(user: user)
                } else if let error {
                    model.statusMessage =
                        "Oturum geri yüklenemedi: \(error.localizedDescription)"
                }
            }
        }
    }

    private func signIn() {

        guard let clientID = Bundle.main.object(
            forInfoDictionaryKey: "GIDClientID"
        ) as? String,
        !clientID.isEmpty,
        !clientID.contains("$(") else {

            model.statusMessage = "Google Client ID eksik."
            return
        }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let root = scene.windows
                .first(where: { $0.isKeyWindow })?
                .rootViewController else {

            model.statusMessage = "Giriş ekranı açılamadı."
            return
        }

        isSigningIn = true

        GIDSignIn.sharedInstance.configuration =
            GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.signIn(
            withPresenting: root,
            hint: nil,
            additionalScopes: [
                "https://www.googleapis.com/auth/drive.file"
            ]
        ) { result, error in

            DispatchQueue.main.async {
                isSigningIn = false

                if let user = result?.user {
                    model.setGoogleUser(user: user)
                } else if let error {
                    model.statusMessage =
                        "Google girişi başarısız: \(error.localizedDescription)"
                }
            }
        }
    }
}
