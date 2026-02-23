#!/usr/bin/env node
// @ts-check
// statusline.js - Claude Code statusline
// 表示: dir:branch | #turn | tokens | context%

const fs = require("fs");
const path = require("path");

/** @type {Record<string, {color: string, icon: string, threshold: number}>} */
const STATES = {
  normal: { color: "\x1b[32m", icon: "\u25CB", threshold: 0 },
  warning: { color: "\x1b[33m", icon: "\u25B2", threshold: 70 },
  critical: { color: "\x1b[31m", icon: "\u2715", threshold: 90 },
};

/**
 * transcriptファイルからユーザーメッセージ数をカウント
 * @param {string} transcriptPath
 * @returns {number}
 */
function countUserMessages(transcriptPath) {
  try {
    if (!fs.existsSync(transcriptPath)) return 0;
    const content = fs.readFileSync(transcriptPath, "utf8");
    const lines = content.trim().split("\n");
    let count = 0;
    for (const line of lines) {
      try {
        if (JSON.parse(line).type === "user") count++;
      } catch {
        // skip invalid lines
      }
    }
    return count;
  } catch {
    return 0;
  }
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
  const percentage = Math.round(ctx.used_percentage || 0);
  const tokens = (
    (ctx.total_input_tokens || 0) + (ctx.total_output_tokens || 0)
  ).toLocaleString();

  const state =
    percentage >= STATES.critical.threshold
      ? STATES.critical
      : percentage >= STATES.warning.threshold
        ? STATES.warning
        : STATES.normal;

  const warning =
    state === STATES.critical
      ? ` ${state.icon} /reload`
      : state === STATES.warning
        ? ` ${state.icon} Warning`
        : "";

  const cwd = data.cwd || process.cwd();
  const dirName = path.basename(cwd);
  const branch = getGitBranch(cwd);
  const turn = data.transcript_path
    ? countUserMessages(data.transcript_path)
    : 0;

  const R = "\x1b[0m";
  const D = "\x1b[90m";
  const termWidth = process.stdout.columns || 80;

  let text;
  if (termWidth < 60) {
    text = `${state.color}${percentage}%${R}${warning ? " " + state.icon : ""}`;
  } else {
    text = `${D}${dirName}:${branch}${R} ${D}|${R} #${turn} ${D}|${R} ${tokens} ${D}|${R} ${state.color}${percentage}%${R}${warning}`;
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
  module.exports = {
    displayStatusLine,
    countUserMessages,
    getGitBranch,
    STATES,
  };
}
