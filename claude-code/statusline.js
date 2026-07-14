#!/usr/bin/env node
// @ts-check
// statusline.js - Claude Code statusline
// 表示: 46% █░░░░ │ Fable 5 H │ ◈ main*⇡1 (dir) [wt] │ +12/-3 │ $1.23
// 幅超過時は右の情報 (cost → lines → bar → suffix → dir → model) から段階的に省略

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
  brightRed: "\x1b[38;5;196m",
  reverse: "\x1b[7m",
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
 * Git状態をまとめて取得 (1回のシェル呼び出し)
 * @param {string} cwd
 * @returns {{branch: string, dirty: number, ahead: number, behind: number}}
 */
function gitInfo(cwd) {
  try {
    const { execSync } = require("child_process");
    const out = execSync(
      'b=$(git rev-parse --abbrev-ref HEAD); ' +
        "s=$(git status --porcelain 2>/dev/null | wc -l); " +
        'ab=$(git rev-list --left-right --count "@{u}...HEAD" 2>/dev/null || printf "0\\t0"); ' +
        'printf "%s\\n%s\\n%s" "$b" "$s" "$ab"',
      { cwd, encoding: "utf8", stdio: ["pipe", "pipe", "ignore"] },
    ).split("\n");
    const branch = (out[0] || "?").trim() || "?";
    const dirty = parseInt(out[1], 10) || 0;
    // rev-list --left-right --count @{u}...HEAD → "behind<TAB>ahead"
    const ab = (out[2] || "").trim().split(/\s+/);
    const behind = parseInt(ab[0], 10) || 0;
    const ahead = parseInt(ab[1], 10) || 0;
    return { branch, dirty, ahead, behind };
  } catch {
    return { branch: "?", dirty: 0, ahead: 0, behind: 0 };
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
    // marker 名は hook 側 (session-start.sh / post-tool-use.sh) と一致させる:
    // /tmp/claude-wt-<session_id>-<YYYYMMDD(ローカル)>
    const d = new Date();
    const dateToday =
      String(d.getFullYear()) +
      String(d.getMonth() + 1).padStart(2, "0") +
      String(d.getDate()).padStart(2, "0");
    try {
      const wtPath = fs
        .readFileSync(`/tmp/claude-wt-${data.session_id}-${dateToday}`, "utf8")
        .trim();
      if (wtPath && fs.existsSync(wtPath)) cwd = wtPath;
    } catch {
      // no marker
    }
  }
  const dirName = path.basename(cwd);
  const git = gitInfo(cwd);
  const wt = isWorktree(cwd);
  const rawModel = (data.model && data.model.display_name) || "?";
  const model = rawModel.replace(/^Claude\s+/i, "").replace(/\s*\(.*?\)$/, "");

  const termWidth = process.stdout.columns || 80;
  // 広い端末でも全幅まで伸ばさない (視認性優先の上限)
  const maxWidth = Math.min(termWidth, 80);
  const stripAnsi = (s) => s.replace(/\x1b\[[0-9;]*m/g, "");
  // 実端末での表示幅: 一部の記号 / 絵文字は 2 桁分として占有する
  const WIDE = /[‼-㊙\u{1F000}-\u{1FFFF}⚠⛔◈█░⇡⇣▲⑃]/u;
  const w = (s) => {
    const stripped = stripAnsi(s);
    let n = 0;
    for (const ch of stripped) n += WIDE.test(ch) ? 2 : 1;
    return n;
  };
  const trunc = (s, max) =>
    s.length > max && max > 1 ? s.slice(0, max - 1) + "…" : s;

  // effort / thinking バッジ
  const effortLevel =
    (data.effort && data.effort.level) || data.effort_level || null;
  const thinkingOn =
    (data.thinking && data.thinking.enabled === true) ||
    data.thinking_enabled === true;
  const badges = [];
  if (effortLevel === "max")
    badges.push(`${C.bold}${C.reverse}${C.red}Mx${C.R}`);
  else if (effortLevel === "xhigh")
    badges.push(`${C.bold}${C.brightRed}xH${C.R}`);
  else if (effortLevel === "high") badges.push(`${C.bold}${C.red}H${C.R}`);
  else if (effortLevel === "medium") badges.push(`${C.yellow}M${C.R}`);
  else if (effortLevel === "low") badges.push(`${C.dim}L${C.R}`);
  if (thinkingOn) badges.push(`${C.magenta}\u{1F4AD}${C.R}`);
  const badgeStr = badges.length ? ` ${badges.join(" ")}` : "";

  // コンテキスト使用率 (常に先頭 = 絶対に見切れない)
  let pctColor;
  let suffix = "";
  if (pct >= 90) {
    pctColor = C.red;
    suffix = ` ${C.bold}${C.red}⛔ /reload${C.R}`;
  } else if (pct >= 70) {
    pctColor = C.yellow;
    suffix = ` ${C.bold}${C.yellow}⚠ /compact${C.R}`;
  } else if (pct >= 50) {
    pctColor = C.yellow;
    suffix = ` ${C.dim}${C.yellow}▲${C.R}`;
  } else {
    pctColor = C.green;
  }
  const pctCore = `${pctColor}${C.bold}${pct}%${C.R}`;
  const bar = progressBar(pct, 5);

  const modelSeg = `${C.modelColor}${model}${C.R}${badgeStr}`;

  // セッション成果 (行数増減 / コスト)
  const cost = data.cost || {};
  const added = cost.total_lines_added || 0;
  const removed = cost.total_lines_removed || 0;
  const linesSeg =
    added || removed
      ? `${C.green}+${added}${C.gray}/${C.red}-${removed}${C.R}`
      : "";
  const usd = cost.total_cost_usd || 0;
  const costSeg = usd >= 0.005 ? `${C.tokenColor}$${usd.toFixed(2)}${C.R}` : "";

  // git 状態マーク: * = 未コミット変更, ⇡ n = push 待ち, ⇣ n = pull 待ち
  let markStr = "";
  if (git.dirty) markStr += `${C.yellow}*`;
  if (git.ahead) markStr += `${C.green}⇡${git.ahead}`;
  if (git.behind) markStr += `${C.red}⇣${git.behind}`;
  if (markStr) markStr += C.R;
  // worktree 標識は branch 直後に固定 (幅圧縮でも落ちない位置)
  const wtTag = wt ? `${C.yellow}⑃${C.R}` : "";

  // location部を幅に収まるよう構築 (branch 名を最優先、dir は () で補助的に付与)
  const buildLoc = (maxLen, showDir) => {
    if (git.branch === "?") {
      return `${C.cyan}◈ ${wtTag}${C.gray}${trunc(dirName, Math.max(maxLen - 2 - (wt ? 1 : 0), 2))}${C.R}`;
    }
    const dirPart = showDir ? ` ${C.dim}(${dirName})${C.R}` : "";
    const overhead = 2 + w(wtTag) + w(markStr) + w(dirPart);
    const b = trunc(git.branch, Math.max(maxLen - overhead, 2));
    return `${C.cyan}◈ ${wtTag}${C.branchColor}${b}${C.R}${markStr}${dirPart}`;
  };

  const sepStr = ` ${C.darkGray}│${C.R} `;
  const sepLen = 3; // " │ "

  const emit = (text) => console.log(text);

  // 極小端末 → pctのみ
  if (termWidth < 40) {
    emit(pctCore + suffix);
    return;
  }

  // 後ろの要素ほど先に落とす (cost → lines → bar → suffix → dir → model)
  const features = ["model", "dir", "suffix", "bar", "lines", "cost"];
  const LOC = Symbol("loc");
  for (let drop = 0; drop <= features.length; drop++) {
    const on = new Set(features.slice(0, features.length - drop));
    let pctSeg = pctCore;
    if (on.has("bar")) pctSeg += ` ${bar}`;
    if (on.has("suffix")) pctSeg += suffix;
    /** @type {any[]} */
    const segs = [pctSeg];
    if (on.has("model")) segs.push(modelSeg);
    segs.push(LOC);
    if (on.has("lines") && linesSeg) segs.push(linesSeg);
    if (on.has("cost") && costSeg) segs.push(costSeg);
    const fixed =
      segs.filter((s) => s !== LOC).reduce((a, s) => a + w(s), 0) +
      sepLen * (segs.length - 1);
    const loc = buildLoc(maxWidth - fixed, on.has("dir"));
    const text = segs.map((s) => (s === LOC ? loc : s)).join(sepStr);
    if (w(text) <= maxWidth) {
      emit(text);
      return;
    }
  }

  emit(pctCore);
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
    getGitBranch,
    gitInfo,
    isWorktree,
    progressBar,
  };
}
