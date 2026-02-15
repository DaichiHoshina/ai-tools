// @ts-check
const fs = require("fs");
const path = require("path");
const os = require("os");

const {
  getStatusState,
  formatTokenCount,
  getGitBranch,
  getCurrentSkill,
  getTotalUserCount,
  getResponseCounter,
  displayStatusLine,
  STATUS_STATES,
  CACHE_TTL_MS,
  cache,
} = require("../../statusline.js");

// --- getStatusState ---

describe("getStatusState", () => {
  test("0%でnormal状態を返す", () => {
    const state = getStatusState(0);
    expect(state).toBe(STATUS_STATES.normal);
  });

  test("50%でnormal状態を返す", () => {
    const state = getStatusState(50);
    expect(state).toBe(STATUS_STATES.normal);
  });

  test("69%でnormal状態を返す", () => {
    const state = getStatusState(69);
    expect(state).toBe(STATUS_STATES.normal);
  });

  test("70%でwarning状態を返す", () => {
    const state = getStatusState(70);
    expect(state).toBe(STATUS_STATES.warning);
  });

  test("85%でwarning状態を返す", () => {
    const state = getStatusState(85);
    expect(state).toBe(STATUS_STATES.warning);
  });

  test("89%でwarning状態を返す", () => {
    const state = getStatusState(89);
    expect(state).toBe(STATUS_STATES.warning);
  });

  test("90%でcritical状態を返す", () => {
    const state = getStatusState(90);
    expect(state).toBe(STATUS_STATES.critical);
  });

  test("100%でcritical状態を返す", () => {
    const state = getStatusState(100);
    expect(state).toBe(STATUS_STATES.critical);
  });
});

// --- formatTokenCount ---

describe("formatTokenCount", () => {
  test("0を正しくフォーマット", () => {
    expect(formatTokenCount(0)).toBe("0");
  });

  test("小さい数値はそのまま", () => {
    expect(formatTokenCount(999)).toBe("999");
  });

  test("1000以上をカンマ区切り", () => {
    const result = formatTokenCount(1000);
    expect(result).toMatch(/1.000|1,000/);
  });

  test("大きい数値をカンマ区切り", () => {
    const result = formatTokenCount(1234567);
    expect(result).toMatch(/1.234.567|1,234,567/);
  });
});

// --- STATUS_STATES ---

describe("STATUS_STATES", () => {
  test("8つの状態が定義されている", () => {
    expect(Object.keys(STATUS_STATES)).toHaveLength(8);
  });

  test("全状態にcolor, icon, label, thresholdがある", () => {
    for (const [name, state] of Object.entries(STATUS_STATES)) {
      expect(state).toHaveProperty("color");
      expect(state).toHaveProperty("icon");
      expect(state).toHaveProperty("label");
      expect(state).toHaveProperty("threshold");
      expect(typeof state.color).toBe("string");
      expect(typeof state.icon).toBe("string");
      expect(typeof state.label).toBe("string");
      expect(typeof state.threshold).toBe("number");
    }
  });

  test("warningのthresholdは70", () => {
    expect(STATUS_STATES.warning.threshold).toBe(70);
  });

  test("criticalのthresholdは90", () => {
    expect(STATUS_STATES.critical.threshold).toBe(90);
  });
});

// --- CACHE_TTL_MS ---

describe("CACHE_TTL_MS", () => {
  test("5000ms (5秒)", () => {
    expect(CACHE_TTL_MS).toBe(5000);
  });
});

// --- getGitBranch ---

describe("getGitBranch", () => {
  test("有効なgitリポジトリでブランチ名を返す", () => {
    const branch = getGitBranch(process.cwd());
    expect(typeof branch).toBe("string");
    expect(branch.length).toBeGreaterThan(0);
  });

  test("無効なディレクトリでunknownを返す", () => {
    const branch = getGitBranch("/nonexistent/path");
    expect(branch).toBe("unknown");
  });
});

// --- getCurrentSkill ---

describe("getCurrentSkill", () => {
  test("状態ファイルがない場合noneを返す", () => {
    const skill = getCurrentSkill();
    expect(typeof skill).toBe("string");
  });
});

// --- getTotalUserCount ---

describe("getTotalUserCount", () => {
  test("存在しないセッションIDで0を返す", async () => {
    const count = await getTotalUserCount("nonexistent-session-id");
    expect(count).toBe(0);
  });

  test("空文字で0を返す", async () => {
    const count = await getTotalUserCount("");
    expect(count).toBe(0);
  });
});

// --- getResponseCounter ---

describe("getResponseCounter", () => {
  test("undefinedのセッションIDで1を返す", async () => {
    const counter = await getResponseCounter(undefined);
    expect(counter).toBe(1);
  });

  test("存在しないセッションIDで1を返す", async () => {
    const counter = await getResponseCounter("nonexistent-id");
    expect(counter).toBeGreaterThanOrEqual(1);
  });
});

// --- displayStatusLine ---

describe("displayStatusLine", () => {
  let consoleSpy;

  beforeEach(() => {
    consoleSpy = jest.spyOn(console, "log").mockImplementation(() => {});
  });

  afterEach(() => {
    consoleSpy.mockRestore();
  });

  test("空データでもクラッシュしない", async () => {
    await displayStatusLine({});
    expect(consoleSpy).toHaveBeenCalled();
  });

  test("context_windowデータを表示", async () => {
    await displayStatusLine({
      context_window: {
        used_percentage: 45.5,
        total_input_tokens: 10000,
        total_output_tokens: 5000,
      },
    });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("46%");
    expect(output).toContain("15,000");
  });

  test("warning閾値でwarningアイコンを表示", async () => {
    await displayStatusLine({
      context_window: {
        used_percentage: 75,
        total_input_tokens: 50000,
        total_output_tokens: 25000,
      },
    });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("75%");
    expect(output).toContain("Warning");
  });

  test("critical閾値で/reloadを表示", async () => {
    await displayStatusLine({
      context_window: {
        used_percentage: 95,
        total_input_tokens: 90000,
        total_output_tokens: 10000,
      },
    });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("95%");
    expect(output).toContain("/reload");
  });

  test("used_percentage未定義でデフォルト0%", async () => {
    await displayStatusLine({
      context_window: {},
    });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("0%");
  });

  test("context_window未定義でデフォルト表示", async () => {
    await displayStatusLine({});
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("0%");
  });
});

// --- cache ---

describe("cache", () => {
  test("初期状態が正しい", () => {
    expect(cache.userCount).toBeDefined();
    expect(typeof cache.userCount.value).toBe("number");
    expect(typeof cache.userCount.timestamp).toBe("number");
  });
});
