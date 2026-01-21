/**
 * ユーティリティ関数
 */

import { randomUUID } from 'crypto';
import { readFileSync, writeFileSync, existsSync, mkdirSync, renameSync } from 'fs';
import { dirname } from 'path';
import type { Result } from './types';
import { Ok, Err } from './types';

/**
 * UUIDv4生成
 */
export function generateUUID(): string {
  return randomUUID();
}

/**
 * 現在のUNIXタイムスタンプ取得
 */
export function now(): number {
  return Math.floor(Date.now() / 1000);
}

/**
 * 日付フォーマット（YYYY-MM-DD）
 */
export function formatDate(timestamp: number): string {
  const date = new Date(timestamp * 1000);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * JSONファイル読み込み
 */
export function readJSON<T>(path: string): Result<T> {
  try {
    if (!existsSync(path)) {
      return Err({ type: 'board_not_found' as const, board_id: path });
    }
    const content = readFileSync(path, 'utf-8');
    const data = JSON.parse(content) as T;
    return Ok(data);
  } catch (error) {
    return Err({ type: 'file_corruption' as const, file: path });
  }
}

/**
 * JSONファイル書き込み（原子性保証）
 */
export function writeJSON<T>(path: string, data: T, pretty = false): Result<void> {
  try {
    // ディレクトリが存在しない場合は作成
    const dir = dirname(path);
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }

    // 一時ファイルに書き込み
    const tmp = `${path}.tmp.${process.pid}`;
    const content = pretty ? JSON.stringify(data, null, 2) : JSON.stringify(data);
    writeFileSync(tmp, content, 'utf-8');

    // 原子的にリネーム（POSIXではmvは原子的）
    renameSync(tmp, path);

    return Ok(undefined);
  } catch (error) {
    return Err({ type: 'permission_denied' as const, file: path });
  }
}

/**
 * ディレクトリ作成（再帰的）
 */
export function ensureDir(path: string): Result<void> {
  try {
    if (!existsSync(path)) {
      mkdirSync(path, { recursive: true });
    }
    return Ok(undefined);
  } catch (error) {
    return Err({ type: 'permission_denied' as const, file: path });
  }
}

/**
 * 環境変数取得
 */
export function getClaudeConfigDir(): string {
  const home = process.env.HOME ?? process.env.USERPROFILE;
  if (!home) {
    throw new Error('HOME environment variable not set');
  }
  return `${home}/.config/claude`;
}

/**
 * Kanbanディレクトリパス取得
 */
export function getKanbanDir(): string {
  return `${getClaudeConfigDir()}/kanban`;
}

/**
 * ボードディレクトリパス取得
 */
export function getBoardDir(board_id: string): string {
  return `${getKanbanDir()}/boards/project-${board_id}`;
}

/**
 * グローバルディレクトリパス取得
 */
export function getGlobalDir(): string {
  return `${getKanbanDir()}/boards/global`;
}

/**
 * Agent ID取得（環境変数 or プロセスID）
 */
export function getAgentId(): string {
  return process.env.AGENT_ID ?? `claude-${process.pid}`;
}
