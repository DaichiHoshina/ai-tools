/**
 * ボード管理
 *
 * Kanbanボードの作成・読み込み・更新
 */
import type { Result, BoardConfig, Task, TaskStatus, TaskPriority, GlobalIndex } from './types';
/**
 * ボード初期化
 *
 * @param name ボード名
 * @param project_path プロジェクトパス
 * @returns ボードID or エラー
 */
export declare function initBoard(name: string, project_path: string): Result<string>;
/**
 * タスク追加
 *
 * @param board_id ボードID
 * @param title タスクタイトル
 * @param options オプション
 * @returns タスクID or エラー
 */
export declare function addTask(board_id: string, title: string, options?: {
    description?: string;
    priority?: TaskPriority;
    status?: TaskStatus;
}): Result<string>;
/**
 * タスク取得
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns タスク or エラー
 */
export declare function getTask(board_id: string, task_id: string): Result<Task>;
/**
 * タスク一覧取得
 *
 * @param board_id ボードID
 * @param filter フィルタ
 * @returns タスク一覧 or エラー
 */
export declare function listTasks(board_id: string, filter?: {
    status?: TaskStatus;
    priority?: TaskPriority;
}): Result<Task[]>;
/**
 * タスクステータス更新
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param new_status 新しいステータス
 * @param agent_id エージェントID（省略時は自動取得）
 * @returns 成功 or エラー
 */
export declare function updateTaskStatus(board_id: string, task_id: string, new_status: TaskStatus, agent_id?: string): Result<void>;
/**
 * タスク更新
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param updates 更新内容
 * @returns 成功 or エラー
 */
export declare function updateTask(board_id: string, task_id: string, updates: {
    title?: string;
    description?: string;
    priority?: TaskPriority;
    assigned_to?: string;
}): Result<void>;
/**
 * ボード情報取得
 *
 * @param board_id ボードID
 * @returns ボード情報 or エラー
 */
export declare function getBoardInfo(board_id: string): Result<BoardConfig>;
/**
 * 全ボード一覧取得
 */
export declare function listBoards(): Result<GlobalIndex>;
/**
 * プロジェクトパスからボード検索
 */
export declare function findBoardByProject(project_path: string): Result<string | null>;
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
export declare function getBoardStatus(board_id: string): Result<BoardStatus>;
/**
 * 次のタスク提案
 *
 * WIP制限を考慮して、次に着手すべきタスクを提案
 *
 * @param board_id ボードID
 * @returns 次のタスク or null（タスクがない場合）
 */
export declare function getNextTask(board_id: string): Result<Task | null>;
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
export declare function splitTask(board_id: string, task_id: string, subtasks: Array<{
    title: string;
    priority?: TaskPriority;
}>): Result<string[]>;
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
export declare function getBoardProgress(board_id: string): Result<ProgressReport>;
/**
 * タスクをブロック状態に設定
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param reason ブロック理由
 * @returns 成功 or エラー
 */
export declare function blockTask(board_id: string, task_id: string, reason: string): Result<void>;
/**
 * タスクのブロック解除
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns 成功 or エラー
 */
export declare function unblockTask(board_id: string, task_id: string): Result<void>;
//# sourceMappingURL=board-manager.d.ts.map