#!/usr/bin/env node
// @ts-check
// statusline.js - Claude Code statusline
// 表示: ◈ dir:branch [wt] │ Opus 4.6 │ 34%  (幅超過時は2行分割)

const path = require("path");

// ANSI 256color
const C = {
  R: "\x1b[0m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
  cyan: "\x1b[36m",
  magenta: "\x1b[35m",
  white: "\x1b[97m",
  green: "\x1b[38;5;114m",
  yellow: "\x1b[38;5;221m",
  red: "\x1b[38;5;203m",
  gray: "\x1b[38;5;243m",
  darkGray: "\x1b[38;5;238m",
  branchColor: "\x1b[38;5;75m",
  modelColor: "\x1b[38;5;177m",
  tokenColor: "\x1b[38;5;252m",
};

/**
 * プログレスバーを生成
 * @param {number} pct - 0-100
 * @param {number} width - バー幅
 * @returns {string}
 */
function progressBar(pct, width) {
  const filled = Math.round((pct / 100) * width);
  const empty = width - filled;
  const filledChar = "\u2588"; // █
  const emptyChar = "\u2591"; // ░

  let barColor;
  if (pct >= 90) barColor = C.red;
  else if (pct >= 70) barColor = C.yellow;
  else barColor = C.green;

  return `${barColor}${filledChar.repeat(filled)}${C.darkGray}${emptyChar.repeat(empty)}${C.R}`;
}

/**
 * Gitブランチ名を取得
 * @param {string} cwd
 * @returns {string}
 */
function getGitBranch(cwd) {
  try {
    const { execSync } = require("child_process");
    return (
      execSync("git rev-parse --abbrev-ref HEAD", {
        cwd,
        encoding: "utf8",
        stdio: ["pipe", "pipe", "ignore"],
      }).trim() || "?"
    );
  } catch {
    return "?";
  }
}

/**
 * ワークツリー内かどうか判定
 * @param {string} cwd
 * @returns {boolean}
 */
function isWorktree(cwd) {
  try {
    const { execSync } = require("child_process");
    const opts = { cwd, encoding: "utf8", stdio: ["pipe", "pipe", "ignore"] };
    // 1回のシェル呼び出しで両方取得
    const out = execSync(
      'echo "$(git rev-parse --git-dir)\n$(git rev-parse --git-common-dir)"',
      opts,
    ).trim();
    const [gitDir, commonDir] = out.split("\n");
    return path.resolve(cwd, gitDir) !== path.resolve(cwd, commonDir);
  } catch {
    return false;
  }
}

/**
 * @param {any} data - Claude Codeから渡されるJSON
 */
function displayStatusLine(data) {
  const ctx = data.context_window || {};
  const pct = Math.round(ctx.used_percentage || 0);

  // コンテキスト使用率を一時ファイルに書き出し（auto-compact用）
  try {
    require("fs").writeFileSync("/tmp/claude-ctx-pct", String(pct));
  } catch {
    // ignore
  }
  const fs = require("fs");
  const launchCwd = data.cwd || process.cwd();
  // マーカーファイルから実作業ディレクトリを取得
  let cwd = launchCwd;
  if (data.session_id) {
    try {
      const wtPath = fs
        .readFileSync(`/tmp/claude-wt-${data.session_id}`, "utf8")
        .trim();
      if (wtPath && fs.existsSync(wtPath)) cwd = wtPath;
    } catch {
      // no marker
    }
  }
  const dirName = path.basename(cwd);
  const branch = getGitBranch(cwd);
  const rawModel = (data.model && data.model.display_name) || "?";
  const model = rawModel.replace(/^Claude\s+/i, "").replace(/\s*\(.*?\)$/, "");

  const sep = `${C.darkGray}\u2502${C.R}`;
  const termWidth = process.stdout.columns || 80;

  let pctColor;
  let suffix = "";
  if (pct >= 90) {
    pctColor = C.red;
    suffix = ` ${C.bold}${C.red}\u26D4 /reload${C.R}`;
  } else if (pct >= 70) {
    pctColor = C.yellow;
    suffix = ` ${C.bold}${C.yellow}\u26A0 /compact${C.R}`;
  } else if (pct >= 50) {
    pctColor = C.yellow;
    suffix = ` ${C.dim}${C.yellow}\u25B2${C.R}`;
  } else {
    pctColor = C.green;
  }

  const stripAnsi = (s) => s.replace(/\x1b\[[0-9;]*m/g, "");
  const wt = isWorktree(cwd);
  const wtTag = wt ? ` ${C.yellow}[wt]` : "";
  const modelPart = `${C.modelColor}${model}${C.R}`;
  const pctPart = `${pctColor}${C.bold}${pct}%${C.R}${suffix}`;

  if (termWidth < 60) {
    const pad = Math.max(0, termWidth - stripAnsi(pctPart).length);
    console.log(" ".repeat(pad) + pctPart);
  } else {
    // 固定部分の長さを計算（"◈ " + ":" + wtTag + " │ model │ pct suffix"）
    const fixedLen =
      2 +
      1 +
      (wt ? 5 : 0) +
      3 +
      stripAnsi(modelPart).length +
      3 +
      stripAnsi(pctPart).length;
    const maxLocLen = termWidth - fixedLen;

    let d = dirName;
    let b = branch;
    if (d.length + b.length > maxLocLen && maxLocLen > 0) {
      // branchを優先的に残し、dirNameを切り詰め
      const minDir = 3; // "xx…" 最小
      const bMax = Math.min(b.length, maxLocLen - minDir);
      const dMax = maxLocLen - bMax;
      if (dMax < d.length) d = d.slice(0, Math.max(dMax - 1, 1)) + "\u2026";
      if (bMax < b.length) b = b.slice(0, Math.max(bMax - 1, 1)) + "\u2026";
    }

    const locPart = `${C.cyan}\u25C8 ${d}${C.gray}:${C.branchColor}${b}${wtTag}${C.R}`;
    const text = [locPart, modelPart, pctPart].join(` ${sep} `);
    const pad = Math.max(0, termWidth - stripAnsi(text).length);
    console.log(" ".repeat(pad) + text);
  }
}

if (require.main === module) {
  let input = "";
  process.stdin.on("data", (chunk) => (input += chunk));
  process.stdin.on("end", () => {
    try {
      displayStatusLine(JSON.parse(input));
    } catch {
      console.log("[Status Unavailable]");
    }
  });
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = { displayStatusLine, getGitBranch, isWorktree, progressBar };
}
