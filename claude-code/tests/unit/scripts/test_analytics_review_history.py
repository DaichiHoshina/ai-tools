"""
analytics-report.py のレビュー履歴解析関数ユニットテスト
stdlib unittest 使用（pytest 不要）

実行:
    python3 -m unittest tests/unit/scripts/test_analytics_review_history.py
"""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


def _load_analytics_module():
    """ハイフン入りファイル名のため importlib で動的ロード。"""
    repo_root = Path(__file__).resolve().parents[3]
    script_path = repo_root / "scripts" / "analytics-report.py"
    spec = importlib.util.spec_from_file_location("analytics_report", script_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


arep = _load_analytics_module()


class LoadReviewHistoryTest(unittest.TestCase):
    def test_returns_empty_when_file_missing(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(arep.load_review_history(Path(d)), [])

    def test_returns_empty_when_dir_only(self):
        with tempfile.TemporaryDirectory() as d:
            (Path(d) / ".claude").mkdir()
            self.assertEqual(arep.load_review_history(Path(d)), [])

    def test_loads_jsonl_entries(self):
        with tempfile.TemporaryDirectory() as d:
            cdir = Path(d) / ".claude"
            cdir.mkdir()
            f = cdir / "review-history.jsonl"
            f.write_text(
                '{"date":"2026-04-20","focus":"security","file":"a.ts","line":10,"confidence":95,"severity":"Critical"}\n'
                '{"date":"2026-04-21","focus":"quality","file":"b.go","line":20,"confidence":65,"severity":"Warning"}\n'
            )
            entries = arep.load_review_history(Path(d))
            self.assertEqual(len(entries), 2)
            self.assertEqual(entries[0]["focus"], "security")

    def test_skips_invalid_json_lines(self):
        with tempfile.TemporaryDirectory() as d:
            cdir = Path(d) / ".claude"
            cdir.mkdir()
            f = cdir / "review-history.jsonl"
            f.write_text(
                '{"date":"2026-04-20","focus":"security"}\n'
                'NOT_A_JSON_LINE\n'
                '{"date":"2026-04-21","focus":"quality"}\n'
                '\n'
            )
            entries = arep.load_review_history(Path(d))
            self.assertEqual(len(entries), 2)


class AnalyzeReviewHistoryTest(unittest.TestCase):
    def test_empty_returns_empty_dict(self):
        self.assertEqual(arep.analyze_review_history([]), {})

    def test_counts_focus_and_severity(self):
        entries = [
            {"date": "2026-04-20", "focus": "security", "severity": "Critical", "confidence": 95},
            {"date": "2026-04-21", "focus": "security", "severity": "Critical", "confidence": 85},
            {"date": "2026-04-22", "focus": "quality", "severity": "Warning", "confidence": 65},
        ]
        stats = arep.analyze_review_history(entries)
        self.assertEqual(stats["total"], 3)
        self.assertEqual(stats["focus_counts"]["security"], 2)
        self.assertEqual(stats["focus_counts"]["quality"], 1)
        self.assertEqual(stats["severity_counts"]["Critical"], 2)
        self.assertEqual(stats["severity_counts"]["Warning"], 1)

    def test_confidence_buckets(self):
        entries = [
            {"date": "2026-04-20", "focus": "x", "confidence": 95},
            {"date": "2026-04-20", "focus": "x", "confidence": 80},
            {"date": "2026-04-20", "focus": "x", "confidence": 70},
            {"date": "2026-04-20", "focus": "x", "confidence": 30},
            {"date": "2026-04-20", "focus": "x", "confidence": 10},
        ]
        stats = arep.analyze_review_history(entries)
        cb = stats["confidence_buckets"]
        self.assertEqual(cb["80-100"], 2)
        self.assertEqual(cb["50-79"], 1)
        self.assertEqual(cb["25-49"], 1)

    def test_repeated_detection_threshold(self):
        # 同一 file:line bucket で3回以上 → repeated に登場
        entries = [
            {"date": "2026-04-20", "focus": "arch", "file": "x.ts", "line": 10, "confidence": 90},
            {"date": "2026-04-21", "focus": "arch", "file": "x.ts", "line": 11, "confidence": 90},
            {"date": "2026-04-22", "focus": "arch", "file": "x.ts", "line": 9, "confidence": 90},
        ]
        stats = arep.analyze_review_history(entries)
        self.assertGreaterEqual(len(stats["repeated"]), 1)
        loc, cnt = stats["repeated"][0]
        self.assertEqual(cnt, 3)

    def test_repeated_skipped_when_under_3(self):
        entries = [
            {"date": "2026-04-20", "focus": "arch", "file": "x.ts", "line": 10, "confidence": 90},
            {"date": "2026-04-21", "focus": "arch", "file": "x.ts", "line": 10, "confidence": 90},
        ]
        stats = arep.analyze_review_history(entries)
        self.assertEqual(stats["repeated"], [])


class FormatReviewHistoryTest(unittest.TestCase):
    def test_empty_stats_returns_empty_string(self):
        self.assertEqual(arep.format_review_history({}), "")
        self.assertEqual(arep.format_review_history({"total": 0}), "")

    def test_renders_summary_lines(self):
        entries = [
            {"date": "2026-04-20", "focus": "security", "severity": "Critical", "confidence": 95},
            {"date": "2026-04-21", "focus": "quality", "severity": "Warning", "confidence": 65},
        ]
        stats = arep.analyze_review_history(entries)
        out = arep.format_review_history(stats)
        self.assertIn("レビュー履歴", out)
        self.assertIn("累計指摘数: 2件", out)
        self.assertIn("Critical 1", out)
        self.assertIn("Warning 1", out)
        self.assertIn("security(1)", out)

    def test_renders_repeated_section(self):
        entries = [
            {"date": "2026-04-20", "focus": "arch", "file": "x.ts", "line": 10, "confidence": 90, "severity": "Critical"},
            {"date": "2026-04-21", "focus": "arch", "file": "x.ts", "line": 11, "confidence": 90, "severity": "Critical"},
            {"date": "2026-04-22", "focus": "arch", "file": "x.ts", "line": 9, "confidence": 90, "severity": "Critical"},
        ]
        stats = arep.analyze_review_history(entries)
        out = arep.format_review_history(stats)
        self.assertIn("繰り返し指摘", out)
        self.assertIn("arch", out)
        self.assertIn("x.ts", out)


if __name__ == "__main__":
    unittest.main()
