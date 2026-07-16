import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from dashboard import server


def _build_db(path):
    conn = sqlite3.connect(str(path))
    conn.executescript(
        """
        CREATE TABLE sessions (
            session_id TEXT,
            project TEXT,
            model TEXT,
            start_time TEXT,
            duration_sec INTEGER,
            total_messages INTEGER,
            input_tokens INTEGER,
            output_tokens INTEGER,
            cache_read_tokens INTEGER,
            cache_write_tokens INTEGER
        );
        CREATE TABLE tool_events (
            tool_name TEXT,
            tool_category TEXT,
            timestamp TEXT,
            project TEXT
        );
        CREATE TABLE agent_events (
            agent_type TEXT,
            start_time TEXT,
            duration_sec INTEGER,
            project TEXT
        );
        """
    )
    conn.execute(
        "INSERT INTO sessions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        ("s1", "proj-a", "claude-sonnet-4-6", "2026-07-01T00:00:00Z", 100, 10, 1000, 500, 0, 0),
    )
    conn.execute(
        "INSERT INTO sessions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        ("s2", "proj-b", "claude-opus-4-6", "2026-07-02T00:00:00Z", 200, 20, 2000, 1000, 0, 0),
    )
    conn.execute(
        "INSERT INTO tool_events VALUES (?, ?, ?, ?)",
        ("Read", "file", "2026-07-01T00:00:00Z", "proj-a"),
    )
    conn.execute(
        "INSERT INTO tool_events VALUES (?, ?, ?, ?)",
        ("Bash", "shell", "2026-07-02T00:00:00Z", "proj-b"),
    )
    conn.execute(
        "INSERT INTO agent_events VALUES (?, ?, ?, ?)",
        ("explore-agent", "2026-07-01T00:00:00Z", 30, "proj-a"),
    )
    conn.commit()
    conn.close()


class ApiOverviewTest(unittest.TestCase):
    def setUp(self):
        self._tmpdir = tempfile.TemporaryDirectory()
        self.db_path = Path(self._tmpdir.name) / "analytics.db"
        _build_db(self.db_path)
        self._patcher = mock.patch.object(server, "DB_PATH", self.db_path)
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()
        self._tmpdir.cleanup()

    def test_api_overview_counts_all(self):
        result = server.api_overview({"days": "all", "project": "all"})
        self.assertEqual(result["total_sessions"], 2)
        self.assertEqual(result["total_tool_uses"], 2)
        self.assertEqual(result["total_agent_runs"], 1)
        self.assertEqual(result["total_tokens"], {"input": 3000, "output": 1500, "cache_read": 0, "cache_write": 0})
        self.assertEqual(result["projects"], ["proj-a", "proj-b"])

    def test_api_overview_filters_by_project(self):
        result = server.api_overview({"days": "all", "project": "proj-a"})
        self.assertEqual(result["total_sessions"], 1)
        self.assertEqual(result["total_tool_uses"], 1)

    def test_api_overview_no_db_returns_empty(self):
        missing = Path(self._tmpdir.name) / "missing.db"
        with mock.patch.object(server, "DB_PATH", missing):
            result = server.api_overview({})
        self.assertEqual(result["total_sessions"], 0)
        self.assertEqual(result["projects"], [])


class ApiToolsTest(unittest.TestCase):
    def setUp(self):
        self._tmpdir = tempfile.TemporaryDirectory()
        self.db_path = Path(self._tmpdir.name) / "analytics.db"
        _build_db(self.db_path)
        self._patcher = mock.patch.object(server, "DB_PATH", self.db_path)
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()
        self._tmpdir.cleanup()

    def test_api_tools_by_name_and_category(self):
        result = server.api_tools({"days": "all", "project": "all"})
        names = {row["name"] for row in result["by_name"]}
        self.assertEqual(names, {"Read", "Bash"})
        categories = {row["category"] for row in result["by_category"]}
        self.assertEqual(categories, {"file", "shell"})

    def test_api_tools_daily_trend(self):
        result = server.api_tools({"days": "all", "project": "all"})
        dates = [row["date"] for row in result["daily_trend"]]
        self.assertEqual(dates, ["2026-07-01", "2026-07-02"])

    def test_api_tools_no_db_returns_empty(self):
        missing = Path(self._tmpdir.name) / "missing.db"
        with mock.patch.object(server, "DB_PATH", missing):
            result = server.api_tools({})
        self.assertEqual(result, {"by_name": [], "by_category": [], "daily_trend": []})


if __name__ == "__main__":
    unittest.main()
