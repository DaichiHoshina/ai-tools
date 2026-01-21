/**
 * ロック管理
 *
 * Sub agent間のタスク衝突を回避するためのロック機構
 */
import type { Result, Lock } from './types';
/**
 * ロック取得
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param agent_id エージェントID（省略時は自動取得）
 * @param timeout タイムアウト秒数（省略時は1時間）
 * @returns ロック情報 or エラー
 */
export declare function acquireLock(board_id: string, task_id: string, agent_id?: string, timeout?: number): Result<Lock>;
/**
 * ロック解放
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @param agent_id エージェントID（省略時は自動取得）
 * @returns 成功 or エラー
 */
export declare function releaseLock(board_id: string, task_id: string, agent_id?: string): Result<void>;
/**
 * ロック状態確認
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns ロック情報（ロックされていない場合はnull）
 */
export declare function checkLock(board_id: string, task_id: string): Result<Lock | null>;
/**
 * 期限切れロック一括解放
 *
 * @param board_id ボードID
 * @returns 解放したタスク数
 */
export declare function cleanupExpiredLocks(board_id: string): Result<number>;
//# sourceMappingURL=lock-manager.d.ts.map