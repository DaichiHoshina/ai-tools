/**
 * トークン最適化
 *
 * JSON圧縮・展開によるトークン消費削減
 */
import type { Task, TaskStatus, TaskPriority } from './types';
/**
 * タスク圧縮（人間可読 → 圧縮JSON）
 *
 * 既に圧縮形式の場合はそのまま返す
 */
export declare function compressTask(task: Task): Task;
/**
 * タスク展開（圧縮JSON → 人間可読）
 *
 * 表示用に展開
 */
export interface ExpandedTask {
    id: string;
    title: string;
    description?: string;
    status: TaskStatus;
    priority: TaskPriority;
    assigned_to?: string;
    created_at: number;
    updated_at: number;
    lock?: {
        agent_id: string;
        timestamp: number;
        expires_at: number;
    };
    metadata?: Record<string, unknown>;
}
export declare function expandTask(task: Task): ExpandedTask;
/**
 * タスク配列を圧縮JSON文字列に変換
 *
 * トークン消費を最小化
 */
export declare function serializeTasks(tasks: Task[]): string;
/**
 * 圧縮JSON文字列をタスク配列に変換
 */
export declare function deserializeTasks(json: string): Task[];
/**
 * トークン数推定
 *
 * 概算（1トークン ≈ 4文字）
 */
export declare function estimateTokens(text: string): number;
/**
 * 圧縮効果計算
 *
 * @param original 元のJSON文字列
 * @param compressed 圧縮後のJSON文字列
 * @returns 削減率（0-1の範囲）
 */
export declare function calculateCompressionRatio(original: string, compressed: string): number;
/**
 * タスクサマリー生成（トークン節約版）
 *
 * タスク一覧表示時に、詳細情報を省略
 */
export declare function generateTaskSummary(task: Task): string;
/**
 * Kanbanボード描画（ASCII）
 *
 * トークン効率的な表示
 */
export declare function renderKanbanBoard(tasks: Task[]): string;
/**
 * タスク詳細表示（展開版）
 */
export declare function renderTaskDetail(task: Task): string;
//# sourceMappingURL=token-optimizer.d.ts.map