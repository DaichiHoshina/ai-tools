// @ts-check
const path = require("path");

const {
  displayStatusLine,
  getGitBranch,
  isWorktree,
  progressBar,
} = require("../../statusline.js");

// --- getGitBranch ---

describe("getGitBranch", () => {
  test("有効なgitリポジトリでブランチ名を返す", () => {
    const branch = getGitBranch(process.cwd());
    expect(typeof branch).toBe("string");
    expect(branch.length).toBeGreaterThan(0);
  });

  test("無効なディレクトリで?を返す", () => {
    const branch = getGitBranch("/nonexistent/path");
    expect(branch).toBe("?");
  });
});

// --- isWorktree ---

describe("isWorktree", () => {
  test("通常リポジトリでfalseを返す", () => {
    // process.cwd() が git worktree の場合に環境依存で fail するため、
    // 一時 dir に通常リポジトリを作って判定する
    const fs = require("fs");
    const os = require("os");
    const { execFileSync } = require("child_process");
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "statusline-test-"));
    try {
      execFileSync("git", ["init", "-q"], { cwd: tmpDir, stdio: "ignore" });
      expect(isWorktree(tmpDir)).toBe(false);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test("無効なディレクトリでfalseを返す", () => {
    expect(isWorktree("/nonexistent/path")).toBe(false);
  });
});

// --- progressBar ---

describe("progressBar", () => {
  test("0%で空バーを返す", () => {
    const bar = progressBar(0, 10);
    expect(typeof bar).toBe("string");
    expect(bar.length).toBeGreaterThan(0);
  });

  test("100%で満タンバーを返す", () => {
    const bar = progressBar(100, 10);
    expect(typeof bar).toBe("string");
  });

  test("幅0でも文字列を返す", () => {
    const bar = progressBar(50, 0);
    expect(typeof bar).toBe("string");
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

  test("空データでもクラッシュしない", () => {
    displayStatusLine({});
    expect(consoleSpy).toHaveBeenCalled();
  });

  test("context_windowデータでpctを表示", () => {
    displayStatusLine({
      context_window: { used_percentage: 45.5 },
    });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("46%");
  });

  test("70%以上で/compactを表示", () => {
    displayStatusLine({
      context_window: { used_percentage: 75 },
    });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("75%");
    expect(output).toContain("/compact");
  });

  test("90%以上で/reloadを表示", () => {
    displayStatusLine({
      context_window: { used_percentage: 95 },
    });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("95%");
    expect(output).toContain("/reload");
  });

  test("used_percentage未定義でデフォルト0%", () => {
    displayStatusLine({ context_window: {} });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("0%");
  });

  test("rate_limitsで5h/7dの使用率とreset時刻を表示", () => {
    displayStatusLine({
      context_window: { used_percentage: 40 },
      rate_limits: {
        five_hour: { used_percentage: 26, resets_at: 1752825600 },
        seven_day: { used_percentage: 12, resets_at: 1753000000 },
      },
    });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("5h");
    expect(output).toContain("26%");
    expect(output).toContain("7d");
    expect(output).toContain("12%");
    expect(output).toContain("↺");
  });

  test("rate_limits不在なら5h/7dを表示しない", () => {
    displayStatusLine({ context_window: { used_percentage: 40 } });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).not.toContain("5h");
    expect(output).not.toContain("7d");
  });

  test("cost.total_cost_usdがあっても$表示しない", () => {
    displayStatusLine({
      context_window: { used_percentage: 40 },
      cost: { total_cost_usd: 1.86 },
    });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).not.toContain("$");
  });

  test("モデル名からClaudeプレフィックスを除去", () => {
    displayStatusLine({
      model: { display_name: "Claude Opus 4.6" },
    });
    const output = consoleSpy.mock.calls[0][0];
    expect(output).toContain("Opus 4.6");
    expect(output).not.toContain("Claude Opus");
  });
});
