#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const readline = require("readline");
const os = require("os");

// Constants
const COMPACTION_THRESHOLD = 200000 * 0.8;

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
    const model = data.model?.display_name || "Unknown";
    const currentDir = path.basename(
      data.workspace?.current_dir || data.cwd || "."
    );
    const sessionId = data.session_id;

    // Calculate token usage for current session
    let totalTokens = 0;

    if (sessionId) {
      // Find all transcript files
      const projectsDir = path.join(process.env.HOME, ".claude", "projects");

      if (fs.existsSync(projectsDir)) {
        // Get all project directories
        const projectDirs = fs
          .readdirSync(projectsDir)
          .map((dir) => path.join(projectsDir, dir))
          .filter((dir) => fs.statSync(dir).isDirectory());

        // Search for the current session's transcript file
        for (const projectDir of projectDirs) {
          const transcriptFile = path.join(projectDir, `${sessionId}.jsonl`);

          if (fs.existsSync(transcriptFile)) {
            totalTokens = await calculateTokensFromTranscript(transcriptFile);
            break;
          }
        }
      }
    }

    // Calculate percentage
    const percentage = Math.min(
      100,
      Math.round((totalTokens / COMPACTION_THRESHOLD) * 100)
    );

    // Format token display
    const tokenDisplay = formatTokenCount(totalTokens);

    // Color coding for percentage
    let percentageColor = "\x1b[32m"; // Green
    if (percentage >= 70) percentageColor = "\x1b[33m"; // Yellow
    if (percentage >= 90) percentageColor = "\x1b[31m"; // Red

    // Get current directory path relative to home
    const fullPath = data.workspace?.current_dir || data.cwd || ".";
    const homePath = process.env.HOME;
    let displayPath = fullPath;
    
    if (fullPath.startsWith(homePath)) {
      displayPath = "~" + fullPath.slice(homePath.length);
    }
    
    // Get username and hostname
    const username = process.env.USER || "user";
    const hostname = os.hostname().split('.')[0]; // Short hostname

    // Get git branch
    const gitBranch = await getGitBranch(fullPath);

    // Get response counter from session
    const responseCounter = await getResponseCounter(sessionId);

    // Build CLAUDE.md format status line
    // Format: #N | 📁 directory | 🌿 branch | guidelines(lang) | skill(name)
    const claudeMdLine = `#${responseCounter} | 📁 ${currentDir} | 🌿 ${gitBranch} | guidelines(none) | skill(none)`;

    // Build shell PS1 style: username@hostname:path $ [tokens|percentage]
    const shellLine = `${username}@${hostname}:${displayPath} $ [🪙 ${tokenDisplay}|${percentageColor}${percentage}%\x1b[0m]`;

    console.log(claudeMdLine);
    console.log(shellLine);
  } catch (error) {
    // Fallback status line on error
    console.log("[Error] 📁 . | 🪙 0 | 0%");
  }
}

async function calculateTokensFromTranscript(filePath) {
  return new Promise((resolve, reject) => {
    let lastUsage = null;

    const fileStream = fs.createReadStream(filePath);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity,
    });

    rl.on("line", (line) => {
      try {
        const entry = JSON.parse(line);

        // Check if this is an assistant message with usage data
        if (entry.type === "assistant" && entry.message?.usage) {
          lastUsage = entry.message.usage;
        }
      } catch (e) {
        // Skip invalid JSON lines
      }
    });

    rl.on("close", () => {
      if (lastUsage) {
        // The last usage entry contains cumulative tokens
        const totalTokens =
          (lastUsage.input_tokens || 0) +
          (lastUsage.output_tokens || 0) +
          (lastUsage.cache_creation_input_tokens || 0) +
          (lastUsage.cache_read_input_tokens || 0);
        resolve(totalTokens);
      } else {
        resolve(0);
      }
    });

    rl.on("error", (err) => {
      reject(err);
    });
  });
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
