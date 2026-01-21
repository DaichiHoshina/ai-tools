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
    a: string;
    t: number;
    e: number;
}
/**
 * タスク（圧縮JSON形式）
 */
export interface Task {
    i: string;
    t: string;
    d?: string;
    s: TaskStatus;
    p: TaskPriority;
    a?: string;
    c: number;
    u: number;
    l?: Lock;
    m?: Record<string, unknown>;
}
/**
 * ボード設定
 */
export interface BoardConfig {
    id: string;
    name: string;
    project_path: string;
    created_at: number;
    updated_at: number;
    wip_limit: {
        in_progress: number;
    };
    archive_after_days: number;
}
/**
 * アクティブボード（圧縮JSON形式）
 */
export interface ActiveBoard {
    v: string;
    b: string;
    t: Task[];
    u: number;
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
    date: string;
    board_id: string;
    tasks: Task[];
    archived_at: number;
}
/**
 * エラー型
 */
export type KanbanError = {
    type: 'board_not_found';
    board_id: string;
} | {
    type: 'task_not_found';
    task_id: string;
} | {
    type: 'task_locked';
    locked_by: string;
    expires_at: number;
} | {
    type: 'wip_limit_exceeded';
    limit: number;
    current: number;
} | {
    type: 'invalid_transition';
    from: TaskStatus;
    to: TaskStatus;
} | {
    type: 'lock_timeout';
    task_id: string;
} | {
    type: 'file_corruption';
    file: string;
} | {
    type: 'invalid_uuid';
    value: string;
} | {
    type: 'permission_denied';
    file: string;
};
/**
 * Result型（関数型エラーハンドリング）
 */
export type Result<T, E = KanbanError> = {
    ok: true;
    value: T;
} | {
    ok: false;
    error: E;
};
/**
 * ステータス遷移マップ
 */
export declare const STATUS_TRANSITIONS: Record<TaskStatus, TaskStatus[]>;
/**
 * ステータス遷移検証
 */
export declare function isValidTransition(from: TaskStatus, to: TaskStatus): boolean;
/**
 * UUIDv4検証
 */
export declare function isValidUUID(uuid: string): boolean;
/**
 * Result型ヘルパー
 */
export declare function Ok<T>(value: T): Result<T, never>;
export declare function Err<E>(error: E): Result<never, E>;
//# sourceMappingURL=types.d.ts.map