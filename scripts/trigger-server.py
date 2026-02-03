#!/usr/bin/env python3
"""Simple HTTP trigger server for download.sh"""
import subprocess
import http.server
import json
from datetime import datetime

PORT = 8080
DOWNLOAD_SCRIPT = "/app/download.sh"

class TriggerHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/trigger-download":
            self.trigger_download()
        elif self.path == "/health":
            self.send_json(200, {"status": "ok"})
        else:
            self.send_json(404, {"error": "Not found"})

    def trigger_download(self):
        try:
            result = subprocess.run(
                ["bash", DOWNLOAD_SCRIPT],
                capture_output=True,
                text=True,
                timeout=300
            )
            self.send_json(200, {
                "success": result.returncode == 0,
                "timestamp": datetime.now().isoformat(),
                "stdout": result.stdout[-2000:] if result.stdout else "",
                "stderr": result.stderr[-500:] if result.stderr else ""
            })
        except Exception as e:
            self.send_json(500, {"error": str(e)})

    def send_json(self, code, data):
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())

    def log_message(self, format, *args):
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {args[0]}")

if __name__ == "__main__":
    print(f"Trigger server running on port {PORT}")
    print(f"  GET /trigger-download - Run download.sh")
    print(f"  GET /health - Health check")
    http.server.HTTPServer(("", PORT), TriggerHandler).serve_forever()
