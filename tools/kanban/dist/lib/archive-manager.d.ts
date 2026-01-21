/**
 * アーカイブ管理
 *
 * 完了タスクの自動アーカイブによるトークン最適化
 */
import type { Result, Task } from './types';
/**
 * 自動アーカイブ実行
 *
 * 完了後、指定日数経過したタスクをアーカイブに移動
 *
 * @param board_id ボードID
 * @returns アーカイブしたタスク数 or エラー
 */
export declare function autoArchive(board_id: string): Result<number>;
/**
 * アーカイブからタスク取得
 *
 * @param board_id ボードID
 * @param date 日付（YYYY-MM-DD形式、省略時は全日付）
 * @returns アーカイブタスク or エラー
 */
export declare function getArchivedTasks(board_id: string, date?: string): Result<Task[]>;
/**
 * アーカイブからタスク復元
 *
 * @param board_id ボードID
 * @param task_id タスクID
 * @returns 成功 or エラー
 */
export declare function restoreTask(board_id: string, task_id: string): Result<void>;
/**
 * アーカイブサマリー取得
 *
 * @param board_id ボードID
 * @returns サマリー情報 or エラー
 */
export declare function getArchiveSummary(board_id: string): Result<{
    total_files: number;
    total_tasks: number;
    oldest_date: string | null;
    newest_date: string | null;
}>;
//# sourceMappingURL=archive-manager.d.ts.map