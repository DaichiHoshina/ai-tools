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
        ("s1", "proj-a", "claude-sonnet-4-6", "2026-07-01T00:00:00Z", 100, 10, 1000, 500, 100, 50),
    )
    conn.execute(
        "INSERT INTO sessions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        ("s2", "proj-b", "claude-opus-4-6", "2026-07-02T00:00:00Z", 200, 20, 2000, 1000, 0, 0),
    )
    conn.execute(
        "INSERT INTO agent_events VALUES (?, ?, ?, ?)",
        ("explore-agent", "2026-07-01T00:00:00Z", 30, "proj-a"),
    )
    conn.execute(
        "INSERT INTO agent_events VALUES (?, ?, ?, ?)",
        ("explore-agent", "2026-07-02T00:00:00Z", 10, "proj-b"),
    )
    conn.commit()
    conn.close()


class _DbTestBase(unittest.TestCase):
    def setUp(self):
        self._tmpdir = tempfile.TemporaryDirectory()
        self.db_path = Path(self._tmpdir.name) / "analytics.db"
        _build_db(self.db_path)
        self._patcher = mock.patch.object(server, "DB_PATH", self.db_path)
        self._patcher.start()

    def tearDown(self):
        self._patcher.stop()
        self._tmpdir.cleanup()


class ApiSessionsTest(_DbTestBase):
    def test_api_sessions_returns_rows_desc(self):
        result = server.api_sessions({"days": "all", "project": "all"})
        ids = [row["session_id"] for row in result["sessions"]]
        self.assertEqual(ids, ["s2", "s1"])

    def test_api_sessions_daily_trend(self):
        result = server.api_sessions({"days": "all", "project": "all"})
        dates = [row["date"] for row in result["daily_trend"]]
        self.assertEqual(dates, ["2026-07-01", "2026-07-02"])

    def test_api_sessions_no_db_returns_empty(self):
        missing = Path(self._tmpdir.name) / "missing.db"
        with mock.patch.object(server, "DB_PATH", missing):
            result = server.api_sessions({})
        self.assertEqual(result, {"sessions": [], "daily_trend": []})


class ApiTokensTest(_DbTestBase):
    def test_api_tokens_daily(self):
        result = server.api_tokens({"days": "all", "project": "all"})
        dates = [row["date"] for row in result["daily"]]
        self.assertEqual(dates, ["2026-07-01", "2026-07-02"])

    def test_api_tokens_by_model_and_cost(self):
        result = server.api_tokens({"days": "all", "project": "all"})
        models = {row["model"] for row in result["by_model"]}
        self.assertEqual(models, {"claude-sonnet-4-6", "claude-opus-4-6"})
        self.assertGreater(result["estimated_cost"]["total_usd"], 0)
        self.assertEqual(len(result["estimated_cost"]["by_model"]), 2)

    def test_api_tokens_no_db_returns_empty(self):
        missing = Path(self._tmpdir.name) / "missing.db"
        with mock.patch.object(server, "DB_PATH", missing):
            result = server.api_tokens({})
        self.assertEqual(
            result,
            {"daily": [], "by_model": [], "estimated_cost": {"total_usd": 0, "by_model": []}},
        )


class ApiAgentsTest(_DbTestBase):
    def test_api_agents_by_type(self):
        result = server.api_agents({"days": "all", "project": "all"})
        self.assertEqual(len(result["by_type"]), 1)
        self.assertEqual(result["by_type"][0]["type"], "explore-agent")
        self.assertEqual(result["by_type"][0]["count"], 2)

    def test_api_agents_daily_trend(self):
        result = server.api_agents({"days": "all", "project": "all"})
        dates = [row["date"] for row in result["daily_trend"]]
        self.assertEqual(dates, ["2026-07-01", "2026-07-02"])

    def test_api_agents_no_db_returns_empty(self):
        missing = Path(self._tmpdir.name) / "missing.db"
        with mock.patch.object(server, "DB_PATH", missing):
            result = server.api_agents({})
        self.assertEqual(result, {"by_type": [], "daily_trend": []})


if __name__ == "__main__":
    unittest.main()
