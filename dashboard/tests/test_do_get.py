import http.client
import http.server
import sqlite3
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

from dashboard import server


class DoGetTest(unittest.TestCase):
    def setUp(self):
        self._tmpdir = tempfile.TemporaryDirectory()
        self.db_path = Path(self._tmpdir.name) / "analytics.db"
        conn = sqlite3.connect(str(self.db_path))
        conn.executescript(
            """
            CREATE TABLE sessions (
                session_id TEXT, project TEXT, model TEXT, start_time TEXT,
                duration_sec INTEGER, total_messages INTEGER,
                input_tokens INTEGER, output_tokens INTEGER,
                cache_read_tokens INTEGER, cache_write_tokens INTEGER
            );
            CREATE TABLE tool_events (
                tool_name TEXT, tool_category TEXT, timestamp TEXT, project TEXT
            );
            CREATE TABLE agent_events (
                agent_type TEXT, start_time TEXT, duration_sec INTEGER, project TEXT
            );
            """
        )
        conn.commit()
        conn.close()

        self.html_path = Path(self._tmpdir.name) / "index.html"
        self.html_path.write_text("<html>dashboard</html>", encoding="utf-8")

        self._db_patcher = mock.patch.object(server, "DB_PATH", self.db_path)
        self._html_patcher = mock.patch.object(server, "HTML_PATH", self.html_path)
        self._db_patcher.start()
        self._html_patcher.start()

        self.httpd = http.server.HTTPServer(("127.0.0.1", 0), server.DashboardHandler)
        self.port = self.httpd.server_address[1]
        self._thread = threading.Thread(target=self.httpd.serve_forever)
        self._thread.daemon = True
        self._thread.start()

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self._thread.join(timeout=5)
        self._db_patcher.stop()
        self._html_patcher.stop()
        self._tmpdir.cleanup()

    def _get(self, path):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request("GET", path)
        resp = conn.getresponse()
        body = resp.read()
        conn.close()
        return resp.status, body

    def test_root_returns_200_and_html(self):
        status, body = self._get("/")
        self.assertEqual(status, 200)
        self.assertIn(b"dashboard", body)

    def test_routes_hit_returns_json(self):
        status, body = self._get("/api/overview")
        self.assertEqual(status, 200)
        self.assertIn(b"total_sessions", body)

    def test_unknown_path_returns_404(self):
        status, body = self._get("/no-such-path")
        self.assertEqual(status, 404)
        self.assertIn(b"Not Found", body)


if __name__ == "__main__":
    unittest.main()
