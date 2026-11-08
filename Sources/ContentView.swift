
import SwiftUI

struct ContentView: View {

    @ObservedObject var model: CameraAppModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    Image(systemName: "camera.aperture")
                        .font(.system(size: 75))
                        .foregroundColor(.blue)
                        .padding(.top, 30)

                    Text("G526 Kamera Kontrolü")
                        .font(.title.bold())

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Kamera Durumu", systemImage: "video")
                            .font(.headline)

                        Text(model.status)
                            .foregroundColor(.secondary)

                        HStack {
                            Circle()
                                .fill(model.isConnected ? Color.green : Color.red)
                                .frame(width: 12, height: 12)

                            Text(model.isConnected ? "Bağlı" : "Bağlı değil")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)

                    Button {
                        if model.isConnected {
                            model.disconnectCamera()
                        } else {
                            model.connectCamera()
                        }
                    } label: {
                        Label(
                            model.isConnected ? "Bağlantıyı Kes" : "Kameraya Bağlan",
                            systemImage: model.isConnected ? "wifi.slash" : "wifi"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(model.isConnected ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    VStack(spacing: 12) {
                        Label("Sesli Komut", systemImage: "waveform")
                            .font(.headline)

                        Text(model.isListening
                             ? "Okey komutu dinleniyor"
                             : "Sesli dinleme kapalı")
                            .foregroundColor(.secondary)

                        Button {
                            if model.isListening {
                                model.stopListening()
                            } else {
                                Task {
                                    await model.startListening()
                                }
                            }
                        } label: {
                            Label(
                                model.isListening ? "Dinlemeyi Durdur" : "Dinlemeyi Başlat",
                                systemImage: model.isListening ? "stop.circle" : "mic.circle"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(model.isListening ? Color.orange : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Son Algılanan Ses")
                            .font(.headline)

                        Text(model.lastCommand.isEmpty
                             ? "Henüz komut algılanmadı."
                             : model.lastCommand)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(14)

                    Text(model.statusMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Google Hesabından Çıkış Yap") {
                        model.signOut()
                    }
                    .foregroundColor(.red)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }
            .navigationTitle("G526 Drive")
        }
    }
}
