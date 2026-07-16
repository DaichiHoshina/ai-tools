import unittest

from dashboard.server import build_where, calc_cost, get_date_filter, parse_query_params


class ParseQueryParamsTest(unittest.TestCase):
    def test_parse_query_params_basic(self):
        self.assertEqual(parse_query_params("/api/tools?days=7"), {"days": "7"})

    def test_parse_query_params_multiple(self):
        params = parse_query_params("/api/tools?days=7&project=foo")
        self.assertEqual(params, {"days": "7", "project": "foo"})

    def test_parse_query_params_empty(self):
        self.assertEqual(parse_query_params("/api/tools"), {})

    def test_parse_query_params_takes_first_value(self):
        params = parse_query_params("/api/tools?days=7&days=30")
        self.assertEqual(params["days"], "7")


class GetDateFilterTest(unittest.TestCase):
    def test_get_date_filter_all_returns_none(self):
        self.assertIsNone(get_date_filter("all"))

    def test_get_date_filter_valid_days_returns_string(self):
        result = get_date_filter("7")
        self.assertIsInstance(result, str)
        self.assertRegex(result, r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_get_date_filter_invalid_defaults_to_30(self):
        result_invalid = get_date_filter("not-a-number")
        result_30 = get_date_filter("30")
        self.assertEqual(result_invalid[:10], result_30[:10])


class BuildWhereTest(unittest.TestCase):
    def test_build_where_no_conditions(self):
        where, params = build_where(None, "all", "start_time")
        self.assertEqual(where, "")
        self.assertEqual(params, [])

    def test_build_where_cutoff_only(self):
        where, params = build_where("2026-01-01T00:00:00Z", "all", "start_time")
        self.assertEqual(where, "WHERE start_time >= ?")
        self.assertEqual(params, ["2026-01-01T00:00:00Z"])

    def test_build_where_project_only(self):
        where, params = build_where(None, "my-project", "timestamp")
        self.assertEqual(where, "WHERE project = ?")
        self.assertEqual(params, ["my-project"])

    def test_build_where_both_conditions(self):
        where, params = build_where("2026-01-01T00:00:00Z", "my-project", "timestamp", "proj_col")
        self.assertEqual(where, "WHERE timestamp >= ? AND proj_col = ?")
        self.assertEqual(params, ["2026-01-01T00:00:00Z", "my-project"])


class CalcCostTest(unittest.TestCase):
    def test_calc_cost_known_model(self):
        cost = calc_cost("claude-sonnet-4-6", 1_000_000, 1_000_000, 0, 0)
        self.assertAlmostEqual(cost, 18.0)

    def test_calc_cost_unknown_model_falls_back_to_sonnet(self):
        cost_unknown = calc_cost("unknown-model", 1_000_000, 0, 0, 0)
        cost_sonnet = calc_cost("claude-sonnet-4-6", 1_000_000, 0, 0, 0)
        self.assertEqual(cost_unknown, cost_sonnet)

    def test_calc_cost_zero_tokens(self):
        self.assertEqual(calc_cost("claude-opus-4-6", 0, 0, 0, 0), 0.0)


if __name__ == "__main__":
    unittest.main()
