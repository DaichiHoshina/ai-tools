"use strict";
/**
 * アーカイブ管理
 *
 * 完了タスクの自動アーカイブによるトークン最適化
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.autoArchive = autoArchive;
exports.getArchivedTasks = getArchivedTasks;
exports.restoreTask = restoreTask;
exports.getArchiveSummary = getArchiveSummary;
const fs_1 = require("fs");
const types_1 = require("./types");
const utils_1 = require("./utils");
/**
 * 自動アーカイブ実行
 *
 * 完了後、指定日数経過したタスクをアーカイブに移動
 *
 * @param board_id ボードID
 * @returns アーカイブしたタスク数 or エラー
 */
function autoArchive(board_id) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const config_file = `${board_dir}/config.json`;
    const active_file = `${board_dir}/active.json`;
    const archive_dir = `${board_dir}/archive`;
    // 設定読み込み
    const config_result = (0, utils_1.readJSON)(config_file);
    if (!config_result.ok) {
        return (0, types_1.Err)(config_result.error);
    }
    const config = config_result.value;
    // アクティブタスク読み込み
    const active_result = (0, utils_1.readJSON)(active_file);
    if (!active_result.ok) {
        return (0, types_1.Err)(active_result.error);
    }
    const active = active_result.value;
    // アーカイブ対象抽出
    const current_time = (0, utils_1.now)();
    const cutoff_time = current_time - config.archive_after_days * 86400;
    const to_archive = active.t.filter((task) => task.s === 'done' && task.u < cutoff_time);
    if (to_archive.length === 0) {
        return (0, types_1.Ok)(0);
    }
    // アーカイブディレクトリ作成
    const ensure_result = (0, utils_1.ensureDir)(archive_dir);
    if (!ensure_result.ok) {
        return (0, types_1.Err)(ensure_result.error);
    }
    // 日付ごとにグループ化
    const grouped = groupByDate(to_archive);
    // 各日付でアーカイブファイル作成
    for (const [date, tasks] of Object.entries(grouped)) {
        const archive_file = `${archive_dir}/${date}.json`;
        // 既存アーカイブファイル読み込み（存在する場合）
        let archive_data;
        if ((0, fs_1.existsSync)(archive_file)) {
            const existing_result = (0, utils_1.readJSON)(archive_file);
            if (!existing_result.ok) {
                return (0, types_1.Err)(existing_result.error);
            }
            archive_data = existing_result.value;
            archive_data.tasks.push(...tasks);
            archive_data.archived_at = current_time;
        }
        else {
            archive_data = {
                date,
                board_id,
                tasks,
                archived_at: current_time
            };
        }
        // アーカイブファイル書き込み
        const write_result = (0, utils_1.writeJSON)(archive_file, archive_data);
        if (!write_result.ok) {
            return (0, types_1.Err)(write_result.error);
        }
    }
    // アクティブタスクから削除
    const remaining = active.t.filter((task) => !to_archive.includes(task));
    active.t = remaining;
    active.u = current_time;
    const write_result = (0, utils_1.writeJSON)(active_file, active);
    if (!write_result.ok) {
        return (0, types_1.Err)(write_result.error);
    }
    return (0, types_1.Ok)(to_archive.length);
}
/**
 * アーカイブからタスク取得
 *
 * @param board_id ボードID
 * @param date 日付（YYYY-MM-DD形式、省略時は全日付）
 * @returns アーカイブタスク or エラー
 */
function getArchivedTasks(board_id, date) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const archive_dir = `${board_dir}/archive`;
    if (!(0, fs_1.existsSync)(archive_dir)) {
        return (0, types_1.Ok)([]);
    }
    const all_tasks = [];
    if (date) {
        // 特定日付のみ
        const archive_file = `${archive_dir}/${date}.json`;
        if (!(0, fs_1.existsSync)(archive_file)) {
            return (0, types_1.Ok)([]);
        }
        const archive_result = (0, utils_1.readJSON)(archive_file);
        if (!archive_result.ok) {
            return (0, types_1.Err)(archive_result.error);
        }
        return (0, types_1.Ok)(archive_result.value.tasks);
    }
    // 全日付
    const files = (0, fs_1.readdirSync)(archive_dir).filter((f) => f.endsWith('.json'));
    for (const file of files) {
        const archive_file = `${archive_dir}/${file}`;
        const archive_result = (0, utils_1.readJSON)(archive_file);
        if (!archive_result.ok) {
            continue; // エラーは無視して続行
        }
        all_tasks.push(...archive_result.value.tasks);
    }
    return (0, types_1.Ok)(all_tasks);
}
/**
 * アーカイブからタスク復元
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns 成功 or エラー
 */
function restoreTask(board_id, task_id) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    if (!(0, types_1.isValidUUID)(task_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: task_id });
    }
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const archive_dir = `${board_dir}/archive`;
    const active_file = `${board_dir}/active.json`;
    if (!(0, fs_1.existsSync)(archive_dir)) {
        return (0, types_1.Err)({ type: 'task_not_found', task_id });
    }
    // アーカイブから検索
    const files = (0, fs_1.readdirSync)(archive_dir).filter((f) => f.endsWith('.json'));
    let found_task;
    let found_file;
    for (const file of files) {
        const archive_file = `${archive_dir}/${file}`;
        const archive_result = (0, utils_1.readJSON)(archive_file);
        if (!archive_result.ok) {
            continue;
        }
        const archive_data = archive_result.value;
        const task_index = archive_data.tasks.findIndex((t) => t.i === task_id);
        if (task_index !== -1) {
            found_task = archive_data.tasks[task_index];
            found_file = archive_file;
            // アーカイブから削除
            archive_data.tasks.splice(task_index, 1);
            archive_data.archived_at = (0, utils_1.now)();
            if (archive_data.tasks.length === 0) {
                // アーカイブファイルが空になったら削除は行わない（履歴として保持）
            }
            const write_result = (0, utils_1.writeJSON)(archive_file, archive_data);
            if (!write_result.ok) {
                return (0, types_1.Err)(write_result.error);
            }
            break;
        }
    }
    if (!found_task) {
        return (0, types_1.Err)({ type: 'task_not_found', task_id });
    }
    // アクティブタスクに追加
    const active_result = (0, utils_1.readJSON)(active_file);
    if (!active_result.ok) {
        return (0, types_1.Err)(active_result.error);
    }
    const active = active_result.value;
    // ステータスをbacklogに戻す
    found_task.s = 'backlog';
    found_task.u = (0, utils_1.now)();
    active.t.push(found_task);
    active.u = (0, utils_1.now)();
    const write_result = (0, utils_1.writeJSON)(active_file, active);
    return write_result;
}
/**
 * タスクを日付ごとにグループ化
 */
function groupByDate(tasks) {
    const grouped = {};
    for (const task of tasks) {
        const date = (0, utils_1.formatDate)(task.u);
        if (!grouped[date]) {
            grouped[date] = [];
        }
        grouped[date].push(task);
    }
    return grouped;
}
/**
 * アーカイブサマリー取得
 *
 * @param board_id ボードID
 * @returns サマリー情報 or エラー
 */
function getArchiveSummary(board_id) {
    if (!(0, types_1.isValidUUID)(board_id)) {
        return (0, types_1.Err)({ type: 'invalid_uuid', value: board_id });
    }
    const board_dir = (0, utils_1.getBoardDir)(board_id);
    const archive_dir = `${board_dir}/archive`;
    if (!(0, fs_1.existsSync)(archive_dir)) {
        return (0, types_1.Ok)({
            total_files: 0,
            total_tasks: 0,
            oldest_date: null,
            newest_date: null
        });
    }
    const files = (0, fs_1.readdirSync)(archive_dir).filter((f) => f.endsWith('.json'));
    const dates = files.map((f) => f.replace('.json', '')).sort();
    let total_tasks = 0;
    for (const file of files) {
        const archive_file = `${archive_dir}/${file}`;
        const archive_result = (0, utils_1.readJSON)(archive_file);
        if (archive_result.ok) {
            total_tasks += archive_result.value.tasks.length;
        }
    }
    return (0, types_1.Ok)({
        total_files: files.length,
        total_tasks,
        oldest_date: dates.length > 0 ? dates[0] : null,
        newest_date: dates.length > 0 ? dates[dates.length - 1] : null
    });
}
//# sourceMappingURL=archive-manager.js.map