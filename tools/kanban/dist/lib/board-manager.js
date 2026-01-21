"use strict";
/**
 * ボード管理
 *
 * Kanbanボードの作成・読み込み・更新
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.initBoard = initBoard;
exports.addTask = addTask;
exports.getTask = getTask;
exports.listTasks = listTasks;
exports.updateTaskStatus = updateTaskStatus;
exports.updateTask = updateTask;
exports.getBoardInfo = getBoardInfo;
exports.listBoards = listBoards;
exports.findBoardByProject = findBoardByProject;
exports.getBoardStatus = getBoardStatus;
exports.getNextTask = getNextTask;
exports.splitTask = splitTask;
exports.getBoardProgress = getBoardProgress;
exports.blockTask = blockTask;
exports.unblockTask = unblockTask;
const fs_1 = require("fs");
const types_1 = require("./types");
const utils_1 = require("./utils");
const lock_manager_1 = require("./lock-manager");
const archive_manager_1 = require("./archive-manager");
/**
 * ボード初期化
 *
 * @param name ボード名
 * @param project_path プロジェクトパス
 * @returns ボードID or エラー
 */
function initBoard(name, project_path) {
    const board_id = (0, utils_1.generateUUID)();
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    // ディレクトリ作成
    const ensure_result = (0, utils_1.ensureDir)(board_dir);
    if (!ensure_result.ok) {
        return (0, types_1.Err)(ensure_result.error);
    }
    const ensure_archive_result = (0, utils_1.ensureDir)(`${board_dir}/archive`);
    if (!ensure_archive_result.ok) {
        return (0, types_1.Err)(ensure_archive_result.error);
    }
    // 設定ファイル作成
    const config = {
        id: board_id,
        name,
        project_path,
        created_at: (0, utils_1.now)(),
        updated_at: (0, utils_1.now)(),
        wip_limit: {
            in_progress: 1
        },
        archive_after_days: 7
    };
    const config_result = (0, utils_1.writeJSON)(`${board_dir}/config.json`, config, true);
    if (!config_result.ok) {
        return (0, types_1.Err)(config_result.error);
    }
    // アクティブボード初期化
    const active = {
        v: '1.0.0',
        b: board_id,
        t: [],
        u: (0, utils_1.now)()
    };
    const active_result = (0, utils_1.writeJSON)(`${board_dir}/active.json`, active);
    if (!active_result.ok) {
        return (0, types_1.Err)(active_result.error);
    }
    // グローバルインデックスに登録
    const register_result = registerBoard(board_id, name, project_path);
    if (!register_result.ok) {
        return (0, types_1.Err)(register_result.error);
    }
    return (0, types_1.Ok)(board_id);
}
/**
 * タスク追加
 *
 * @param board_id ボードID
 * @param title タスクタイトル
 * @param options オプション
 * @returns タスクID or エラー
 */
function addTask(board_id, title, options) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const active_file = `${board_dir}/active.json`;
    // アクティブボード読み込み
    const active_result = (0, utils_1.readJSON)(active_file);
    if (!active_result.ok) {
        return (0, types_1.Err)(active_result.error);
    }
    const active = active_result.value;
    const task_id = (0, utils_1.generateUUID)();
    // タスク作成
    const task = {
        i: task_id,
        t: title,
        d: options?.description,
        s: options?.status ?? 'backlog',
        p: options?.priority ?? 'medium',
        c: (0, utils_1.now)(),
        u: (0, utils_1.now)()
    };
    // タスク追加
    active.t.push(task);
    active.u = (0, utils_1.now)();
    // 書き込み
    const write_result = (0, utils_1.writeJSON)(active_file, active);
    if (!write_result.ok) {
        return (0, types_1.Err)(write_result.error);
    }
    return (0, types_1.Ok)(task_id);
}
/**
 * タスク取得
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns タスク or エラー
 */
function getTask(board_id, task_id) {
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
    const task = active_result.value.t.find((t) => t.i === task_id);
    if (!task) {
        return (0, types_1.Err)({ type: 'task_not_found', task_id });
    }
    return (0, types_1.Ok)(task);
}
/**
 * タスク一覧取得
 *
 * @param board_id ボードID
 * @param filter フィルタ
 * @returns タスク一覧 or エラー
 */
function listTasks(board_id, filter) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const active_file = `${board_dir}/active.json`;
    const active_result = (0, utils_1.readJSON)(active_file);
    if (!active_result.ok) {
        return (0, types_1.Err)(active_result.error);
    }
    let tasks = active_result.value.t;
    // フィルタ適用
    if (filter?.status) {
        tasks = tasks.filter((t) => t.s === filter.status);
    }
    if (filter?.priority) {
        tasks = tasks.filter((t) => t.p === filter.priority);
    }
    return (0, types_1.Ok)(tasks);
}
/**
 * タスクステータス更新
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param new_status 新しいステータス
 * @param agent_id エージェントID（省略時は自動取得）
 * @returns 成功 or エラー
 */
function updateTaskStatus(board_id, task_id, new_status, agent_id) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    if (!(0, types_1.isValidUUID)(task_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: task_id });
    }
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const config_file = `${board_dir}/config.json`;
    const active_file = `${board_dir}/active.json`;
    // 設定読み込み
    const config_result = (0, utils_1.readJSON)(config_file);
    if (!config_result.ok) {
        return (0, types_1.Err)(config_result.error);
    }
    const config = config_result.value;
    // アクティブボード読み込み
    const active_result = (0, utils_1.readJSON)(active_file);
    if (!active_result.ok) {
        return (0, types_1.Err)(active_result.error);
    }
    const active = active_result.value;
    const task_index = active.t.findIndex((t) => t.i === task_id);
    if (task_index === -1) {
        return (0, types_1.Err)({ type: 'task_not_found', task_id });
    }
    const task = active.t[task_index];
    // ステータス遷移検証
    if (!(0, types_1.isValidTransition)(task.s, new_status)) {
        return (0, types_1.Err)({
            type: 'invalid_transition',
            from: task.s,
            to: new_status
        });
    }
    // WIP制限チェック（In Progressに移動する場合）
    if (new_status === 'in_progress') {
        const in_progress_count = active.t.filter((t) => t.s === 'in_progress').length;
        if (in_progress_count >= config.wip_limit.in_progress) {
            return (0, types_1.Err)({
                type: 'wip_limit_exceeded',
                limit: config.wip_limit.in_progress,
                current: in_progress_count
            });
        }
    }
    // ステータス更新
    task.s = new_status;
    task.u = (0, utils_1.now)();
    // In Progressに移動する場合はロック取得
    if (new_status === 'in_progress') {
        const lock_result = (0, lock_manager_1.acquireLock)(board_id, task_id, agent_id);
        if (!lock_result.ok) {
            return (0, types_1.Err)(lock_result.error);
        }
        task.l = lock_result.value;
    }
    // Doneに移動する場合はロック解放
    if (new_status === 'done' && task.l) {
        const unlock_result = (0, lock_manager_1.releaseLock)(board_id, task_id, agent_id);
        if (!unlock_result.ok) {
            return (0, types_1.Err)(unlock_result.error);
        }
        delete task.l;
    }
    active.u = (0, utils_1.now)();
    // 書き込み
    const write_result = (0, utils_1.writeJSON)(active_file, active);
    if (!write_result.ok) {
        return (0, types_1.Err)(write_result.error);
    }
    // 自動アーカイブ実行
    (0, archive_manager_1.autoArchive)(board_id);
    return (0, types_1.Ok)(undefined);
}
/**
 * タスク更新
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param updates 更新内容
 * @returns 成功 or エラー
 */
function updateTask(board_id, task_id, updates) {
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
    const task_index = active.t.findIndex((t) => t.i === task_id);
    if (task_index === -1) {
        return (0, types_1.Err)({ type: 'task_not_found', task_id });
    }
    const task = active.t[task_index];
    // 更新
    if (updates.title !== undefined) {
        task.t = updates.title;
    }
    if (updates.description !== undefined) {
        task.d = updates.description;
    }
    if (updates.priority !== undefined) {
        task.p = updates.priority;
    }
    if (updates.assigned_to !== undefined) {
        task.a = updates.assigned_to;
    }
    task.u = (0, utils_1.now)();
    active.u = (0, utils_1.now)();
    // 書き込み
    const write_result = (0, utils_1.writeJSON)(active_file, active);
    return write_result;
}
/**
 * ボード情報取得
 *
 * @param board_id ボードID
 * @returns ボード情報 or エラー
 */
function getBoardInfo(board_id) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const config_file = `${board_dir}/config.json`;
    return (0, utils_1.readJSON)(config_file);
}
/**
 * グローバルインデックスにボード登録
 */
function registerBoard(board_id, name, project_path) {
    const global_dir = (0, utils_1.getGlobalDir)();
    const index_file = `${global_dir}/index.json`;
    // ディレクトリ作成
    const ensure_result = (0, utils_1.ensureDir)(global_dir);
    if (!ensure_result.ok) {
        return (0, types_1.Err)(ensure_result.error);
    }
    // インデックス読み込み
    let index;
    if ((0, fs_1.existsSync)(index_file)) {
        const index_result = (0, utils_1.readJSON)(index_file);
        if (!index_result.ok) {
            return (0, types_1.Err)(index_result.error);
        }
        index = index_result.value;
    }
    else {
        index = {
            version: '1.0.0',
            boards: [],
            updated_at: (0, utils_1.now)()
        };
    }
    // ボード登録
    index.boards.push({
        id: board_id,
        name,
        project_path,
        task_count: 0,
        updated_at: (0, utils_1.now)()
    });
    index.updated_at = (0, utils_1.now)();
    // 書き込み
    return (0, utils_1.writeJSON)(index_file, index, true);
}
/**
 * 全ボード一覧取得
 */
function listBoards() {
    const global_dir = (0, utils_1.getGlobalDir)();
    const index_file = `${global_dir}/index.json`;
    if (!(0, fs_1.existsSync)(index_file)) {
        return (0, types_1.Ok)({
            version: '1.0.0',
            boards: [],
            updated_at: (0, utils_1.now)()
        });
    }
    return (0, utils_1.readJSON)(index_file);
}
/**
 * プロジェクトパスからボード検索
 */
function findBoardByProject(project_path) {
    const boards_result = listBoards();
    if (!boards_result.ok) {
        return (0, types_1.Err)(boards_result.error);
    }
    const board = boards_result.value.boards.find((b) => b.project_path === project_path);
    return (0, types_1.Ok)(board ? board.id : null);
}
function getBoardStatus(board_id) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    const config_result = getBoardInfo(board_id);
    if (!config_result.ok) {
        return (0, types_1.Err)(config_result.error);
    }
    const config = config_result.value;
    const tasks_result = listTasks(board_id);
    if (!tasks_result.ok) {
        return (0, types_1.Err)(tasks_result.error);
    }
    const tasks = tasks_result.value;
    // ステータス別カウント
    const task_counts = {
        backlog: 0,
        ready: 0,
        in_progress: 0,
        review: 0,
        test: 0,
        done: 0
    };
    for (const task of tasks) {
        task_counts[task.s]++;
    }
    // ロック済みタスク数
    const locked_tasks = tasks.filter((t) => t.l && t.l.e > (0, utils_1.now)()).length;
    // ブロックされたタスク数（metadata.blockedフラグ）
    const blocked_tasks = tasks.filter((t) => t.m?.blocked === true).length;
    // 進捗率計算（Done / 全タスク）
    const total_tasks = tasks.length;
    const progress_percentage = total_tasks > 0 ? Math.floor((task_counts.done / total_tasks) * 100) : 0;
    // 次のタスク提案
    const next_task_result = getNextTask(board_id);
    const next_task_id = next_task_result.ok ? next_task_result.value?.i ?? null : null;
    return (0, types_1.Ok)({
        board_id,
        board_name: config.name,
        project_path: config.project_path,
        task_counts,
        total_tasks,
        wip_limit: config.wip_limit.in_progress,
        wip_current: task_counts.in_progress,
        locked_tasks,
        blocked_tasks,
        progress_percentage,
        next_task_id
    });
}
/**
 * 次のタスク提案
 *
 * WIP制限を考慮して、次に着手すべきタスクを提案
 *
 * @param board_id ボードID
 * @returns 次のタスク or null（タスクがない場合）
 */
function getNextTask(board_id) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    const tasks_result = listTasks(board_id);
    if (!tasks_result.ok) {
        return (0, types_1.Err)(tasks_result.error);
    }
    const tasks = tasks_result.value;
    // In Progressタスクがある場合はnull（WIP=1を守る）
    const in_progress = tasks.filter((t) => t.s === 'in_progress');
    if (in_progress.length > 0) {
        return (0, types_1.Ok)(null);
    }
    // 優先順位: Ready > Backlog
    const priority_order = ['critical', 'high', 'medium', 'low'];
    // Readyから選択
    const ready_tasks = tasks.filter((t) => t.s === 'ready' && !t.m?.blocked);
    for (const priority of priority_order) {
        const task = ready_tasks.find((t) => t.p === priority);
        if (task) {
            return (0, types_1.Ok)(task);
        }
    }
    // Backlogから選択
    const backlog_tasks = tasks.filter((t) => t.s === 'backlog' && !t.m?.blocked);
    for (const priority of priority_order) {
        const task = backlog_tasks.find((t) => t.p === priority);
        if (task) {
            return (0, types_1.Ok)(task);
        }
    }
    return (0, types_1.Ok)(null);
}
/**
 * タスク分割
 *
 * 大きいタスクを複数のサブタスクに分割
 *
 * @param board_id ボードID
 * @param task_id 分割元タスクID
 * @param subtasks サブタスク一覧
 * @returns 分割後のタスクID配列 or エラー
 */
function splitTask(board_id, task_id, subtasks) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    if (!(0, types_1.isValidUUID)(task_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: task_id });
    }
    // 元タスク取得
    const original_task_result = getTask(board_id, task_id);
    if (!original_task_result.ok) {
        return (0, types_1.Err)(original_task_result.error);
    }
    const original_task = original_task_result.value;
    const subtask_ids = [];
    // サブタスク作成
    for (const subtask of subtasks) {
        const result = addTask(board_id, subtask.title, {
            priority: subtask.priority ?? original_task.p,
            status: original_task.s,
            description: `[Split from: ${original_task.t}]`
        });
        if (!result.ok) {
            return (0, types_1.Err)(result.error);
        }
        subtask_ids.push(result.value);
    }
    // 元タスクをDoneに移動（分割済みマーク）
    const update_result = updateTask(board_id, task_id, {
        description: `[Split into ${subtasks.length} tasks] ${original_task.d ?? ''}`
    });
    if (!update_result.ok) {
        return (0, types_1.Err)(update_result.error);
    }
    const done_result = updateTaskStatus(board_id, task_id, 'done');
    if (!done_result.ok) {
        return (0, types_1.Err)(done_result.error);
    }
    return (0, types_1.Ok)(subtask_ids);
}
function getBoardProgress(board_id) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    const config_result = getBoardInfo(board_id);
    if (!config_result.ok) {
        return (0, types_1.Err)(config_result.error);
    }
    const config = config_result.value;
    const tasks_result = listTasks(board_id);
    if (!tasks_result.ok) {
        return (0, types_1.Err)(tasks_result.error);
    }
    const tasks = tasks_result.value;
    // ステータス別集計
    const by_status = {
        backlog: 0,
        ready: 0,
        in_progress: 0,
        review: 0,
        test: 0,
        done: 0
    };
    for (const task of tasks) {
        by_status[task.s]++;
    }
    // 優先度別集計
    const by_priority = {
        critical: 0,
        high: 0,
        medium: 0,
        low: 0
    };
    for (const task of tasks) {
        by_priority[task.p]++;
    }
    const total_tasks = tasks.length;
    const completed_tasks = by_status.done;
    const progress_percentage = total_tasks > 0 ? Math.floor((completed_tasks / total_tasks) * 100) : 0;
    const estimated_remaining_tasks = total_tasks - completed_tasks;
    return (0, types_1.Ok)({
        board_id,
        board_name: config.name,
        total_tasks,
        completed_tasks,
        progress_percentage,
        by_status,
        by_priority,
        estimated_remaining_tasks
    });
}
/**
 * タスクをブロック状態に設定
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param reason ブロック理由
 * @returns 成功 or エラー
 */
function blockTask(board_id, task_id, reason) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    if (!(0, types_1.isValidUUID)(task_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: task_id });
    }
    const task_result = getTask(board_id, task_id);
    if (!task_result.ok) {
        return (0, types_1.Err)(task_result.error);
    }
    const task = task_result.value;
    // metadata更新
    const metadata = task.m ?? {};
    metadata.blocked = true;
    metadata.block_reason = reason;
    metadata.blocked_at = (0, utils_1.now)();
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const active_file = `${board_dir}/active.json`;
    const active_result = (0, utils_1.readJSON)(active_file);
    if (!active_result.ok) {
        return (0, types_1.Err)(active_result.error);
    }
    const active = active_result.value;
    const task_index = active.t.findIndex((t) => t.i === task_id);
    if (task_index === -1) {
        return (0, types_1.Err)({ type: 'task_not_found', task_id });
    }
    active.t[task_index].m = metadata;
    active.t[task_index].u = (0, utils_1.now)();
    active.u = (0, utils_1.now)();
    return (0, utils_1.writeJSON)(active_file, active);
}
/**
 * タスクのブロック解除
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns 成功 or エラー
 */
function unblockTask(board_id, task_id) {
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
    const task_index = active.t.findIndex((t) => t.i === task_id);
    if (task_index === -1) {
        return (0, types_1.Err)({ type: 'task_not_found', task_id });
    }
    const metadata = active.t[task_index].m ?? {};
    delete metadata.blocked;
    delete metadata.block_reason;
    delete metadata.blocked_at;
    active.t[task_index].m = Object.keys(metadata).length > 0 ? metadata : undefined;
    active.t[task_index].u = (0, utils_1.now)();
    active.u = (0, utils_1.now)();
    return (0, utils_1.writeJSON)(active_file, active);
}
//# sourceMappingURL=board-manager.js.map