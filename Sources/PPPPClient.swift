
import Foundation
import Network

final class PPPPClient {

    private let host: NWEndpoint.Host
    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "com.g526.camera")
    private var connection: NWConnection?

    init(
        host: String = "192.168.100.20",
        port: UInt16 = 32100
    ) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    func connect(
        timeout: TimeInterval = 10,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let connection = NWConnection(
            host: host,
            port: port,
            using: .udp
        )

        self.connection = connection

        let lock = NSLock()
        var completed = false

        func finish(_ result: Result<Void, Error>) {
            lock.lock()
            guard !completed else {
                lock.unlock()
                return
            }
            completed = true
            lock.unlock()

            DispatchQueue.main.async {
                completion(result)
            }
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(.success(()))
            case .failed(let error):
                finish(.failure(error))
            case .cancelled:
                finish(.failure(PPPPError.cancelled))
            default:
                break
            }
        }

        connection.start(queue: queue)

        queue.asyncAfter(deadline: .now() + timeout) {
            finish(.failure(PPPPError.timeout))
        }
    }

    func send(
        _ data: Data,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let connection else {
            completion(.failure(PPPPError.notConnected))
            return
        }

        connection.send(
            content: data,
            completion: .contentProcessed { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        )
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }
}

enum PPPPError: LocalizedError {
    case timeout
    case cancelled
    case notConnected

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Kamera bağlantısı zaman aşımına uğradı."
        case .cancelled:
            return "Kamera bağlantısı iptal edildi."
        case .notConnected:
            return "Kamera bağlantısı kurulmadı."
        }
    }
}
