#!/usr/bin/env node
/**
 * Kanban CLI
 *
 * コマンドラインインターフェース
 */

import { initBoard, addTask, listTasks, updateTaskStatus, getBoardInfo, listBoards, findBoardByProject, getBoardStatus, getNextTask, splitTask, getBoardProgress, blockTask, unblockTask } from './lib/board-manager';
import { acquireLock, releaseLock, cleanupExpiredLocks } from './lib/lock-manager';
import { autoArchive, getArchivedTasks, restoreTask, getArchiveSummary } from './lib/archive-manager';
import { renderKanbanBoard, renderTaskDetail } from './lib/token-optimizer';
import type { TaskPriority, TaskStatus } from './lib/types';

const args = process.argv.slice(2);
const command = args[0];

/**
 * エラー表示
 */
function error(message: string): never {
  console.error(`Error: ${message}`);
  process.exit(1);
}

/**
 * 成功表示
 */
function success(message: string): void {
  console.log(message);
  process.exit(0);
}

/**
 * 現在のプロジェクトパス取得
 */
function getCurrentProjectPath(): string {
  return process.cwd();
}

/**
 * 現在のボードID取得
 */
function getCurrentBoardId(): string {
  const project_path = getCurrentProjectPath();
  const result = findBoardByProject(project_path);

  if (!result.ok) {
    error(`Failed to find board: ${JSON.stringify(result.error)}`);
  }

  if (!result.value) {
    error('No board found for current project. Run: kanban init');
  }

  return result.value;
}

/**
 * コマンド実行
 */
async function main(): Promise<void> {
  if (!command) {
    console.log('Usage: kanban <command> [options]');
    console.log('');
    console.log('Commands:');
    console.log('  init [name]                    Initialize new board');
    console.log('  auto-init                      Auto initialize (check if exists)');
    console.log('  add <title> [options]          Add task');
    console.log('  list [--status=<status>]       List tasks');
    console.log('  start <task_id>                Start task (move to In Progress)');
    console.log('  move <task_id> <status>        Move task to status');
    console.log('  done <task_id>                 Complete task');
    console.log('  show <task_id>                 Show task details');
    console.log('  boards                         List all boards');
    console.log('  archive [--date=<YYYY-MM-DD>]  Show archived tasks');
    console.log('  cleanup                        Cleanup expired locks');
    console.log('');
    console.log('Advanced Commands (for complex projects):');
    console.log('  status                         Show detailed board status');
    console.log('  next                           Suggest next task (WIP=1)');
    console.log('  progress                       Show progress report');
    console.log('  split <task_id>                Split task into subtasks');
    console.log('  block <task_id> <reason>       Mark task as blocked');
    console.log('  unblock <task_id>              Unblock task');
    process.exit(0);
  }

  switch (command) {
    case 'init': {
      const name = args[1] ?? 'Default Board';
      const project_path = getCurrentProjectPath();
      const result = initBoard(name, project_path);

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      success(`Board initialized: ${result.value}`);
      break;
    }

    case 'add': {
      const title = args[1];
      if (!title) {
        error('Title is required');
      }

      const board_id = getCurrentBoardId();

      // オプション解析
      const priority = (args.find((a) => a.startsWith('--priority='))?.split('=')[1] as TaskPriority) ?? 'medium';
      const description = args.find((a) => a.startsWith('--description='))?.split('=')[1];

      const result = addTask(board_id, title, { priority, description });

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      success(`Task added: ${result.value}`);
      break;
    }

    case 'list': {
      const board_id = getCurrentBoardId();

      // フィルタ解析
      const status = args.find((a) => a.startsWith('--status='))?.split('=')[1] as TaskStatus | undefined;

      const result = listTasks(board_id, status ? { status } : undefined);

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      if (result.value.length === 0) {
        console.log('No tasks found');
        process.exit(0);
      }

      const board = renderKanbanBoard(result.value);
      console.log(board);
      process.exit(0);
      break;
    }

    case 'start': {
      const task_id = args[1];
      if (!task_id) {
        error('Task ID is required');
      }

      const board_id = getCurrentBoardId();
      const result = updateTaskStatus(board_id, task_id, 'in_progress');

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      success('Task started');
      break;
    }

    case 'move': {
      const task_id = args[1];
      const status = args[2] as TaskStatus;

      if (!task_id || !status) {
        error('Task ID and status are required');
      }

      const board_id = getCurrentBoardId();
      const result = updateTaskStatus(board_id, task_id, status);

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      success(`Task moved to ${status}`);
      break;
    }

    case 'done': {
      const task_id = args[1];
      if (!task_id) {
        error('Task ID is required');
      }

      const board_id = getCurrentBoardId();
      const result = updateTaskStatus(board_id, task_id, 'done');

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      success('Task completed');
      break;
    }

    case 'show': {
      const task_id = args[1];
      if (!task_id) {
        error('Task ID is required');
      }

      const board_id = getCurrentBoardId();
      const tasks_result = listTasks(board_id);

      if (!tasks_result.ok) {
        error(JSON.stringify(tasks_result.error));
      }

      const task = tasks_result.value.find((t) => t.i === task_id);
      if (!task) {
        error('Task not found');
      }

      const detail = renderTaskDetail(task);
      console.log(detail);
      process.exit(0);
      break;
    }

    case 'boards': {
      const result = listBoards();

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      if (result.value.boards.length === 0) {
        console.log('No boards found');
        process.exit(0);
      }

      console.log('Boards:');
      for (const board of result.value.boards) {
        console.log(`  ${board.name} (${board.id})`);
        console.log(`    Project: ${board.project_path}`);
        console.log(`    Tasks: ${board.task_count}`);
        console.log('');
      }
      process.exit(0);
      break;
    }

    case 'archive': {
      const board_id = getCurrentBoardId();
      const date = args.find((a) => a.startsWith('--date='))?.split('=')[1];

      const tasks_result = getArchivedTasks(board_id, date);

      if (!tasks_result.ok) {
        error(JSON.stringify(tasks_result.error));
      }

      if (tasks_result.value.length === 0) {
        console.log('No archived tasks found');
        process.exit(0);
      }

      console.log(`Archived tasks${date ? ` (${date})` : ''}:`);
      for (const task of tasks_result.value) {
        console.log(`  [${task.i}] ${task.t} (${task.s})`);
      }

      // サマリー表示
      const summary_result = getArchiveSummary(board_id);
      if (summary_result.ok) {
        const summary = summary_result.value;
        console.log('');
        console.log('Summary:');
        console.log(`  Total files: ${summary.total_files}`);
        console.log(`  Total tasks: ${summary.total_tasks}`);
        if (summary.oldest_date) {
          console.log(`  Oldest: ${summary.oldest_date}`);
        }
        if (summary.newest_date) {
          console.log(`  Newest: ${summary.newest_date}`);
        }
      }

      process.exit(0);
      break;
    }

    case 'cleanup': {
      const board_id = getCurrentBoardId();
      const result = cleanupExpiredLocks(board_id);

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      success(`Cleaned up ${result.value} expired locks`);
      break;
    }

    case 'auto-init': {
      const project_path = getCurrentProjectPath();
      const board_result = findBoardByProject(project_path);

      if (!board_result.ok) {
        error(JSON.stringify(board_result.error));
      }

      if (board_result.value) {
        console.log(`Board already exists: ${board_result.value}`);
        process.exit(0);
      }

      // ボード作成
      const name = args[1] ?? `Board-${Date.now()}`;
      const init_result = initBoard(name, project_path);

      if (!init_result.ok) {
        error(JSON.stringify(init_result.error));
      }

      success(`Board initialized: ${init_result.value}`);
      break;
    }

    case 'status': {
      const board_id = getCurrentBoardId();
      const result = getBoardStatus(board_id);

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      const status = result.value;

      console.log('=== Board Status ===');
      console.log(`Board: ${status.board_name} (${status.board_id})`);
      console.log(`Project: ${status.project_path}`);
      console.log('');
      console.log('Progress:');
      console.log(`  ${status.task_counts.done}/${status.total_tasks} tasks completed (${status.progress_percentage}%)`);
      console.log('');
      console.log('Tasks by Status:');
      console.log(`  Backlog: ${status.task_counts.backlog}`);
      console.log(`  Ready: ${status.task_counts.ready}`);
      console.log(`  In Progress: ${status.task_counts.in_progress} / ${status.wip_limit} (WIP limit)`);
      console.log(`  Review: ${status.task_counts.review}`);
      console.log(`  Test: ${status.task_counts.test}`);
      console.log(`  Done: ${status.task_counts.done}`);
      console.log('');
      console.log(`Locked tasks: ${status.locked_tasks}`);
      console.log(`Blocked tasks: ${status.blocked_tasks}`);

      if (status.next_task_id) {
        console.log('');
        console.log(`Next task: ${status.next_task_id}`);
      }

      process.exit(0);
      break;
    }

    case 'next': {
      const board_id = getCurrentBoardId();
      const result = getNextTask(board_id);

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      if (!result.value) {
        console.log('No task available (WIP=1 or no tasks)');
        process.exit(0);
      }

      const task = result.value;
      console.log('Next task:');
      console.log(`  ID: ${task.i}`);
      console.log(`  Title: ${task.t}`);
      console.log(`  Status: ${task.s}`);
      console.log(`  Priority: ${task.p}`);

      if (task.d) {
        console.log(`  Description: ${task.d}`);
      }

      console.log('');
      console.log(`Run: kanban start ${task.i}`);

      process.exit(0);
      break;
    }

    case 'progress': {
      const board_id = getCurrentBoardId();
      const result = getBoardProgress(board_id);

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      const progress = result.value;

      console.log('=== Progress Report ===');
      console.log(`Board: ${progress.board_name}`);
      console.log('');
      console.log('Overall:');
      console.log(`  ${progress.completed_tasks}/${progress.total_tasks} tasks completed (${progress.progress_percentage}%)`);
      console.log(`  Remaining: ${progress.estimated_remaining_tasks} tasks`);
      console.log('');
      console.log('By Status:');
      for (const [status, count] of Object.entries(progress.by_status)) {
        if (count > 0) {
          console.log(`  ${status}: ${count}`);
        }
      }
      console.log('');
      console.log('By Priority:');
      for (const [priority, count] of Object.entries(progress.by_priority)) {
        if (count > 0) {
          console.log(`  ${priority}: ${count}`);
        }
      }

      process.exit(0);
      break;
    }

    case 'split': {
      const task_id = args[1];
      if (!task_id) {
        error('Task ID is required');
      }

      // サブタスク数を取得（デフォルト3）
      const count = parseInt(args[2] ?? '3', 10);

      if (count < 2 || count > 10) {
        error('Subtask count must be between 2 and 10');
      }

      const board_id = getCurrentBoardId();

      // サブタスク名を生成
      const subtasks = [];
      for (let i = 1; i <= count; i++) {
        subtasks.push({
          title: `Subtask ${i}`,
          priority: 'medium' as TaskPriority
        });
      }

      const result = splitTask(board_id, task_id, subtasks);

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      console.log(`Task split into ${count} subtasks:`);
      for (const id of result.value) {
        console.log(`  ${id}`);
      }

      success('Task split successfully');
      break;
    }

    case 'block': {
      const task_id = args[1];
      const reason = args.slice(2).join(' ');

      if (!task_id || !reason) {
        error('Task ID and reason are required');
      }

      const board_id = getCurrentBoardId();
      const result = blockTask(board_id, task_id, reason);

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      success(`Task blocked: ${reason}`);
      break;
    }

    case 'unblock': {
      const task_id = args[1];

      if (!task_id) {
        error('Task ID is required');
      }

      const board_id = getCurrentBoardId();
      const result = unblockTask(board_id, task_id);

      if (!result.ok) {
        error(JSON.stringify(result.error));
      }

      success('Task unblocked');
      break;
    }

    default:
      error(`Unknown command: ${command}`);
  }
}

main().catch((err) => {
  error(err.message);
});
