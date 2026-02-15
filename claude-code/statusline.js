#!/usr/bin/env node
// @ts-check
// statusline.js - Claude Code 2.1.6+ ステータスライン表示

const fs = require("fs");
const path = require("path");

/**
 * @typedef {Object} StatusState
 * @property {string} color - ANSIカラーコード
 * @property {string} icon - 状態アイコン
 * @property {string} label - 状態ラベル
 * @property {number} threshold - 閾値（パーセント）
 */

/**
 * @typedef {Object} ContextWindow
 * @property {number} [used_percentage] - コンテキスト使用率
 * @property {number} [total_input_tokens] - 入力トークン数
 * @property {number} [total_output_tokens] - 出力トークン数
 */

/**
 * @typedef {Object} StatusLineData
 * @property {ContextWindow} [context_window] - コンテキストウィンドウ情報
 * @property {string} [session_id] - セッションID
 * @property {string} [cwd] - カレントディレクトリ
 */

/**
 * @typedef {Object} CacheEntry
 * @property {number} value - キャッシュ値
 * @property {number} timestamp - 最終更新タイムスタンプ
 * @property {string|null} sessionId - セッションID
 */

/**
 * @typedef {Object} SessionCounterState
 * @property {string|null} sessionId - セッションID
 * @property {number} startCount - 開始カウント
 */

/** キャッシュTTL（ミリ秒） */
const CACHE_TTL_MS = 5000;

/** @type {{ userCount: CacheEntry }} キャッシュ（sessionId: null はセッション未設定を示す） */
let cache = {
  userCount: { value: 0, timestamp: 0, sessionId: null },
};

/** Material Design 3 準拠: 状態定義（色+シンボル併用で色覚障害対応）
 * @type {Record<string, StatusState>}
 */
const STATUS_STATES = {
  normal: { color: "\x1b[32m", icon: "\u25CB", label: "Ready", threshold: 0 },
  info: { color: "\x1b[34m", icon: "\u2139", label: "Info", threshold: 0 },
  success: { color: "\x1b[32m", icon: "\u2713", label: "Success", threshold: 0 },
  warning: { color: "\x1b[33m", icon: "\u25B2", label: "Warning", threshold: 70 },
  critical: { color: "\x1b[31m", icon: "\u2715", label: "Critical", threshold: 90 },
  error: { color: "\x1b[31m", icon: "\u274C", label: "Error", threshold: 0 },
  loading: { color: "\x1b[36m", icon: "\u23F3", label: "Loading", threshold: 0 },
  disabled: { color: "\x1b[90m", icon: "\u2297", label: "Disabled", threshold: 0 },
};

/**
 * 使用率に基づいて状態を判定する
 * @param {number} percentage - コンテキスト使用率（0-100）
 * @returns {StatusState} 判定された状態
 */
function getStatusState(percentage) {
  if (percentage >= STATUS_STATES.critical.threshold) {
    return STATUS_STATES.critical;
  } else if (percentage >= STATUS_STATES.warning.threshold) {
    return STATUS_STATES.warning;
  }
  return STATUS_STATES.normal;
}

/**
 * トークン数をカンマ区切りでフォーマットする
 * @param {number} tokens - トークン数
 * @returns {string} フォーマット済み文字列
 */
function formatTokenCount(tokens) {
  return tokens.toLocaleString();
}

/**
 * 現在のGitブランチ名を取得する
 * @param {string} cwd - 作業ディレクトリ
 * @returns {string} ブランチ名
 */
function getGitBranch(cwd) {
  try {
    const { execSync } = require("child_process");
    const branch = execSync("git rev-parse --abbrev-ref HEAD", {
      cwd,
      encoding: "utf8",
      stdio: ["pipe", "pipe", "ignore"],
    }).trim();
    return branch || "unknown";
  } catch {
    return "unknown";
  }
}

/**
 * 現在のスキル名を取得する
 * @returns {string} スキル名（未設定時は"none"）
 */
function getCurrentSkill() {
  try {
    const stateFile = path.join(
      process.env.HOME || "",
      ".claude",
      "state",
      "current-skill.txt",
    );
    if (fs.existsSync(stateFile)) {
      const skill = fs.readFileSync(stateFile, "utf8").trim();
      return skill || "none";
    }
    return "none";
  } catch {
    return "none";
  }
}

/**
 * セッション内のユーザーメッセージ数を取得する
 * @param {string} sessionId - セッションID
 * @returns {Promise<number>} メッセージ数
 */
async function getTotalUserCount(sessionId) {
  try {
    const projectsDir = path.join(process.env.HOME || "", ".claude", "projects");
    if (!fs.existsSync(projectsDir)) return 0;

    const projectDirs = fs
      .readdirSync(projectsDir)
      .map((dir) => path.join(projectsDir, dir))
      .filter((dir) => fs.statSync(dir).isDirectory());

    for (const projectDir of projectDirs) {
      const transcriptFile = path.join(projectDir, `${sessionId}.jsonl`);

      if (fs.existsSync(transcriptFile)) {
        const content = fs.readFileSync(transcriptFile, "utf8");
        const lines = content.trim().split("\n");

        let lastSummaryIndex = -1;
        for (let i = lines.length - 1; i >= 0; i--) {
          try {
            const entry = JSON.parse(lines[i]);
            if (entry.type === "summary") {
              lastSummaryIndex = i;
              break;
            }
          } catch {
            // Skip invalid JSON lines
          }
        }

        let count = 0;
        const startIndex = lastSummaryIndex + 1;
        for (let i = startIndex; i < lines.length; i++) {
          try {
            const entry = JSON.parse(lines[i]);
            if (entry.type === "user") {
              count++;
            }
          } catch {
            // Skip invalid JSON lines
          }
        }
        return count;
      }
    }
    return 0;
  } catch {
    return 0;
  }
}

/**
 * セッション内のレスポンスカウンターを取得する（キャッシュ付き）
 * @param {string|undefined} sessionId - セッションID
 * @returns {Promise<number>} カウンター値（1始まり）
 */
async function getResponseCounter(sessionId) {
  try {
    if (!sessionId) return 1;

    const now = Date.now();
    if (
      cache.userCount.sessionId === sessionId &&
      now - cache.userCount.timestamp < CACHE_TTL_MS
    ) {
      return cache.userCount.value;
    }

    const stateFile = path.join(
      process.env.HOME || "",
      ".claude",
      "state",
      "session-counter.json",
    );
    const stateDir = path.dirname(stateFile);

    if (!fs.existsSync(stateDir)) {
      fs.mkdirSync(stateDir, { recursive: true });
    }

    const totalCount = await getTotalUserCount(sessionId);

    /** @type {SessionCounterState} */
    let state = { sessionId: null, startCount: 0 };
    if (fs.existsSync(stateFile)) {
      try {
        state = JSON.parse(fs.readFileSync(stateFile, "utf8"));
      } catch {
        // Invalid state file, reset
      }
    }

    if (state.sessionId !== sessionId) {
      state = { sessionId, startCount: totalCount };
      fs.writeFileSync(stateFile, JSON.stringify(state));
    }

    const counter = Math.max(1, totalCount - state.startCount + 1);
    cache.userCount = { value: counter, timestamp: now, sessionId };

    return counter;
  } catch {
    return 1;
  }
}

/**
 * ステータスラインを表示する
 * @param {StatusLineData} data - 入力データ
 */
async function displayStatusLine(data) {
  let tokenDisplay = "0";
  let percentage = 0;
  let percentageColor = "\x1b[32m";
  let contextWarning = "";

  try {
    const contextWindow = data.context_window || {};

    if (contextWindow.used_percentage !== undefined) {
      percentage = Math.round(contextWindow.used_percentage);

      const inputTokens = contextWindow.total_input_tokens || 0;
      const outputTokens = contextWindow.total_output_tokens || 0;
      const totalTokens = inputTokens + outputTokens;
      tokenDisplay = formatTokenCount(totalTokens);
    }
  } catch {
    // トークン取得失敗時はデフォルト値を使用
  }

  try {
    const state = getStatusState(percentage);
    percentageColor = state.color;

    if (state === STATUS_STATES.warning) {
      contextWarning = ` ${state.icon} Warning`;
    } else if (state === STATUS_STATES.critical) {
      contextWarning = ` ${state.icon} /reload`;
    }

    const termWidth = process.stdout.columns || 80;
    let statusText;

    if (termWidth < 60) {
      statusText = `${percentage}%${contextWarning ? " " + state.icon : ""}`;
    } else {
      statusText = `${tokenDisplay} | ${percentage}%${contextWarning}`;
    }

    const visibleLength = statusText.replace(/\x1b\[[0-9;]*m/g, "").length;
    const padding = Math.max(0, termWidth - visibleLength - 2);
    console.log(
      `${" ".repeat(padding)}${tokenDisplay} | ${percentageColor}${percentage}%\x1b[0m${contextWarning}`,
    );
  } catch {
    console.log(`${tokenDisplay} | ${percentage}%`);
  }
}

// Read JSON from stdin (直接実行時のみ)
if (require.main === module) {
  let input = "";
  process.stdin.on("data", (chunk) => (input += chunk));
  process.stdin.on("end", async () => {
    try {
      const data = JSON.parse(input);
      await displayStatusLine(data);
    } catch (error) {
      console.log("[Status Unavailable]");

      if (process.env.DEBUG_STATUSLINE) {
        const err = /** @type {Error} */ (error);
        console.error(`[DEBUG] Error: ${err.message}`);
        console.error(`[DEBUG] Stack: ${err.stack}`);
        console.error(`[DEBUG] Input length: ${input.length} bytes`);
      }

      if (!process.env.SUPPRESS_HINTS) {
        console.error("Hint: /reload or restart Claude Code");
      }
    }
  });
}

// Export for testing
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
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
  };
}
