/**
 * ボード管理
 *
 * Kanbanボードの作成・読み込み・更新
 */

import { existsSync } from 'fs';
import type { Result, BoardConfig, Task, TaskStatus, TaskPriority, GlobalIndex } from './types';
import { Ok, Err, isValidUUID, isValidTransition } from './types';
import {
  now,
  generateUUID,
  getBoardDir,
  getGlobalDir,
  readJSON,
  writeJSON,
  ensureDir
} from './utils';
import { acquireLock, releaseLock } from './lock-manager';
import { autoArchive } from './archive-manager';

/**
 * ボード初期化
 *
 * @param name ボード名
 * @param project_path プロジェクトパス
 * @returns ボードID or エラー
 */
export function initBoard(name: string, project_path: string): Result<string> {
  const board_id = generateUUID();
  const board_dir = getBoardDir(board_id);

  // ディレクトリ作成
  const ensure_result = ensureDir(board_dir);
  if (!ensure_result.ok) {
    return Err(ensure_result.error);
  }

  const ensure_archive_result = ensureDir(`${board_dir}/archive`);
  if (!ensure_archive_result.ok) {
    return Err(ensure_archive_result.error);
  }

  // 設定ファイル作成
  const config: BoardConfig = {
    id: board_id,
    name,
    project_path,
    created_at: now(),
    updated_at: now(),
    wip_limit: {
      in_progress: 1
    },
    archive_after_days: 7
  };

  const config_result = writeJSON(`${board_dir}/config.json`, config, true);
  if (!config_result.ok) {
    return Err(config_result.error);
  }

  // アクティブボード初期化
  const active = {
    v: '1.0.0',
    b: board_id,
    t: [],
    u: now()
  };

  const active_result = writeJSON(`${board_dir}/active.json`, active);
  if (!active_result.ok) {
    return Err(active_result.error);
  }

  // グローバルインデックスに登録
  const register_result = registerBoard(board_id, name, project_path);
  if (!register_result.ok) {
    return Err(register_result.error);
  }

  return Ok(board_id);
}

/**
 * タスク追加
 *
 * @param board_id ボードID
 * @param title タスクタイトル
 * @param options オプション
 * @returns タスクID or エラー
 */
export function addTask(
  board_id: string,
  title: string,
  options?: {
    description?: string;
    priority?: TaskPriority;
    status?: TaskStatus;
  }
): Result<string> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }

  const board_dir = getBoardDir(board_id);
  const active_file = `${board_dir}/active.json`;

  // アクティブボード読み込み
  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    return Err(active_result.error);
  }

  const active = active_result.value;
  const task_id = generateUUID();

  // タスク作成
  const task: Task = {
    i: task_id,
    t: title,
    d: options?.description,
    s: options?.status ?? 'backlog',
    p: options?.priority ?? 'medium',
    c: now(),
    u: now()
  };

  // タスク追加
  active.t.push(task);
  active.u = now();

  // 書き込み
  const write_result = writeJSON(active_file, active);
  if (!write_result.ok) {
    return Err(write_result.error);
  }

  return Ok(task_id);
}

/**
 * タスク取得
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns タスク or エラー
 */
export function getTask(board_id: string, task_id: string): Result<Task> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }
  if (!isValidUUID(task_id)) {
    return Err({ type: 'invalid_uuid', value: task_id });
  }

  const board_dir = getBoardDir(board_id);
  const active_file = `${board_dir}/active.json`;

  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    return Err(active_result.error);
  }

  const task = active_result.value.t.find((t) => t.i === task_id);
  if (!task) {
    return Err({ type: 'task_not_found', task_id });
  }

  return Ok(task);
}

/**
 * タスク一覧取得
 *
 * @param board_id ボードID
 * @param filter フィルタ
 * @returns タスク一覧 or エラー
 */
export function listTasks(
  board_id: string,
  filter?: {
    status?: TaskStatus;
    priority?: TaskPriority;
  }
): Result<Task[]> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }

  const board_dir = getBoardDir(board_id);
  const active_file = `${board_dir}/active.json`;

  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    return Err(active_result.error);
  }

  let tasks = active_result.value.t;

  // フィルタ適用
  if (filter?.status) {
    tasks = tasks.filter((t) => t.s === filter.status);
  }
  if (filter?.priority) {
    tasks = tasks.filter((t) => t.p === filter.priority);
  }

  return Ok(tasks);
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
export function updateTaskStatus(
  board_id: string,
  task_id: string,
  new_status: TaskStatus,
  agent_id?: string
): Result<void> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }
  if (!isValidUUID(task_id)) {
    return Err({ type: 'invalid_uuid', value: task_id });
  }

  const board_dir = getBoardDir(board_id);
  const config_file = `${board_dir}/config.json`;
  const active_file = `${board_dir}/active.json`;

  // 設定読み込み
  const config_result = readJSON<BoardConfig>(config_file);
  if (!config_result.ok) {
    return Err(config_result.error);
  }
  const config = config_result.value;

  // アクティブボード読み込み
  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    return Err(active_result.error);
  }

  const active = active_result.value;
  const task_index = active.t.findIndex((t) => t.i === task_id);

  if (task_index === -1) {
    return Err({ type: 'task_not_found', task_id });
  }

  const task = active.t[task_index];

  // ステータス遷移検証
  if (!isValidTransition(task.s, new_status)) {
    return Err({
      type: 'invalid_transition',
      from: task.s,
      to: new_status
    });
  }

  // WIP制限チェック（In Progressに移動する場合）
  if (new_status === 'in_progress') {
    const in_progress_count = active.t.filter((t) => t.s === 'in_progress').length;
    if (in_progress_count >= config.wip_limit.in_progress) {
      return Err({
        type: 'wip_limit_exceeded',
        limit: config.wip_limit.in_progress,
        current: in_progress_count
      });
    }
  }

  // ステータス更新
  task.s = new_status;
  task.u = now();

  // In Progressに移動する場合はロック取得
  if (new_status === 'in_progress') {
    const lock_result = acquireLock(board_id, task_id, agent_id);
    if (!lock_result.ok) {
      return Err(lock_result.error);
    }
    task.l = lock_result.value;
  }

  // Doneに移動する場合はロック解放
  if (new_status === 'done' && task.l) {
    const unlock_result = releaseLock(board_id, task_id, agent_id);
    if (!unlock_result.ok) {
      return Err(unlock_result.error);
    }
    delete task.l;
  }

  active.u = now();

  // 書き込み
  const write_result = writeJSON(active_file, active);
  if (!write_result.ok) {
    return Err(write_result.error);
  }

  // 自動アーカイブ実行
  autoArchive(board_id);

  return Ok(undefined);
}

/**
 * タスク更新
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param updates 更新内容
 * @returns 成功 or エラー
 */
export function updateTask(
  board_id: string,
  task_id: string,
  updates: {
    title?: string;
    description?: string;
    priority?: TaskPriority;
    assigned_to?: string;
  }
): Result<void> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }
  if (!isValidUUID(task_id)) {
    return Err({ type: 'invalid_uuid', value: task_id });
  }

  const board_dir = getBoardDir(board_id);
  const active_file = `${board_dir}/active.json`;

  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    return Err(active_result.error);
  }

  const active = active_result.value;
  const task_index = active.t.findIndex((t) => t.i === task_id);

  if (task_index === -1) {
    return Err({ type: 'task_not_found', task_id });
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

  task.u = now();
  active.u = now();

  // 書き込み
  const write_result = writeJSON(active_file, active);
  return write_result;
}

/**
 * ボード情報取得
 *
 * @param board_id ボードID
 * @returns ボード情報 or エラー
 */
export function getBoardInfo(board_id: string): Result<BoardConfig> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }

  const board_dir = getBoardDir(board_id);
  const config_file = `${board_dir}/config.json`;

  return readJSON<BoardConfig>(config_file);
}

/**
 * グローバルインデックスにボード登録
 */
function registerBoard(board_id: string, name: string, project_path: string): Result<void> {
  const global_dir = getGlobalDir();
  const index_file = `${global_dir}/index.json`;

  // ディレクトリ作成
  const ensure_result = ensureDir(global_dir);
  if (!ensure_result.ok) {
    return Err(ensure_result.error);
  }

  // インデックス読み込み
  let index: GlobalIndex;
  if (existsSync(index_file)) {
    const index_result = readJSON<GlobalIndex>(index_file);
    if (!index_result.ok) {
      return Err(index_result.error);
    }
    index = index_result.value;
  } else {
    index = {
      version: '1.0.0',
      boards: [],
      updated_at: now()
    };
  }

  // ボード登録
  index.boards.push({
    id: board_id,
    name,
    project_path,
    task_count: 0,
    updated_at: now()
  });

  index.updated_at = now();

  // 書き込み
  return writeJSON(index_file, index, true);
}

/**
 * 全ボード一覧取得
 */
export function listBoards(): Result<GlobalIndex> {
  const global_dir = getGlobalDir();
  const index_file = `${global_dir}/index.json`;

  if (!existsSync(index_file)) {
    return Ok({
      version: '1.0.0',
      boards: [],
      updated_at: now()
    });
  }

  return readJSON<GlobalIndex>(index_file);
}

/**
 * プロジェクトパスからボード検索
 */
export function findBoardByProject(project_path: string): Result<string | null> {
  const boards_result = listBoards();
  if (!boards_result.ok) {
    return Err(boards_result.error);
  }

  const board = boards_result.value.boards.find((b) => b.project_path === project_path);
  return Ok(board ? board.id : null);
}

/**
 * ボード詳細ステータス取得
 *
 * @param board_id ボードID
 * @returns 詳細ステータス or エラー
 */
export interface BoardStatus {
  board_id: string;
  board_name: string;
  project_path: string;
  task_counts: Record<TaskStatus, number>;
  total_tasks: number;
  wip_limit: number;
  wip_current: number;
  locked_tasks: number;
  blocked_tasks: number;
  progress_percentage: number;
  next_task_id: string | null;
}

export function getBoardStatus(board_id: string): Result<BoardStatus> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }

  const config_result = getBoardInfo(board_id);
  if (!config_result.ok) {
    return Err(config_result.error);
  }
  const config = config_result.value;

  const tasks_result = listTasks(board_id);
  if (!tasks_result.ok) {
    return Err(tasks_result.error);
  }
  const tasks = tasks_result.value;

  // ステータス別カウント
  const task_counts: Record<TaskStatus, number> = {
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
  const locked_tasks = tasks.filter((t) => t.l && t.l.e > now()).length;

  // ブロックされたタスク数（metadata.blockedフラグ）
  const blocked_tasks = tasks.filter((t) => t.m?.blocked === true).length;

  // 進捗率計算（Done / 全タスク）
  const total_tasks = tasks.length;
  const progress_percentage = total_tasks > 0 ? Math.floor((task_counts.done / total_tasks) * 100) : 0;

  // 次のタスク提案
  const next_task_result = getNextTask(board_id);
  const next_task_id = next_task_result.ok ? next_task_result.value?.i ?? null : null;

  return Ok({
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
export function getNextTask(board_id: string): Result<Task | null> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }

  const tasks_result = listTasks(board_id);
  if (!tasks_result.ok) {
    return Err(tasks_result.error);
  }
  const tasks = tasks_result.value;

  // In Progressタスクがある場合はnull（WIP=1を守る）
  const in_progress = tasks.filter((t) => t.s === 'in_progress');
  if (in_progress.length > 0) {
    return Ok(null);
  }

  // 優先順位: Ready > Backlog
  const priority_order: TaskPriority[] = ['critical', 'high', 'medium', 'low'];

  // Readyから選択
  const ready_tasks = tasks.filter((t) => t.s === 'ready' && !t.m?.blocked);
  for (const priority of priority_order) {
    const task = ready_tasks.find((t) => t.p === priority);
    if (task) {
      return Ok(task);
    }
  }

  // Backlogから選択
  const backlog_tasks = tasks.filter((t) => t.s === 'backlog' && !t.m?.blocked);
  for (const priority of priority_order) {
    const task = backlog_tasks.find((t) => t.p === priority);
    if (task) {
      return Ok(task);
    }
  }

  return Ok(null);
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
export function splitTask(
  board_id: string,
  task_id: string,
  subtasks: Array<{ title: string; priority?: TaskPriority }>
): Result<string[]> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }
  if (!isValidUUID(task_id)) {
    return Err({ type: 'invalid_uuid', value: task_id });
  }

  // 元タスク取得
  const original_task_result = getTask(board_id, task_id);
  if (!original_task_result.ok) {
    return Err(original_task_result.error);
  }
  const original_task = original_task_result.value;

  const subtask_ids: string[] = [];

  // サブタスク作成
  for (const subtask of subtasks) {
    const result = addTask(board_id, subtask.title, {
      priority: subtask.priority ?? original_task.p,
      status: original_task.s,
      description: `[Split from: ${original_task.t}]`
    });

    if (!result.ok) {
      return Err(result.error);
    }

    subtask_ids.push(result.value);
  }

  // 元タスクをDoneに移動（分割済みマーク）
  const update_result = updateTask(board_id, task_id, {
    description: `[Split into ${subtasks.length} tasks] ${original_task.d ?? ''}`
  });

  if (!update_result.ok) {
    return Err(update_result.error);
  }

  const done_result = updateTaskStatus(board_id, task_id, 'done');
  if (!done_result.ok) {
    return Err(done_result.error);
  }

  return Ok(subtask_ids);
}

/**
 * 進捗レポート取得
 *
 * Phase別の統計を取得
 *
 * @param board_id ボードID
 * @returns 進捗レポート or エラー
 */
export interface ProgressReport {
  board_id: string;
  board_name: string;
  total_tasks: number;
  completed_tasks: number;
  progress_percentage: number;
  by_status: Record<TaskStatus, number>;
  by_priority: Record<TaskPriority, number>;
  estimated_remaining_tasks: number;
}

export function getBoardProgress(board_id: string): Result<ProgressReport> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }

  const config_result = getBoardInfo(board_id);
  if (!config_result.ok) {
    return Err(config_result.error);
  }
  const config = config_result.value;

  const tasks_result = listTasks(board_id);
  if (!tasks_result.ok) {
    return Err(tasks_result.error);
  }
  const tasks = tasks_result.value;

  // ステータス別集計
  const by_status: Record<TaskStatus, number> = {
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
  const by_priority: Record<TaskPriority, number> = {
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

  return Ok({
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
export function blockTask(board_id: string, task_id: string, reason: string): Result<void> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }
  if (!isValidUUID(task_id)) {
    return Err({ type: 'invalid_uuid', value: task_id });
  }

  const task_result = getTask(board_id, task_id);
  if (!task_result.ok) {
    return Err(task_result.error);
  }
  const task = task_result.value;

  // metadata更新
  const metadata = task.m ?? {};
  metadata.blocked = true;
  metadata.block_reason = reason;
  metadata.blocked_at = now();

  const board_dir = getBoardDir(board_id);
  const active_file = `${board_dir}/active.json`;

  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    return Err(active_result.error);
  }

  const active = active_result.value;
  const task_index = active.t.findIndex((t) => t.i === task_id);

  if (task_index === -1) {
    return Err({ type: 'task_not_found', task_id });
  }

  active.t[task_index].m = metadata;
  active.t[task_index].u = now();
  active.u = now();

  return writeJSON(active_file, active);
}

/**
 * タスクのブロック解除
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns 成功 or エラー
 */
export function unblockTask(board_id: string, task_id: string): Result<void> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }
  if (!isValidUUID(task_id)) {
    return Err({ type: 'invalid_uuid', value: task_id });
  }

  const board_dir = getBoardDir(board_id);
  const active_file = `${board_dir}/active.json`;

  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    return Err(active_result.error);
  }

  const active = active_result.value;
  const task_index = active.t.findIndex((t) => t.i === task_id);

  if (task_index === -1) {
    return Err({ type: 'task_not_found', task_id });
  }

  const metadata = active.t[task_index].m ?? {};
  delete metadata.blocked;
  delete metadata.block_reason;
  delete metadata.blocked_at;

  active.t[task_index].m = Object.keys(metadata).length > 0 ? metadata : undefined;
  active.t[task_index].u = now();
  active.u = now();

  return writeJSON(active_file, active);
}
