#!/usr/bin/env node
// @ts-check
// statusline.js - Claude Code statusline
// 表示: ◈ dir:branch │ Opus 4.6 │ [████░░] 34%

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
 * @param {any} data - Claude Codeから渡されるJSON
 */
function displayStatusLine(data) {
  const ctx = data.context_window || {};
  const pct = Math.round(ctx.used_percentage || 0);
  const cwd = data.cwd || process.cwd();
  const dirName = path.basename(cwd);
  const branch = getGitBranch(cwd);
  const rawModel = (data.model && data.model.display_name) || "?";
  const model = rawModel.replace(/^Claude\s+/i, "");

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

  let text;
  if (termWidth < 60) {
    text = `${pctColor}${pct}%${C.R}${suffix}`;
  } else {
    const barWidth = termWidth >= 120 ? 10 : 6;
    const bar = progressBar(pct, barWidth);
    text = [
      `${C.cyan}\u25C8 ${dirName}${C.gray}:${C.branchColor}${branch}${C.R}`,
      `${C.modelColor}${model}${C.R}`,
      `${bar} ${pctColor}${C.bold}${pct}%${C.R}${suffix}`,
    ].join(` ${sep} `);
  }

  const visibleLen = text.replace(/\x1b\[[0-9;]*m/g, "").length;
  const pad = Math.max(0, termWidth - visibleLen);
  console.log(" ".repeat(pad) + text);
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
  module.exports = { displayStatusLine, getGitBranch, progressBar };
}
