//
//  ContentTransferServer.swift
//  NesCaster
//
//  Local HTTP server for transferring ROMs and profile pictures
//  Used on Apple TV where file browsing isn't available
//

import Foundation
import Network

@MainActor
class ContentTransferServer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isRunning = false
    @Published private(set) var serverAddress: String?
    @Published private(set) var port: UInt16 = 8080
    @Published private(set) var connectedClients: Int = 0
    @Published private(set) var lastUploadedFile: String?
    
    // MARK: - Private Properties
    
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var profileID: UUID?
    private let fileManager = FileManager.default
    
    // MARK: - Callbacks
    
    var onFileUploaded: ((URL) -> Void)?
    
    // MARK: - Singleton
    
    static let shared = ContentTransferServer()
    
    private init() {}
    
    // MARK: - Server Control
    
    func start(for profileID: UUID) throws {
        self.profileID = profileID
        
        // Create listener
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        
        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleStateUpdate(state)
            }
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleNewConnection(connection)
            }
        }
        
        listener?.start(queue: .main)
        print("🌐 ContentTransferServer: Starting on port \(port)...")
    }
    
    func stop() {
        listener?.cancel()
        listener = nil
        
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        
        isRunning = false
        serverAddress = nil
        connectedClients = 0
        
        print("🌐 ContentTransferServer: Stopped")
    }
    
    // MARK: - State Handling
    
    private func handleStateUpdate(_ state: NWListener.State) {
        switch state {
        case .ready:
            isRunning = true
            serverAddress = getLocalIPAddress()
            print("✅ ContentTransferServer: Ready at http://\(serverAddress ?? "unknown"):\(port)")
            
        case .failed(let error):
            print("❌ ContentTransferServer: Failed - \(error)")
            isRunning = false
            
        case .cancelled:
            isRunning = false
            
        default:
            break
        }
    }
    
    // MARK: - Connection Handling
    
    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        connectedClients = connections.count
        
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.receiveRequest(from: connection!)
                case .failed, .cancelled:
                    if let conn = connection {
                        self?.connections.removeAll { $0 === conn }
                        self?.connectedClients = self?.connections.count ?? 0
                    }
                default:
                    break
                }
            }
        }
        
        connection.start(queue: .main)
    }
    
    // MARK: - Request Handling
    
    private func receiveRequest(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                if let data = data, !data.isEmpty {
                    self?.processRequest(data: data, connection: connection)
                }
                
                if isComplete || error != nil {
                    connection.cancel()
                }
            }
        }
    }
    
    private func processRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "Invalid request")
            return
        }
        
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "Invalid request")
            return
        }
        
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            sendResponse(connection: connection, status: "400 Bad Request", body: "Invalid request")
            return
        }
        
        let method = parts[0]
        let path = parts[1]
        
        switch (method, path) {
        case ("GET", "/"):
            serveHomePage(connection: connection)
            
        case ("GET", "/api/files"):
            serveFileList(connection: connection)
            
        case ("POST", "/api/upload"):
            handleFileUpload(data: data, connection: connection)
            
        case ("DELETE", _) where path.hasPrefix("/api/delete/"):
            let filename = String(path.dropFirst("/api/delete/".count))
            handleFileDelete(filename: filename, connection: connection)
            
        default:
            sendResponse(connection: connection, status: "404 Not Found", body: "Not found")
        }
    }
    
    // MARK: - Serve Home Page
    
    private func serveHomePage(connection: NWConnection) {
        let html = generateHTML()
        sendResponse(connection: connection, status: "200 OK", contentType: "text/html", body: html)
    }
    
    // MARK: - File List API
    
    private func serveFileList(connection: NWConnection) {
        guard let profileID = profileID else {
            sendJSON(connection: connection, status: "500 Internal Server Error", json: ["error": "No profile"])
            return
        }
        
        let romsDir = getROMsDirectory(profileID: profileID)
        var files: [[String: Any]] = []
        
        if let contents = try? fileManager.contentsOfDirectory(at: romsDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) {
            for url in contents where url.pathExtension.lowercased() == "nes" {
                let attributes = try? fileManager.attributesOfItem(atPath: url.path)
                let size = attributes?[.size] as? Int ?? 0
                
                files.append([
                    "name": url.lastPathComponent,
                    "size": size,
                    "type": "rom"
                ])
            }
        }
        
        sendJSON(connection: connection, status: "200 OK", json: ["files": files])
    }
    
    // MARK: - File Upload
    
    private func handleFileUpload(data: Data, connection: NWConnection) {
        guard let profileID = profileID else {
            sendJSON(connection: connection, status: "500 Internal Server Error", json: ["error": "No profile"])
            return
        }
        
        // Parse multipart form data (simplified)
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendJSON(connection: connection, status: "400 Bad Request", json: ["error": "Invalid data"])
            return
        }
        
        // Find boundary
        guard let boundaryRange = requestString.range(of: "boundary="),
              let endOfBoundary = requestString[boundaryRange.upperBound...].firstIndex(of: "\r") else {
            sendJSON(connection: connection, status: "400 Bad Request", json: ["error": "Missing boundary"])
            return
        }
        
        let boundary = String(requestString[boundaryRange.upperBound..<endOfBoundary])
        
        // Find filename
        guard let filenameRange = requestString.range(of: "filename=\""),
              let endOfFilename = requestString[filenameRange.upperBound...].firstIndex(of: "\"") else {
            sendJSON(connection: connection, status: "400 Bad Request", json: ["error": "Missing filename"])
            return
        }
        
        let filename = String(requestString[filenameRange.upperBound..<endOfFilename])
        
        // Find file content (after double CRLF)
        guard let contentStart = data.range(of: Data("\r\n\r\n".utf8)) else {
            sendJSON(connection: connection, status: "400 Bad Request", json: ["error": "Invalid format"])
            return
        }
        
        // Extract file data (between headers and final boundary)
        let contentStartIndex = contentStart.upperBound
        let boundaryData = Data("--\(boundary)".utf8)
        
        guard let contentEnd = data[contentStartIndex...].range(of: boundaryData) else {
            sendJSON(connection: connection, status: "400 Bad Request", json: ["error": "Missing end boundary"])
            return
        }
        
        let fileData = data[contentStartIndex..<contentEnd.lowerBound]
        
        // Save file
        let romsDir = getROMsDirectory(profileID: profileID)
        let fileURL = romsDir.appendingPathComponent(filename)
        
        do {
            try fileData.write(to: fileURL)
            lastUploadedFile = filename
            onFileUploaded?(fileURL)
            
            sendJSON(connection: connection, status: "200 OK", json: [
                "success": true,
                "filename": filename,
                "size": fileData.count
            ])
            
            print("📦 File uploaded: \(filename) (\(fileData.count) bytes)")
        } catch {
            sendJSON(connection: connection, status: "500 Internal Server Error", json: ["error": error.localizedDescription])
        }
    }
    
    // MARK: - File Delete
    
    private func handleFileDelete(filename: String, connection: NWConnection) {
        guard let profileID = profileID else {
            sendJSON(connection: connection, status: "500 Internal Server Error", json: ["error": "No profile"])
            return
        }
        
        let decodedFilename = filename.removingPercentEncoding ?? filename
        let romsDir = getROMsDirectory(profileID: profileID)
        let fileURL = romsDir.appendingPathComponent(decodedFilename)
        
        do {
            try fileManager.removeItem(at: fileURL)
            sendJSON(connection: connection, status: "200 OK", json: ["success": true])
            print("🗑️ File deleted: \(decodedFilename)")
        } catch {
            sendJSON(connection: connection, status: "500 Internal Server Error", json: ["error": error.localizedDescription])
        }
    }
    
    // MARK: - Response Helpers
    
    private func sendResponse(connection: NWConnection, status: String, contentType: String = "text/plain", body: String) {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType); charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        Access-Control-Allow-Origin: *\r
        \r
        \(body)
        """
        
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    private func sendJSON(connection: NWConnection, status: String, json: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: json),
           let jsonString = String(data: data, encoding: .utf8) {
            sendResponse(connection: connection, status: status, contentType: "application/json", body: jsonString)
        }
    }
    
    // MARK: - File System
    
    private func getROMsDirectory(profileID: UUID) -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let romsDir = documentsURL
            .appendingPathComponent("Profiles")
            .appendingPathComponent(profileID.uuidString)
            .appendingPathComponent("ROMs")
        
        try? fileManager.createDirectory(at: romsDir, withIntermediateDirectories: true)
        return romsDir
    }
    
    // MARK: - Network
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        
        return address
    }
    
    // MARK: - HTML Generation
    
    private func generateHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>NesCaster - File Transfer</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif;
                    background: linear-gradient(135deg, #0a0a14 0%, #141428 50%, #0a0a14 100%);
                    min-height: 100vh;
                    color: #fff;
                    padding: 40px;
                }
                .container {
                    max-width: 800px;
                    margin: 0 auto;
                }
                .header {
                    text-align: center;
                    margin-bottom: 40px;
                }
                .logo {
                    font-size: 48px;
                    font-weight: 700;
                    background: linear-gradient(135deg, #f05a5a 0%, #d63384 100%);
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                    margin-bottom: 8px;
                }
                .subtitle {
                    color: rgba(255,255,255,0.5);
                    font-size: 16px;
                }
                .card {
                    background: rgba(255,255,255,0.05);
                    backdrop-filter: blur(20px);
                    border: 1px solid rgba(255,255,255,0.1);
                    border-radius: 24px;
                    padding: 32px;
                    margin-bottom: 24px;
                }
                .card-title {
                    font-size: 20px;
                    font-weight: 600;
                    margin-bottom: 20px;
                    display: flex;
                    align-items: center;
                    gap: 12px;
                }
                .card-title .icon {
                    width: 40px;
                    height: 40px;
                    background: linear-gradient(135deg, #f05a5a 0%, #d63384 100%);
                    border-radius: 12px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .upload-zone {
                    border: 2px dashed rgba(255,255,255,0.2);
                    border-radius: 16px;
                    padding: 48px;
                    text-align: center;
                    cursor: pointer;
                    transition: all 0.3s;
                }
                .upload-zone:hover, .upload-zone.dragover {
                    border-color: #f05a5a;
                    background: rgba(240,90,90,0.1);
                }
                .upload-zone input { display: none; }
                .upload-icon {
                    font-size: 48px;
                    margin-bottom: 16px;
                }
                .upload-text {
                    color: rgba(255,255,255,0.7);
                    margin-bottom: 8px;
                }
                .upload-hint {
                    color: rgba(255,255,255,0.4);
                    font-size: 14px;
                }
                .file-list {
                    list-style: none;
                }
                .file-item {
                    display: flex;
                    align-items: center;
                    padding: 16px;
                    background: rgba(255,255,255,0.03);
                    border-radius: 12px;
                    margin-bottom: 8px;
                }
                .file-icon {
                    width: 40px;
                    height: 40px;
                    background: rgba(240,90,90,0.2);
                    border-radius: 10px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    margin-right: 16px;
                }
                .file-name {
                    flex: 1;
                    font-weight: 500;
                }
                .file-size {
                    color: rgba(255,255,255,0.4);
                    font-size: 14px;
                    margin-right: 16px;
                }
                .delete-btn {
                    background: rgba(255,59,48,0.2);
                    border: none;
                    color: #ff3b30;
                    padding: 8px 16px;
                    border-radius: 8px;
                    cursor: pointer;
                    font-weight: 500;
                }
                .delete-btn:hover {
                    background: rgba(255,59,48,0.3);
                }
                .empty-state {
                    text-align: center;
                    padding: 40px;
                    color: rgba(255,255,255,0.4);
                }
                .progress {
                    height: 4px;
                    background: rgba(255,255,255,0.1);
                    border-radius: 2px;
                    margin-top: 16px;
                    overflow: hidden;
                    display: none;
                }
                .progress-bar {
                    height: 100%;
                    background: linear-gradient(90deg, #f05a5a, #d63384);
                    width: 0%;
                    transition: width 0.3s;
                }
                .toast {
                    position: fixed;
                    bottom: 40px;
                    left: 50%;
                    transform: translateX(-50%);
                    background: rgba(52,199,89,0.9);
                    color: #fff;
                    padding: 16px 32px;
                    border-radius: 12px;
                    font-weight: 500;
                    display: none;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <div class="logo">🎮 NesCaster</div>
                    <div class="subtitle">File Transfer</div>
                </div>
                
                <div class="card">
                    <div class="card-title">
                        <div class="icon">📁</div>
                        Upload Files
                    </div>
                    <div class="upload-zone" id="dropzone">
                        <div class="upload-icon">📦</div>
                        <div class="upload-text">Drag & drop ROM files here</div>
                        <div class="upload-hint">or click to browse • .nes files only</div>
                        <input type="file" id="fileInput" accept=".nes" multiple>
                    </div>
                    <div class="progress" id="progress">
                        <div class="progress-bar" id="progressBar"></div>
                    </div>
                </div>
                
                <div class="card">
                    <div class="card-title">
                        <div class="icon">🎮</div>
                        Your ROMs
                    </div>
                    <ul class="file-list" id="fileList">
                        <div class="empty-state">Loading...</div>
                    </ul>
                </div>
            </div>
            
            <div class="toast" id="toast"></div>
            
            <script>
                const dropzone = document.getElementById('dropzone');
                const fileInput = document.getElementById('fileInput');
                const fileList = document.getElementById('fileList');
                const progress = document.getElementById('progress');
                const progressBar = document.getElementById('progressBar');
                const toast = document.getElementById('toast');
                
                // Drag & drop
                dropzone.addEventListener('click', () => fileInput.click());
                dropzone.addEventListener('dragover', (e) => {
                    e.preventDefault();
                    dropzone.classList.add('dragover');
                });
                dropzone.addEventListener('dragleave', () => dropzone.classList.remove('dragover'));
                dropzone.addEventListener('drop', (e) => {
                    e.preventDefault();
                    dropzone.classList.remove('dragover');
                    handleFiles(e.dataTransfer.files);
                });
                fileInput.addEventListener('change', () => handleFiles(fileInput.files));
                
                function handleFiles(files) {
                    for (const file of files) {
                        if (file.name.toLowerCase().endsWith('.nes')) {
                            uploadFile(file);
                        }
                    }
                }
                
                function uploadFile(file) {
                    const formData = new FormData();
                    formData.append('file', file);
                    
                    progress.style.display = 'block';
                    progressBar.style.width = '0%';
                    
                    const xhr = new XMLHttpRequest();
                    xhr.open('POST', '/api/upload');
                    
                    xhr.upload.onprogress = (e) => {
                        if (e.lengthComputable) {
                            progressBar.style.width = (e.loaded / e.total * 100) + '%';
                        }
                    };
                    
                    xhr.onload = () => {
                        progress.style.display = 'none';
                        if (xhr.status === 200) {
                            showToast('✅ ' + file.name + ' uploaded!');
                            loadFiles();
                        } else {
                            showToast('❌ Upload failed');
                        }
                    };
                    
                    xhr.send(formData);
                }
                
                function loadFiles() {
                    fetch('/api/files')
                        .then(r => r.json())
                        .then(data => {
                            if (data.files.length === 0) {
                                fileList.innerHTML = '<div class="empty-state">No ROMs yet. Upload some!</div>';
                                return;
                            }
                            
                            fileList.innerHTML = data.files.map(f => `
                                <li class="file-item">
                                    <div class="file-icon">🎮</div>
                                    <div class="file-name">${f.name}</div>
                                    <div class="file-size">${formatSize(f.size)}</div>
                                    <button class="delete-btn" onclick="deleteFile('${f.name}')">Delete</button>
                                </li>
                            `).join('');
                        });
                }
                
                function deleteFile(name) {
                    if (confirm('Delete ' + name + '?')) {
                        fetch('/api/delete/' + encodeURIComponent(name), { method: 'DELETE' })
                            .then(() => {
                                showToast('🗑️ Deleted ' + name);
                                loadFiles();
                            });
                    }
                }
                
                function formatSize(bytes) {
                    if (bytes < 1024) return bytes + ' B';
                    if (bytes < 1024*1024) return (bytes/1024).toFixed(1) + ' KB';
                    return (bytes/1024/1024).toFixed(1) + ' MB';
                }
                
                function showToast(msg) {
                    toast.textContent = msg;
                    toast.style.display = 'block';
                    setTimeout(() => toast.style.display = 'none', 3000);
                }
                
                loadFiles();
            </script>
        </body>
        </html>
        """
    }
}

