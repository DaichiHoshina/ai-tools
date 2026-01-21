/**
 * ロック管理
 *
 * Sub agent間のタスク衝突を回避するためのロック機構
 */

import { existsSync, writeFileSync, readFileSync, unlinkSync } from 'fs';
import type { Result, Lock, Task } from './types';
import { Ok, Err, isValidUUID } from './types';
import { now, generateUUID, getAgentId, getBoardDir, readJSON, writeJSON } from './utils';

/**
 * ロックファイル情報
 */
interface LockFile {
  board_id: string;
  locked_by: string;
  locked_at: number;
  expires_at: number;
}

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
export function acquireLock(
  board_id: string,
  task_id: string,
  agent_id?: string,
  timeout: number = DEFAULT_LOCK_TIMEOUT
): Result<Lock> {
  // UUID検証
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }
  if (!isValidUUID(task_id)) {
    return Err({ type: 'invalid_uuid', value: task_id });
  }

  const aid = agent_id ?? getAgentId();
  const board_dir = getBoardDir(board_id);
  const lock_file = `${board_dir}/.lock`;
  const active_file = `${board_dir}/active.json`;

  // ボードロックファイル確認（他のagentがボード全体をロック中か）
  const board_lock_result = acquireBoardLock(board_id, aid, timeout);
  if (!board_lock_result.ok) {
    return board_lock_result;
  }

  // タスクのロック状態確認
  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    releaseBoardLock(board_id);
    return Err(active_result.error);
  }

  const active = active_result.value;
  const task_index = active.t.findIndex((t) => t.i === task_id);

  if (task_index === -1) {
    releaseBoardLock(board_id);
    return Err({ type: 'task_not_found', task_id });
  }

  const task = active.t[task_index];

  // 既存ロック確認
  if (task.l) {
    const current_time = now();
    if (task.l.e > current_time) {
      // ロック有効期限内
      if (task.l.a !== aid) {
        // 他のagentがロック中
        releaseBoardLock(board_id);
        return Err({
          type: 'task_locked',
          locked_by: task.l.a,
          expires_at: task.l.e
        });
      }
      // 自分自身がロック中（再取得）
      return Ok(task.l);
    }
    // ロック期限切れ → 自動解放して新規取得
  }

  // ロック設定
  const lock: Lock = {
    a: aid,
    t: now(),
    e: now() + timeout
  };

  task.l = lock;
  active.u = now();

  // 書き込み
  const write_result = writeJSON(active_file, active);
  releaseBoardLock(board_id);

  if (!write_result.ok) {
    return Err(write_result.error);
  }

  return Ok(lock);
}

/**
 * ロック解放
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param agent_id エージェントID（省略時は自動取得）
 * @returns 成功 or エラー
 */
export function releaseLock(
  board_id: string,
  task_id: string,
  agent_id?: string
): Result<void> {
  // UUID検証
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }
  if (!isValidUUID(task_id)) {
    return Err({ type: 'invalid_uuid', value: task_id });
  }

  const aid = agent_id ?? getAgentId();
  const board_dir = getBoardDir(board_id);
  const active_file = `${board_dir}/active.json`;

  // ボードロック取得
  const board_lock_result = acquireBoardLock(board_id, aid);
  if (!board_lock_result.ok) {
    return Err(board_lock_result.error);
  }

  // タスク読み込み
  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    releaseBoardLock(board_id);
    return Err(active_result.error);
  }

  const active = active_result.value;
  const task_index = active.t.findIndex((t) => t.i === task_id);

  if (task_index === -1) {
    releaseBoardLock(board_id);
    return Err({ type: 'task_not_found', task_id });
  }

  const task = active.t[task_index];

  // ロック削除
  delete task.l;
  active.u = now();

  // 書き込み
  const write_result = writeJSON(active_file, active);
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
export function checkLock(board_id: string, task_id: string): Result<Lock | null> {
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
  const task = active.t.find((t) => t.i === task_id);

  if (!task) {
    return Err({ type: 'task_not_found', task_id });
  }

  // 期限切れロックは無効扱い
  if (task.l && task.l.e > now()) {
    return Ok(task.l);
  }

  return Ok(null);
}

/**
 * ボードロック取得（内部用）
 *
 * active.jsonの読み書き時に使用
 */
function acquireBoardLock(
  board_id: string,
  agent_id: string,
  timeout: number = DEFAULT_LOCK_TIMEOUT
): Result<void> {
  const board_dir = getBoardDir(board_id);
  const lock_file = `${board_dir}/.lock`;

  // ロックファイル確認
  if (existsSync(lock_file)) {
    try {
      const content = readFileSync(lock_file, 'utf-8');
      const lock: LockFile = JSON.parse(content);

      // 期限確認
      if (lock.expires_at > now()) {
        // 有効期限内
        if (lock.locked_by !== agent_id) {
          // 他のagentがロック中
          return Err({
            type: 'task_locked',
            locked_by: lock.locked_by,
            expires_at: lock.expires_at
          });
        }
        // 自分自身がロック中（再取得）
        return Ok(undefined);
      }
      // 期限切れ → 削除して新規取得
      unlinkSync(lock_file);
    } catch {
      // ロックファイル破損 → 削除して新規取得
      unlinkSync(lock_file);
    }
  }

  // ロックファイル作成
  const lock: LockFile = {
    board_id,
    locked_by: agent_id,
    locked_at: now(),
    expires_at: now() + timeout
  };

  try {
    writeFileSync(lock_file, JSON.stringify(lock), 'utf-8');
    return Ok(undefined);
  } catch {
    return Err({ type: 'permission_denied', file: lock_file });
  }
}

/**
 * ボードロック解放（内部用）
 */
function releaseBoardLock(board_id: string): void {
  const board_dir = getBoardDir(board_id);
  const lock_file = `${board_dir}/.lock`;

  if (existsSync(lock_file)) {
    try {
      unlinkSync(lock_file);
    } catch {
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
export function cleanupExpiredLocks(board_id: string): Result<number> {
  if (!isValidUUID(board_id)) {
    return Err({ type: 'invalid_uuid', value: board_id });
  }

  const board_dir = getBoardDir(board_id);
  const active_file = `${board_dir}/active.json`;
  const agent_id = getAgentId();

  // ボードロック取得
  const board_lock_result = acquireBoardLock(board_id, agent_id);
  if (!board_lock_result.ok) {
    return Err(board_lock_result.error);
  }

  const active_result = readJSON<{ v: string; b: string; t: Task[]; u: number }>(active_file);
  if (!active_result.ok) {
    releaseBoardLock(board_id);
    return Err(active_result.error);
  }

  const active = active_result.value;
  const current_time = now();
  let cleaned = 0;

  for (const task of active.t) {
    if (task.l && task.l.e <= current_time) {
      delete task.l;
      cleaned++;
    }
  }

  if (cleaned > 0) {
    active.u = now();
    const write_result = writeJSON(active_file, active);
    releaseBoardLock(board_id);

    if (!write_result.ok) {
      return Err(write_result.error);
    }
  } else {
    releaseBoardLock(board_id);
  }

  return Ok(cleaned);
}
