"use strict";
/**
 * ロック管理
 *
 * Sub agent間のタスク衝突を回避するためのロック機構
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.acquireLock = acquireLock;
exports.releaseLock = releaseLock;
exports.checkLock = checkLock;
exports.cleanupExpiredLocks = cleanupExpiredLocks;
const fs_1 = require("fs");
const types_1 = require("./types");
const utils_1 = require("./utils");
/**
 * デフォルトロックタイムアウト（1時間）
 */
const DEFAULT_LOCK_TIMEOUT = 3600;
/**
 * ロック取得
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param agent_id エージェントID（省略時は自動取得）
 * @param timeout タイムアウト秒数（省略時は1時間）
 * @returns ロック情報 or エラー
 */
function acquireLock(board_id, task_id, agent_id, timeout = DEFAULT_LOCK_TIMEOUT) {
    // UUID検証
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    if (!(0, types_1.isValidUUID)(task_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: task_id });
    }
    const aid = agent_id ?? (0, utils_1.getAgentId)();
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const lock_file = `${board_dir}/.lock`;
    const active_file = `${board_dir}/active.json`;
    // ボードロックファイル確認（他のagentがボード全体をロック中か）
    const board_lock_result = acquireBoardLock(board_id, aid, timeout);
    if (!board_lock_result.ok) {
        return board_lock_result;
    }
    // タスクのロック状態確認
    const active_result = (0, utils_1.readJSON)(active_file);
    if (!active_result.ok) {
        releaseBoardLock(board_id);
        return (0, types_1.Err)(active_result.error);
    }
    const active = active_result.value;
    const task_index = active.t.findIndex((t) => t.i === task_id);
    if (task_index === -1) {
        releaseBoardLock(board_id);
        return (0, types_1.Err)({ type: 'task_not_found', task_id });
    }
    const task = active.t[task_index];
    // 既存ロック確認
    if (task.l) {
        const current_time = (0, utils_1.now)();
        if (task.l.e > current_time) {
            // ロック有効期限内
            if (task.l.a !== aid) {
                // 他のagentがロック中
                releaseBoardLock(board_id);
                return (0, types_1.Err)({
                    type: 'task_locked',
                    locked_by: task.l.a,
                    expires_at: task.l.e
                });
            }
            // 自分自身がロック中（再取得）
            return (0, types_1.Ok)(task.l);
        }
        // ロック期限切れ → 自動解放して新規取得
    }
    // ロック設定
    const lock = {
        a: aid,
        t: (0, utils_1.now)(),
        e: (0, utils_1.now)() + timeout
    };
    task.l = lock;
    active.u = (0, utils_1.now)();
    // 書き込み
    const write_result = (0, utils_1.writeJSON)(active_file, active);
    releaseBoardLock(board_id);
    if (!write_result.ok) {
        return (0, types_1.Err)(write_result.error);
    }
    return (0, types_1.Ok)(lock);
}
/**
 * ロック解放
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param agent_id エージェントID（省略時は自動取得）
 * @returns 成功 or エラー
 */
function releaseLock(board_id, task_id, agent_id) {
    // UUID検証
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    if (!(0, types_1.isValidUUID)(task_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: task_id });
    }
    const aid = agent_id ?? (0, utils_1.getAgentId)();
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const active_file = `${board_dir}/active.json`;
    // ボードロック取得
    const board_lock_result = acquireBoardLock(board_id, aid);
    if (!board_lock_result.ok) {
        return (0, types_1.Err)(board_lock_result.error);
    }
    // タスク読み込み
    const active_result = (0, utils_1.readJSON)(active_file);
    if (!active_result.ok) {
        releaseBoardLock(board_id);
        return (0, types_1.Err)(active_result.error);
    }
    const active = active_result.value;
    const task_index = active.t.findIndex((t) => t.i === task_id);
    if (task_index === -1) {
        releaseBoardLock(board_id);
        return (0, types_1.Err)({ type: 'task_not_found', task_id });
    }
    const task = active.t[task_index];
    // ロック削除
    delete task.l;
    active.u = (0, utils_1.now)();
    // 書き込み
    const write_result = (0, utils_1.writeJSON)(active_file, active);
    releaseBoardLock(board_id);
    return write_result;
}
/**
 * ロック状態確認
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns ロック情報（ロックされていない場合はnull）
 */
function checkLock(board_id, task_id) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    if (!(0, types_1.isValidUUID)(task_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: task_id });
    }
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const active_file = `${board_dir}/active.json`;
    const active_result = (0, utils_1.readJSON)(active_file);
    if (!active_result.ok) {
        return (0, types_1.Err)(active_result.error);
    }
    const active = active_result.value;
    const task = active.t.find((t) => t.i === task_id);
    if (!task) {
        return (0, types_1.Err)({ type: 'task_not_found', task_id });
    }
    // 期限切れロックは無効扱い
    if (task.l && task.l.e > (0, utils_1.now)()) {
        return (0, types_1.Ok)(task.l);
    }
    return (0, types_1.Ok)(null);
}
/**
 * ボードロック取得（内部用）
 *
 * active.jsonの読み書き時に使用
 */
function acquireBoardLock(board_id, agent_id, timeout = DEFAULT_LOCK_TIMEOUT) {
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const lock_file = `${board_dir}/.lock`;
    // ロックファイル確認
    if ((0, fs_1.existsSync)(lock_file)) {
        try {
            const content = (0, fs_1.readFileSync)(lock_file, 'utf-8');
            const lock = JSON.parse(content);
            // 期限確認
            if (lock.expires_at > (0, utils_1.now)()) {
                // 有効期限内
                if (lock.locked_by !== agent_id) {
                    // 他のagentがロック中
                    return (0, types_1.Err)({
                        type: 'task_locked',
                        locked_by: lock.locked_by,
                        expires_at: lock.expires_at
                    });
                }
                // 自分自身がロック中（再取得）
                return (0, types_1.Ok)(undefined);
            }
            // 期限切れ → 削除して新規取得
            (0, fs_1.unlinkSync)(lock_file);
        }
        catch {
            // ロックファイル破損 → 削除して新規取得
            (0, fs_1.unlinkSync)(lock_file);
        }
    }
    // ロックファイル作成
    const lock = {
        board_id,
        locked_by: agent_id,
        locked_at: (0, utils_1.now)(),
        expires_at: (0, utils_1.now)() + timeout
    };
    try {
        (0, fs_1.writeFileSync)(lock_file, JSON.stringify(lock), 'utf-8');
        return (0, types_1.Ok)(undefined);
    }
    catch {
        return (0, types_1.Err)({ type: 'permission_denied', file: lock_file });
    }
}
/**
 * ボードロック解放（内部用）
 */
function releaseBoardLock(board_id) {
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const lock_file = `${board_dir}/.lock`;
    if ((0, fs_1.existsSync)(lock_file)) {
        try {
            (0, fs_1.unlinkSync)(lock_file);
        }
        catch {
            // 削除失敗は無視（タイムアウトで自動解放される）
        }
    }
}
/**
 * 期限切れロック一括解放
 *
 * @param board_id ボードID
 * @returns 解放したタスク数
 */
function cleanupExpiredLocks(board_id) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const active_file = `${board_dir}/active.json`;
    const agent_id = (0, utils_1.getAgentId)();
    // ボードロック取得
    const board_lock_result = acquireBoardLock(board_id, agent_id);
    if (!board_lock_result.ok) {
        return (0, types_1.Err)(board_lock_result.error);
    }
    const active_result = (0, utils_1.readJSON)(active_file);
    if (!active_result.ok) {
        releaseBoardLock(board_id);
        return (0, types_1.Err)(active_result.error);
    }
    const active = active_result.value;
    const current_time = (0, utils_1.now)();
    let cleaned = 0;
    for (const task of active.t) {
        if (task.l && task.l.e <= current_time) {
            delete task.l;
            cleaned++;
        }
    }
    if (cleaned > 0) {
        active.u = (0, utils_1.now)();
        const write_result = (0, utils_1.writeJSON)(active_file, active);
        releaseBoardLock(board_id);
        if (!write_result.ok) {
            return (0, types_1.Err)(write_result.error);
        }
    }
    else {
        releaseBoardLock(board_id);
    }
    return (0, types_1.Ok)(cleaned);
}
//# sourceMappingURL=lock-manager.js.map