/**
 * ユーティリティ関数
 */
import type { Result } from './types';
/**
 * UUIDv4生成
 */
export declare function generateUUID(): string;
/**
 * 現在のUNIXタイムスタンプ取得
 */
export declare function now(): number;
/**
 * 日付フォーマット（YYYY-MM-DD）
 */
export declare function formatDate(timestamp: number): string;
/**
 * JSONファイル読み込み
 */
export declare function readJSON<T>(path: string): Result<T>;
/**
 * JSONファイル書き込み（原子性保証）
 */
export declare function writeJSON<T>(path: string, data: T, pretty?: boolean): Result<void>;
/**
 * ディレクトリ作成（再帰的）
 */
export declare function ensureDir(path: string): Result<void>;
/**
 * 環境変数取得
 */
export declare function getClaudeConfigDir(): string;
/**
 * Kanbanディレクトリパス取得
 */
export declare function getKanbanDir(): string;
/**
 * ボードディレクトリパス取得
 */
export declare function getBoardDir(board_id: string): string;
/**
 * グローバルディレクトリパス取得
 */
export declare function getGlobalDir(): string;
/**
 * Agent ID取得（環境変数 or プロセスID）
 */
export declare function getAgentId(): string;
//# sourceMappingURL=utils.d.ts.map