#!/usr/bin/env node
// statusline.js - Claude Code 2.1.6+ 対応版（P2改善: キャッシュ＆フォールバック強化）

const fs = require("fs");
const path = require("path");
const os = require("os");

// キャッシュ設定（5秒TTL）
const CACHE_TTL_MS = 5000;
let cache = {
  userCount: { value: 0, timestamp: 0, sessionId: null },
};

// Material Design 3 準拠: 8状態定義（色覚障害対応: 色+シンボル併用）
const STATUS_STATES = {
  normal: { color: "\x1b[32m", icon: "◯", label: "Ready", threshold: 0 },
  info: { color: "\x1b[34m", icon: "ℹ", label: "Info", threshold: 0 },
  success: { color: "\x1b[32m", icon: "✓", label: "Success", threshold: 0 },
  warning: { color: "\x1b[33m", icon: "▲", label: "Warning", threshold: 70 },
  critical: { color: "\x1b[31m", icon: "✕", label: "Critical", threshold: 90 },
  error: { color: "\x1b[31m", icon: "❌", label: "Error", threshold: 0 },
  loading: { color: "\x1b[36m", icon: "⏳", label: "Loading", threshold: 0 },
  disabled: { color: "\x1b[90m", icon: "⊗", label: "Disabled", threshold: 0 },
};

// ANSI Reset
const RESET = "\x1b[0m";

// 状態判定関数
function getStatusState(percentage) {
  if (percentage >= STATUS_STATES.critical.threshold) {
    return STATUS_STATES.critical;
  } else if (percentage >= STATUS_STATES.warning.threshold) {
    return STATUS_STATES.warning;
  }
  return STATUS_STATES.normal;
}

// Read JSON from stdin
let input = "";
process.stdin.on("data", (chunk) => (input += chunk));
process.stdin.on("end", async () => {
  try {
    const data = JSON.parse(input);
    await displayStatusLine(data);
  } catch (error) {
    // 3段階エラーハンドリング（Critical #3対策）

    // Level 1: ユーザーフレンドリーなメッセージ（stdout）
    console.log("[Status Unavailable]");

    // Level 2: デバッグ情報（stderr、DEBUG_STATUSLINE環境変数時）
    if (process.env.DEBUG_STATUSLINE) {
      console.error(`[DEBUG] Error: ${error.message}`);
      console.error(`[DEBUG] Stack: ${error.stack}`);
      console.error(`[DEBUG] Input length: ${input.length} bytes`);
    }

    // Level 3: 復旧ステップ提案（SUPPRESS_HINTS未設定時）
    if (!process.env.SUPPRESS_HINTS) {
      console.error("💡 復旧方法:");
      console.error("  1. /reload を実行");
      console.error("  2. ~/.claude/sync.sh from-local で更新");
      console.error("  3. Claude Code を再起動");
    }
  }
});

async function displayStatusLine(data) {
  // 部分的な情報でも表示できるようにフォールバック値を設定
  let tokenDisplay = "0";
  let percentage = 0;
  let percentageColor = "\x1b[32m";
  let contextWarning = "";

  try {
    // Use context_window data (Claude Code 2.1.6+ required)
    const contextWindow = data.context_window || {};

    if (contextWindow.used_percentage !== undefined) {
      percentage = Math.round(contextWindow.used_percentage);

      // トークン計算: total_input_tokens + total_output_tokens を使用
      const inputTokens = contextWindow.total_input_tokens || 0;
      const outputTokens = contextWindow.total_output_tokens || 0;
      const totalTokens = inputTokens + outputTokens;
      tokenDisplay = formatTokenCount(totalTokens);
    }
  } catch (e) {
    // トークン取得失敗時はデフォルト値を使用
  }

  try {
    // Material Design 3: 状態判定（色+シンボル併用で色覚障害対応）
    const state = getStatusState(percentage);
    percentageColor = state.color;

    // シンボルと警告メッセージを状態に応じて設定
    let stateIcon = state.icon;
    if (state === STATUS_STATES.warning) {
      contextWarning = ` ${stateIcon} Warning`;
    } else if (state === STATUS_STATES.critical) {
      contextWarning = ` ${stateIcon} /reload`;
    }

    // 右寄せ表示（ターミナル幅に合わせてパディング）
    // レスポンシブ対応: 幅60未満の場合はコンパクト表示
    const termWidth = process.stdout.columns || 80;
    let statusText;

    if (termWidth < 60) {
      // コンパクト表示（小画面対応）
      statusText = `${percentage}%${contextWarning ? " " + stateIcon : ""}`;
    } else {
      // 通常表示
      statusText = `${tokenDisplay} | ${percentage}%${contextWarning}`;
    }

    const visibleLength = statusText.replace(/\x1b\[[0-9;]*m/g, "").length;
    const padding = Math.max(0, termWidth - visibleLength - 2);
    console.log(
      `${" ".repeat(padding)}${tokenDisplay} | ${percentageColor}${percentage}%\x1b[0m${contextWarning}`,
    );
  } catch (error) {
    // 最終フォールバック
    console.log(`${tokenDisplay} | ${percentage}%`);
  }
}

function getCurrentSkill() {
  try {
    const stateFile = path.join(
      process.env.HOME,
      ".claude",
      "state",
      "current-skill.txt",
    );
    if (fs.existsSync(stateFile)) {
      const skill = fs.readFileSync(stateFile, "utf8").trim();
      return skill || "none";
    }
    return "none";
  } catch (error) {
    return "none";
  }
}

function formatTokenCount(tokens) {
  return tokens.toLocaleString();
}

async function getGitBranch(cwd) {
  try {
    const { execSync } = require("child_process");
    const branch = execSync("git rev-parse --abbrev-ref HEAD", {
      cwd,
      encoding: "utf8",
      stdio: ["pipe", "pipe", "ignore"],
    }).trim();
    return branch || "unknown";
  } catch (error) {
    return "unknown";
  }
}

async function getResponseCounter(sessionId) {
  try {
    if (!sessionId) return 1;

    // キャッシュチェック（5秒TTL）
    const now = Date.now();
    if (
      cache.userCount.sessionId === sessionId &&
      now - cache.userCount.timestamp < CACHE_TTL_MS
    ) {
      return cache.userCount.value;
    }

    const stateFile = path.join(
      process.env.HOME,
      ".claude",
      "state",
      "session-counter.json",
    );
    const stateDir = path.dirname(stateFile);

    // Ensure state directory exists
    if (!fs.existsSync(stateDir)) {
      fs.mkdirSync(stateDir, { recursive: true });
    }

    // Get total user message count from transcript
    const totalCount = await getTotalUserCount(sessionId);

    // Read or initialize state
    let state = { sessionId: null, startCount: 0 };
    if (fs.existsSync(stateFile)) {
      try {
        state = JSON.parse(fs.readFileSync(stateFile, "utf8"));
      } catch (e) {
        // Invalid state file, reset
      }
    }

    // If session changed, reset counter
    if (state.sessionId !== sessionId) {
      state = { sessionId, startCount: totalCount };
      fs.writeFileSync(stateFile, JSON.stringify(state));
    }

    // Return counter relative to session start (1-based)
    const counter = Math.max(1, totalCount - state.startCount + 1);

    // キャッシュ更新
    cache.userCount = { value: counter, timestamp: now, sessionId };

    return counter;
  } catch (error) {
    return 1;
  }
}

async function getTotalUserCount(sessionId) {
  try {
    const projectsDir = path.join(process.env.HOME, ".claude", "projects");
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

        // 最後のsummaryエントリ（compact結果）の位置を探す
        let lastSummaryIndex = -1;
        for (let i = lines.length - 1; i >= 0; i--) {
          try {
            const entry = JSON.parse(lines[i]);
            if (entry.type === "summary") {
              lastSummaryIndex = i;
              break;
            }
          } catch (e) {
            // Skip invalid JSON lines
          }
        }

        // summary以降のユーザーメッセージのみカウント
        let count = 0;
        const startIndex = lastSummaryIndex + 1;
        for (let i = startIndex; i < lines.length; i++) {
          try {
            const entry = JSON.parse(lines[i]);
            if (entry.type === "user") {
              count++;
            }
          } catch (e) {
            // Skip invalid JSON lines
          }
        }
        return count;
      }
    }
    return 0;
  } catch (error) {
    return 0;
  }
}
