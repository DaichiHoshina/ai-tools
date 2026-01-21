"use strict";
/**
 * Kanban システム型定義
 *
 * 圧縮JSON対応のため、フィールド名を短縮
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.STATUS_TRANSITIONS = void 0;
exports.isValidTransition = isValidTransition;
exports.isValidUUID = isValidUUID;
exports.Ok = Ok;
exports.Err = Err;
/**
 * ステータス遷移マップ
 */
exports.STATUS_TRANSITIONS = {
    backlog: ['ready', 'in_progress'],
    ready: ['backlog', 'in_progress'],
    in_progress: ['ready', 'review', 'test', 'done'],
    review: ['in_progress', 'test', 'done'],
    test: ['review', 'done'],
    done: ['backlog', 'ready'] // 再オープン可能
};
/**
 * ステータス遷移検証
 */
function isValidTransition(from, to) {
    return exports.STATUS_TRANSITIONS[from].includes(to);
}
/**
 * UUIDv4検証
 */
function isValidUUID(uuid) {
    const pattern = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return pattern.test(uuid);
}
/**
 * Result型ヘルパー
 */
function Ok(value) {
    return { ok: true, value };
}
function Err(error) {
    return { ok: false, error };
}
//# sourceMappingURL=types.js.map