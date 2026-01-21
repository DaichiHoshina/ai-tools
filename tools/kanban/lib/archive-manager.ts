/**
 * アーカイブ管理
 *
 * 完了タスクの自動アーカイブによるトークン最適化
 */

import { existsSync, readdirSync } from 'fs';
import type { Result, Task, ArchiveFile, BoardConfig } from './types';
import { Ok, Err, isValidUUID } from './types';
import { now, formatDate, getBoardDir, readJSON, writeJSON, ensureDir } from './utils';

/**
 * 自動アーカイブ実行
 *
 * 完了後、指定日数経過したタスクをアーカイブに移動
 *
 * @param board_id ボードID
 * @returns アーカイブしたタスク数 or エラー
 */
export function autoArchive(board_id: string): Result<number> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }

  const board_dir = getBoardDir(board_id);
  const config_file = `${board_dir}/config.json`;
  const active_file = `${board_dir}/active.json`;
  const archive_dir = `${board_dir}/archive`;

  // 設定読み込み
  const config_result = readJSON<BoardConfig>(config_file);
  if (!config_result.ok) {
    return Err(config_result.error);
  }
  const config = config_result.value;

  // アクティブタスク読み込み
  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    return Err(active_result.error);
  }
  const active = active_result.value;

  // アーカイブ対象抽出
  const current_time = now();
  const cutoff_time = current_time - config.archive_after_days * 86400;

  const to_archive = active.t.filter(
    (task) => task.s === 'done' && task.u < cutoff_time
  );

  if (to_archive.length === 0) {
    return Ok(0);
  }

  // アーカイブディレクトリ作成
  const ensure_result = ensureDir(archive_dir);
  if (!ensure_result.ok) {
    return Err(ensure_result.error);
  }

  // 日付ごとにグループ化
  const grouped = groupByDate(to_archive);

  // 各日付でアーカイブファイル作成
  for (const [date, tasks] of Object.entries(grouped)) {
    const archive_file = `${archive_dir}/${date}.json`;

    // 既存アーカイブファイル読み込み（存在する場合）
    let archive_data: ArchiveFile;
    if (existsSync(archive_file)) {
      const existing_result = readJSON<ArchiveFile>(archive_file);
      if (!existing_result.ok) {
        return Err(existing_result.error);
      }
      archive_data = existing_result.value;
      archive_data.tasks.push(...tasks);
      archive_data.archived_at = current_time;
    } else {
      archive_data = {
        date,
        board_id,
        tasks,
        archived_at: current_time
      };
    }

    // アーカイブファイル書き込み
    const write_result = writeJSON(archive_file, archive_data);
    if (!write_result.ok) {
      return Err(write_result.error);
    }
  }

  // アクティブタスクから削除
  const remaining = active.t.filter((task) => !to_archive.includes(task));
  active.t = remaining;
  active.u = current_time;

  const write_result = writeJSON(active_file, active);
  if (!write_result.ok) {
    return Err(write_result.error);
  }

  return Ok(to_archive.length);
}

/**
 * アーカイブからタスク取得
 *
 * @param board_id ボードID
 * @param date 日付（YYYY-MM-DD形式、省略時は全日付）
 * @returns アーカイブタスク or エラー
 */
export function getArchivedTasks(board_id: string, date?: string): Result<Task[]> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }

  const board_dir = getBoardDir(board_id);
  const archive_dir = `${board_dir}/archive`;

  if (!existsSync(archive_dir)) {
    return Ok([]);
  }

  const all_tasks: Task[] = [];

  if (date) {
    // 特定日付のみ
    const archive_file = `${archive_dir}/${date}.json`;
    if (!existsSync(archive_file)) {
      return Ok([]);
    }

    const archive_result = readJSON<ArchiveFile>(archive_file);
    if (!archive_result.ok) {
      return Err(archive_result.error);
    }

    return Ok(archive_result.value.tasks);
  }

  // 全日付
  const files = readdirSync(archive_dir).filter((f) => f.endsWith('.json'));

  for (const file of files) {
    const archive_file = `${archive_dir}/${file}`;
    const archive_result = readJSON<ArchiveFile>(archive_file);
    if (!archive_result.ok) {
      continue; // エラーは無視して続行
    }

    all_tasks.push(...archive_result.value.tasks);
  }

  return Ok(all_tasks);
}

/**
 * アーカイブからタスク復元
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns 成功 or エラー
 */
export function restoreTask(board_id: string, task_id: string): Result<void> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }
  if (!isValidUUID(task_id)) {
    return Err({ type: 'invalid_uuid', value: task_id });
  }

  const board_dir = getBoardDir(board_id);
  const archive_dir = `${board_dir}/archive`;
  const active_file = `${board_dir}/active.json`;

  if (!existsSync(archive_dir)) {
    return Err({ type: 'task_not_found', task_id });
  }

  // アーカイブから検索
  const files = readdirSync(archive_dir).filter((f) => f.endsWith('.json'));
  let found_task: Task | undefined;
  let found_file: string | undefined;

  for (const file of files) {
    const archive_file = `${archive_dir}/${file}`;
    const archive_result = readJSON<ArchiveFile>(archive_file);
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
      archive_data.archived_at = now();

      if (archive_data.tasks.length === 0) {
        // アーカイブファイルが空になったら削除は行わない（履歴として保持）
      }

      const write_result = writeJSON(archive_file, archive_data);
      if (!write_result.ok) {
        return Err(write_result.error);
      }

      break;
    }
  }

  if (!found_task) {
    return Err({ type: 'task_not_found', task_id });
  }

  // アクティブタスクに追加
  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    return Err(active_result.error);
  }

  const active = active_result.value;

  // ステータスをbacklogに戻す
  found_task.s = 'backlog';
  found_task.u = now();

  active.t.push(found_task);
  active.u = now();

  const write_result = writeJSON(active_file, active);
  return write_result;
}

/**
 * タスクを日付ごとにグループ化
 */
function groupByDate(tasks: Task[]): Record<string, Task[]> {
  const grouped: Record<string, Task[]> = {};

  for (const task of tasks) {
    const date = formatDate(task.u);
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
export function getArchiveSummary(board_id: string): Result<{
  total_files: number;
  total_tasks: number;
  oldest_date: string | null;
  newest_date: string | null;
}> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }

  const board_dir = getBoardDir(board_id);
  const archive_dir = `${board_dir}/archive`;

  if (!existsSync(archive_dir)) {
    return Ok({
      total_files: 0,
      total_tasks: 0,
      oldest_date: null,
      newest_date: null
    });
  }

  const files = readdirSync(archive_dir).filter((f) => f.endsWith('.json'));
  const dates = files.map((f) => f.replace('.json', '')).sort();

  let total_tasks = 0;

  for (const file of files) {
    const archive_file = `${archive_dir}/${file}`;
    const archive_result = readJSON<ArchiveFile>(archive_file);
    if (archive_result.ok) {
      total_tasks += archive_result.value.tasks.length;
    }
  }

  return Ok({
    total_files: files.length,
    total_tasks,
    oldest_date: dates.length > 0 ? dates[0] : null,
    newest_date: dates.length > 0 ? dates[dates.length - 1] : null
  });
}
