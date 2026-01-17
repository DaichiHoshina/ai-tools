#!/usr/bin/env node
// statusline.js - Claude Code 2.1.6+ 対応版（legacy fallback削除）

const fs = require("fs");
const path = require("path");
const os = require("os");

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
  try {
    // Extract values
    const currentDir = path.basename(
      data.workspace?.current_dir || data.cwd || ".",
    );
    const sessionId = data.session_id;

    // Use context_window data (Claude Code 2.1.6+ required)
    const contextWindow = data.context_window || {};
    let percentage = 0;
    let totalTokens = 0;

    if (contextWindow.used_percentage !== undefined) {
      percentage = Math.round(contextWindow.used_percentage);
      // v2.1.6+: remaining_percentage も利用可能
      const remainingPercentage = contextWindow.remaining_percentage !== undefined
        ? Math.round(contextWindow.remaining_percentage)
        : 100 - percentage;

      // Calculate approximate total tokens from percentage
      if (contextWindow.total !== undefined && percentage > 0) {
        totalTokens = Math.round((contextWindow.total * percentage) / 100);
      }
    }
    // Note: Legacy fallback removed - Claude Code 2.1.6+ required

    // Format token display
    const tokenDisplay = formatTokenCount(totalTokens);

    // Color coding for percentage (v2.1.6+: remaining_percentage aware)
    let percentageColor = "\x1b[32m"; // Green (remaining > 30%)
    let contextWarning = "";
    if (percentage >= 70) {
      percentageColor = "\x1b[33m"; // Yellow (remaining 30-10%)
      contextWarning = " ⚠️";
    }
    if (percentage >= 90) {
      percentageColor = "\x1b[31m"; // Red (remaining < 10%)
      contextWarning = " 🔴/reload";
    }

    // Get current directory path relative to home
    const fullPath = data.workspace?.current_dir || data.cwd || ".";
    const homePath = process.env.HOME;
    let displayPath = fullPath;

    if (fullPath.startsWith(homePath)) {
      displayPath = "~" + fullPath.slice(homePath.length);
    }

    // Get username and hostname
    const username = process.env.USER || "user";
    const hostname = os.hostname().split(".")[0]; // Short hostname

    // Get git branch
    const gitBranch = await getGitBranch(fullPath);

    // Get response counter from session
    const responseCounter = await getResponseCounter(sessionId);

    // Build CLAUDE.md format status line
    // Format: #N | 📁 directory | 🌿 branch | guidelines(lang) | skill(name)
    const claudeMdLine = `#${responseCounter} | 📁 ${currentDir} | 🌿 ${gitBranch} | guidelines(none) | skill(none)`;

    // Build shell PS1 style: username@hostname:path $ [tokens|percentage|warning]
    const shellLine = `${username}@${hostname}:${displayPath} $ [🪙 ${tokenDisplay}|${percentageColor}${percentage}%\x1b[0m${contextWarning}]`;

    console.log(claudeMdLine);
    console.log(shellLine);
  } catch (error) {
    // Fallback status line on error
    console.log("[Error] 📁 . | 🪙 0 | 0%");
  }
}

function formatTokenCount(tokens) {
  if (tokens >= 1000000) {
    return `${(tokens / 1000000).toFixed(1)}M`;
  } else if (tokens >= 1000) {
    return `${(tokens / 1000).toFixed(1)}K`;
  }
  return tokens.toString();
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

    // Find transcript file for session
    const projectsDir = path.join(process.env.HOME, ".claude", "projects");
    if (!fs.existsSync(projectsDir)) return 1;

    const projectDirs = fs
      .readdirSync(projectsDir)
      .map((dir) => path.join(projectsDir, dir))
      .filter((dir) => fs.statSync(dir).isDirectory());

    for (const projectDir of projectDirs) {
      const transcriptFile = path.join(projectDir, `${sessionId}.jsonl`);

      if (fs.existsSync(transcriptFile)) {
        // Count assistant messages in transcript
        const content = fs.readFileSync(transcriptFile, "utf8");
        const lines = content.trim().split("\n");
        let assistantCount = 0;

        for (const line of lines) {
          try {
            const entry = JSON.parse(line);
            if (entry.type === "assistant") {
              assistantCount++;
            }
          } catch (e) {
            // Skip invalid JSON lines
          }
        }

        // Next response counter is assistantCount + 1
        return assistantCount + 1;
      }
    }

    return 1;
  } catch (error) {
    return 1;
  }
}
