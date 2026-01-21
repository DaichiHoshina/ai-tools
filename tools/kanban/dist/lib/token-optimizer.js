"use strict";
/**
 * トークン最適化
 *
 * JSON圧縮・展開によるトークン消費削減
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.compressTask = compressTask;
exports.expandTask = expandTask;
exports.serializeTasks = serializeTasks;
exports.deserializeTasks = deserializeTasks;
exports.estimateTokens = estimateTokens;
exports.calculateCompressionRatio = calculateCompressionRatio;
exports.generateTaskSummary = generateTaskSummary;
exports.renderKanbanBoard = renderKanbanBoard;
exports.renderTaskDetail = renderTaskDetail;
/**
 * タスク圧縮（人間可読 → 圧縮JSON）
 *
 * 既に圧縮形式の場合はそのまま返す
 */
function compressTask(task) {
    // 既に圧縮形式（フィールド名が1文字）
    if ('i' in task && 't' in task) {
        return task;
    }
    // 人間可読形式から圧縮形式へ変換
    // （この関数は互換性のために残すが、実際には全て圧縮形式で扱う）
    return task;
}
function expandTask(task) {
    return {
        id: task.i,
        title: task.t,
        description: task.d,
        status: task.s,
        priority: task.p,
        assigned_to: task.a,
        created_at: task.c,
        updated_at: task.u,
        lock: task.l
            ? {
                agent_id: task.l.a,
                timestamp: task.l.t,
                expires_at: task.l.e
            }
            : undefined,
        metadata: task.m
    };
}
/**
 * タスク配列を圧縮JSON文字列に変換
 *
 * トークン消費を最小化
 */
function serializeTasks(tasks) {
    // 改行・インデントなしの最小JSON
    return JSON.stringify(tasks);
}
/**
 * 圧縮JSON文字列をタスク配列に変換
 */
function deserializeTasks(json) {
    return JSON.parse(json);
}
/**
 * トークン数推定
 *
 * 概算（1トークン ≈ 4文字）
 */
function estimateTokens(text) {
    return Math.ceil(text.length / 4);
}
/**
 * 圧縮効果計算
 *
 * @param original 元のJSON文字列
 * @param compressed 圧縮後のJSON文字列
 * @returns 削減率（0-1の範囲）
 */
function calculateCompressionRatio(original, compressed) {
    if (original.length === 0) {
        return 0;
    }
    return 1 - compressed.length / original.length;
}
/**
 * タスクサマリー生成（トークン節約版）
 *
 * タスク一覧表示時に、詳細情報を省略
 */
function generateTaskSummary(task) {
    const status_emoji = {
        backlog: '📋',
        ready: '✅',
        in_progress: '🔄',
        review: '👀',
        test: '🧪',
        done: '✔️'
    };
    const priority_emoji = {
        low: '🟢',
        medium: '🟡',
        high: '🟠',
        critical: '🔴'
    };
    const lock_status = task.l ? '🔒' : '';
    return `${status_emoji[task.s]} ${priority_emoji[task.p]} ${lock_status} ${task.t}`;
}
/**
 * Kanbanボード描画（ASCII）
 *
 * トークン効率的な表示
 */
function renderKanbanBoard(tasks) {
    const columns = {
        backlog: [],
        ready: [],
        in_progress: [],
        review: [],
        test: [],
        done: []
    };
    // タスクを列ごとに分類
    for (const task of tasks) {
        columns[task.s].push(task);
    }
    const lines = [];
    // ヘッダー
    lines.push('┌──────────┬─────────┬────────────┬─────────┬──────┬──────┐');
    lines.push('│ Backlog  │  Ready  │ In Progress│ Review  │ Test │ Done │');
    lines.push('├──────────┼─────────┼────────────┼─────────┼──────┼──────┤');
    // タスク表示（各列最大5件）
    const max_rows = Math.max(...Object.values(columns).map((col) => Math.min(col.length, 5)));
    for (let i = 0; i < max_rows; i++) {
        const row = [];
        for (const status of ['backlog', 'ready', 'in_progress', 'review', 'test', 'done']) {
            const col_tasks = columns[status];
            if (i < col_tasks.length) {
                const task = col_tasks[i];
                const summary = generateTaskSummary(task);
                row.push(truncate(summary, 10));
            }
            else {
                row.push(' '.repeat(10));
            }
        }
        lines.push(`│${row.join('│')}│`);
    }
    // 省略表示
    for (const status of ['backlog', 'ready', 'in_progress', 'review', 'test', 'done']) {
        const col_tasks = columns[status];
        if (col_tasks.length > 5) {
            lines.push(`│  ...+${col_tasks.length - 5} more`);
        }
    }
    lines.push('└──────────┴─────────┴────────────┴─────────┴──────┴──────┘');
    // 統計
    lines.push('');
    lines.push(`Total: ${tasks.length} tasks`);
    for (const status of ['backlog', 'ready', 'in_progress', 'review', 'test', 'done']) {
        const count = columns[status].length;
        if (count > 0) {
            lines.push(`  ${status}: ${count}`);
        }
    }
    return lines.join('\n');
}
/**
 * 文字列切り詰め
 */
function truncate(text, max_length) {
    if (text.length <= max_length) {
        return text.padEnd(max_length, ' ');
    }
    return text.substring(0, max_length - 1) + '…';
}
/**
 * タスク詳細表示（展開版）
 */
function renderTaskDetail(task) {
    const expanded = expandTask(task);
    const lines = [];
    lines.push(`Task: ${expanded.title}`);
    lines.push(`ID: ${expanded.id}`);
    lines.push(`Status: ${expanded.status}`);
    lines.push(`Priority: ${expanded.priority}`);
    if (expanded.description) {
        lines.push(`Description: ${expanded.description}`);
    }
    if (expanded.assigned_to) {
        lines.push(`Assigned to: ${expanded.assigned_to}`);
    }
    lines.push(`Created: ${new Date(expanded.created_at * 1000).toISOString()}`);
    lines.push(`Updated: ${new Date(expanded.updated_at * 1000).toISOString()}`);
    if (expanded.lock) {
        lines.push(`Lock: ${expanded.lock.agent_id} (expires: ${new Date(expanded.lock.expires_at * 1000).toISOString()})`);
    }
    return lines.join('\n');
}
//# sourceMappingURL=token-optimizer.js.map