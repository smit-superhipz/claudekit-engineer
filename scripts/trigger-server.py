#!/usr/bin/env python3
"""Simple HTTP trigger server for download.sh"""
import subprocess
import http.server
import json
import re
from datetime import datetime

PORT = 8080
DOWNLOAD_SCRIPT = "/app/download.sh"

def strip_ansi(text):
    """Remove ANSI color codes from text"""
    return re.sub(r'\x1b\[[0-9;]*m', '', text)

def parse_download_output(stdout):
    """Parse download.sh output and extract file status"""
    clean = strip_ansi(stdout)
    files = []
    errors = []

    for line in clean.split('\n'):
        line = line.strip()

        # Downloaded new file
        if line.startswith('✓ Downloaded:'):
            filename = line.replace('✓ Downloaded:', '').strip()
            files.append({"file": filename, "status": "downloaded"})

        # Already exists
        elif 'Already exists:' in line:
            match = re.search(r'Already exists: ([^\s]+)', line)
            if match:
                files.append({"file": match.group(1), "status": "exists"})

        # Errors
        elif line.startswith('✗'):
            errors.append(line.replace('✗', '').strip())

    return files, errors

class TriggerHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/trigger-download":
            self.trigger_download()
        elif self.path == "/trigger-download?force=true":
            self.trigger_download(force=True)
        elif self.path == "/health":
            self.send_json(200, {"status": "ok"})
        else:
            self.send_json(404, {"error": "Not found"})

    def trigger_download(self, force=False):
        try:
            cmd = ["bash", DOWNLOAD_SCRIPT]
            if force:
                cmd.append("--force")

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=300
            )

            files, errors = parse_download_output(result.stdout)

            response = {
                "success": result.returncode == 0 and len(errors) == 0,
                "files": files
            }

            if errors:
                response["errors"] = errors

            self.send_json(200, response)

        except subprocess.TimeoutExpired:
            self.send_json(500, {"success": False, "error": "timeout"})
        except Exception as e:
            self.send_json(500, {"success": False, "error": str(e)})

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
    print(f"  GET /trigger-download?force=true - Force re-download")
    print(f"  GET /health - Health check")
    http.server.HTTPServer(("", PORT), TriggerHandler).serve_forever()
