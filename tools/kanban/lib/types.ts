/**
 * Kanban システム型定義
 *
 * 圧縮JSON対応のため、フィールド名を短縮
 */

export type TaskStatus = 'backlog' | 'ready' | 'in_progress' | 'review' | 'test' | 'done';
export type TaskPriority = 'low' | 'medium' | 'high' | 'critical';

/**
 * ロック情報
 */
export interface Lock {
  a: string;   // agent_id
  t: number;   // timestamp（UNIX timestamp）
  e: number;   // expires_at（UNIX timestamp）
}

/**
 * タスク（圧縮JSON形式）
 */
export interface Task {
  i: string;                     // id（UUID v4）
  t: string;                     // title
  d?: string;                    // description（オプション）
  s: TaskStatus;                 // status
  p: TaskPriority;               // priority
  a?: string;                    // assigned_to（agent ID）
  c: number;                     // created_at（UNIX timestamp）
  u: number;                     // updated_at（UNIX timestamp）
  l?: Lock;                      // lock（オプション）
  m?: Record<string, unknown>;   // metadata（オプション）
}

/**
 * ボード設定
 */
export interface BoardConfig {
  id: string;              // ボードID（UUID v4）
  name: string;            // ボード名
  project_path: string;    // プロジェクトパス
  created_at: number;      // 作成日時（UNIX timestamp）
  updated_at: number;      // 更新日時（UNIX timestamp）
  wip_limit: {
    in_progress: number;   // In Progress列のWIP制限
  };
  archive_after_days: number; // 自動アーカイブ日数
}

/**
 * アクティブボード（圧縮JSON形式）
 */
export interface ActiveBoard {
  v: string;    // version
  b: string;    // board_id
  t: Task[];    // tasks
  u: number;    // updated_at
}

/**
 * グローバルインデックス
 */
export interface GlobalIndex {
  version: string;
  boards: BoardIndexEntry[];
  updated_at: number;
}

export interface BoardIndexEntry {
  id: string;
  name: string;
  project_path: string;
  task_count: number;
  updated_at: number;
}

/**
 * アーカイブファイル
 */
export interface ArchiveFile {
  date: string;           // YYYY-MM-DD
  board_id: string;
  tasks: Task[];
  archived_at: number;
}

/**
 * エラー型
 */
export type KanbanError =
  | { type: 'board_not_found'; board_id: string }
  | { type: 'task_not_found'; task_id: string }
  | { type: 'task_locked'; locked_by: string; expires_at: number }
  | { type: 'wip_limit_exceeded'; limit: number; current: number }
  | { type: 'invalid_transition'; from: TaskStatus; to: TaskStatus }
  | { type: 'lock_timeout'; task_id: string }
  | { type: 'file_corruption'; file: string }
  | { type: 'invalid_uuid'; value: string }
  | { type: 'permission_denied'; file: string };

/**
 * Result型（関数型エラーハンドリング）
 */
export type Result<T, E = KanbanError> =
  | { ok: true; value: T }
  | { ok: false; error: E };

/**
 * ステータス遷移マップ
 */
export const STATUS_TRANSITIONS: Record<TaskStatus, TaskStatus[]> = {
  backlog: ['ready', 'in_progress'],
  ready: ['backlog', 'in_progress'],
  in_progress: ['ready', 'review', 'test', 'done'],
  review: ['in_progress', 'test', 'done'],
  test: ['review', 'done'],
  done: ['backlog', 'ready']  // 再オープン可能
};

/**
 * ステータス遷移検証
 */
export function isValidTransition(from: TaskStatus, to: TaskStatus): boolean {
  return STATUS_TRANSITIONS[from].includes(to);
}

/**
 * UUIDv4検証
 */
export function isValidUUID(uuid: string): boolean {
  const pattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return pattern.test(uuid);
}

/**
 * Result型ヘルパー
 */
export function Ok<T>(value: T): Result<T, never> {
  return { ok: true, value };
}

export function Err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}
