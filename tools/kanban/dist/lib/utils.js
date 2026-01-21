"use strict";
/**
 * ユーティリティ関数
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateUUID = generateUUID;
exports.now = now;
exports.formatDate = formatDate;
exports.readJSON = readJSON;
exports.writeJSON = writeJSON;
exports.ensureDir = ensureDir;
exports.getClaudeConfigDir = getClaudeConfigDir;
exports.getKanbanDir = getKanbanDir;
exports.getBoardDir = getBoardDir;
exports.getGlobalDir = getGlobalDir;
exports.getAgentId = getAgentId;
const crypto_1 = require("crypto");
const fs_1 = require("fs");
const path_1 = require("path");
const types_1 = require("./types");
/**
 * UUIDv4生成
 */
function generateUUID() {
    return (0, crypto_1.randomUUID)();
}
/**
 * 現在のUNIXタイムスタンプ取得
 */
function now() {
    return Math.floor(Date.now() / 1000);
}
/**
 * 日付フォーマット（YYYY-MM-DD）
 */
function formatDate(timestamp) {
    const date = new Date(timestamp * 1000);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}
/**
 * JSONファイル読み込み
 */
function readJSON(path) {
    try {
        if (!(0, fs_1.existsSync)(path)) {
            return (0, types_1.Err)({ type: 'board_not_found', board_id: path });
        }
        const content = (0, fs_1.readFileSync)(path, 'utf-8');
        const data = JSON.parse(content);
        return (0, types_1.Ok)(data);
    }
    catch (error) {
        return (0, types_1.Err)({ type: 'file_corruption', file: path });
    }
}
/**
 * JSONファイル書き込み（原子性保証）
 */
function writeJSON(path, data, pretty = false) {
    try {
        // ディレクトリが存在しない場合は作成
        const dir = (0, path_1.dirname)(path);
        if (!(0, fs_1.existsSync)(dir)) {
            (0, fs_1.mkdirSync)(dir, { recursive: true });
        }
        // 一時ファイルに書き込み
        const tmp = `${path}.tmp.${process.pid}`;
        const content = pretty ? JSON.stringify(data, null, 2) : JSON.stringify(data);
        (0, fs_1.writeFileSync)(tmp, content, 'utf-8');
        // 原子的にリネーム（POSIXではmvは原子的）
        (0, fs_1.renameSync)(tmp, path);
        return (0, types_1.Ok)(undefined);
    }
    catch (error) {
        return (0, types_1.Err)({ type: 'permission_denied', file: path });
    }
}
/**
 * ディレクトリ作成（再帰的）
 */
function ensureDir(path) {
    try {
        if (!(0, fs_1.existsSync)(path)) {
            (0, fs_1.mkdirSync)(path, { recursive: true });
        }
        return (0, types_1.Ok)(undefined);
    }
    catch (error) {
        return (0, types_1.Err)({ type: 'permission_denied', file: path });
    }
}
/**
 * 環境変数取得
 */
function getClaudeConfigDir() {
    const home = process.env.HOME ?? process.env.USERPROFILE;
    if (!home) {
        throw new Error('HOME environment variable not set');
    }
    return `${home}/.config/claude`;
}
/**
 * Kanbanディレクトリパス取得
 */
function getKanbanDir() {
    return `${getClaudeConfigDir()}/kanban`;
}
/**
 * ボードディレクトリパス取得
 */
function getBoardDir(board_id) {
    return `${getKanbanDir()}/boards/project-${board_id}`;
}
/**
 * グローバルディレクトリパス取得
 */
function getGlobalDir() {
    return `${getKanbanDir()}/boards/global`;
}
/**
 * Agent ID取得（環境変数 or プロセスID）
 */
function getAgentId() {
    return process.env.AGENT_ID ?? `claude-${process.pid}`;
}
//# sourceMappingURL=utils.js.map