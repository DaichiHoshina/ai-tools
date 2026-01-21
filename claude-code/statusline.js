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

// Read JSON from stdin
let input = "";
process.stdin.on("data", (chunk) => (input += chunk));
process.stdin.on("end", async () => {
  try {
    const data = JSON.parse(input);
    await displayStatusLine(data);
  } catch (error) {
    // Fallback status line on error
    console.log("[Error] 📁 . | 🪙 0 | 0%");
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
    // Color coding for percentage (v2.1.6+: remaining_percentage aware)
    if (percentage >= 70) {
      percentageColor = "\x1b[33m"; // Yellow (remaining 30-10%)
      contextWarning = " ⚠️";
    }
    if (percentage >= 90) {
      percentageColor = "\x1b[31m"; // Red (remaining < 10%)
      contextWarning = " 🔴/reload";
    }

    // 右寄せ表示（ターミナル幅に合わせてパディング）
    const statusText = `${tokenDisplay} | ${percentage}%${contextWarning}`;
    const termWidth = process.stdout.columns || 80;
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
    const stateFile = path.join(process.env.HOME, ".claude", "state", "current-skill.txt");
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
