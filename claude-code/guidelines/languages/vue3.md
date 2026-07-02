# Vue 3 Guidelines

Vue 3.5+ (Composition API + `<script setup>`) + Vite + Vitest. Common guidelines: `~/.claude/guidelines/common/`.

## Core Principles

- **Composition API + `<script setup>`** by default; Options API only when extending legacy code
- **Single File Component (.vue)** with `<script setup lang="ts">` + `<template>` + scoped `<style>`
- **TypeScript strict mode**: explicit `defineProps<T>()` / `defineEmits<T>()` types
- **Reactivity primitives**: `ref` for primitives, `reactive` for objects (prefer `ref` for consistency)
- **No `this`**: setup runs once; refs and reactives drive updates

## Directory Structure

`components/` (presentational) / `composables/` (reusable logic, `use*` prefix) / `store/` (Vuex 4 modules or Pinia stores) / `api/` (HTTP clients) / `lib/` (utilities) / `type/` (shared types).

Per-feature subdirectories (`feature_name/`) hold the entrypoint `.vue` + nested components.

## Reactivity

| API | Use | Note |
|-----|-----|------|
| `ref<T>(v)` | primitives / replace whole object | `.value` access; auto-unwrap in template |
| `reactive(obj)` | nested object whose identity stays fixed | no destructure (loses reactivity) |
| `computed(() => …)` | derived value | cached until deps change |
| `watch(src, cb)` | side effect on change | lazy by default; `{ immediate: true }` to fire on mount |
| `watchEffect(cb)` | auto-tracks reads, fires immediately | use when deps are implicit |
| `shallowRef` / `shallowReactive` | large immutable structures | skip deep tracking for perf |
| `toRefs(reactive)` | destructure-safe access | preserves reactivity |
| `readonly(x)` | expose store state without mutation path | enforce one-way data flow |

## `<script setup>` Quick Reference

| Macro | Purpose |
|-------|---------|
| `defineProps<{ x: string }>()` | typed props |
| `defineEmits<{ (e: 'update', v: T): void }>()` | typed events |
| `defineExpose({ method })` | expose method to parent ref |
| `defineModel<T>()` | two-way binding (Vue 3.4+) |
| `defineSlots<{ default: (props: { x: T }) => any }>()` | typed slots (Vue 3.3+) |

## Component Communication

| Direction | Pattern |
|-----------|---------|
| Parent → Child | `defineProps`; readonly inside child |
| Child → Parent | `defineEmits` + `emit('update', v)` |
| Two-way | `defineModel<T>()` (Vue 3.4+) — replaces `v-model` boilerplate |
| Sibling | shared store (Vuex/Pinia) or provide/inject for DI |
| Deep tree | `provide('key', value)` + `inject<T>('key', default)` (avoid for app state) |

## State Management

| Scope | Recommended |
|-------|-------------|
| Component-local | `ref` / `reactive` inside `<script setup>` |
| Cross-component, small | composable (`useFoo()` returning refs) |
| App-wide store | **Vuex 4** (existing codebases) or **Pinia** (new code; Vuex maintenance mode) |
| Server cache | TanStack Query (vue-query) or hand-rolled composable |

### Vuex 4 vs Pinia

| Aspect | Vuex 4 | Pinia |
|--------|--------|-------|
| Status | Maintenance mode | **Vue official recommendation (new code)** |
| TypeScript | Verbose generics | First-class (auto-inferred) |
| Mutations | Required | Removed (mutate state directly inside actions) |
| Modules | Nested via `modules: { … }` | Flat stores, compose via other `useStore()` calls |
| Devtools | Supported | Supported |

**Migration policy**: do not introduce new Vuex modules — write new stores in Pinia. Existing Vuex modules can stay until touched.

## Composables (`use*`)

Reusable stateful logic. Convention: filename `useFoo.ts`, returns refs / functions.

```ts
export function useCounter(initial = 0) {
  const count = ref(initial)
  const increment = () => count.value++
  return { count, increment }
}
```

Rules:
- Call only at the top of `<script setup>` or inside another composable (not inside `if` / loops)
- Return reactive refs (not raw values) so consumers preserve reactivity
- Clean up side effects via `onBeforeUnmount` / `onScopeDispose`

## Lifecycle

| Hook | Fires | Use |
|------|-------|-----|
| `onMounted` | DOM ready | DOM measure, event listener attach |
| `onUpdated` | after re-render | rarely needed (prefer `watch`) |
| `onBeforeUnmount` | before tear-down | cleanup (timers, listeners) |
| `onErrorCaptured` | child error | error boundary pattern |

## Routing (Vue Router 4)

- Define routes with `createRouter({ history: createWebHistory(), routes })`
- Use `<RouterLink :to="…">` and `<RouterView />` in templates
- Access in setup: `const route = useRoute()`, `const router = useRouter()`
- Lazy load: `component: () => import('./Foo.vue')` for code splitting
- Guard navigation: `router.beforeEach((to, from) => { … })` for auth checks

## Testing (Vitest + @vue/test-utils)

| Pattern | Code | Use |
|---------|------|-----|
| Mount | `mount(Component, { props: { … } })` | full DOM render |
| Shallow | `shallowMount(Component)` | stub child components |
| Async update | `await flushPromises()` / `await wrapper.vm.$nextTick()` | wait for reactivity |
| Emit assert | `expect(wrapper.emitted('update')?.[0]).toEqual([v])` | event tests |
| Mock fetch | `vi.mock('axios')` or MSW | isolate component from API |

Run single file: `vitest run path/to/foo.test.ts`.

## Common Mistakes

| Avoid | Use | Reason |
|-------|-----|--------|
| `const { foo } = reactive({ foo: 1 })` | `const state = reactive({…})` then `state.foo` | destructure breaks reactivity |
| Mutate prop directly | `emit('update', newValue)` | one-way data flow violation |
| `watch(() => state, …)` on `reactive` | `watch(() => state.field, …)` or `{ deep: true }` | top-level watcher fires on every nested change without deep flag |
| `ref.value` access inside template | bare `ref` name | auto-unwrapped in template |
| Heavy `computed` recomputing on unrelated state | split into smaller `computed`s | granular caching |
| `v-for` without `:key` | `:key="item.id"` | reconciliation bugs |
| `v-if` + `v-for` on same element | wrap with `<template v-if>` | `v-for` has higher precedence |
| Manual DOM mutation in `onMounted` | template ref + `ref<HTMLElement>(null)` | reactivity-safe |

## Deprecated Pattern Detection

Check `package.json` `vue` version (Vue 3.x required for this guideline).

### Critical (always flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| Options API (`data()`, `methods:`, `computed:`) | Composition API + `<script setup>` | Vue 3 (Options API still supported, but new code = Composition) |
| `Vue.extend({ … })` | `defineComponent({ … })` or `<script setup>` | Vue 3 |
| Filters (`{{ value \| filter }}`) | `computed` or method call | removed in Vue 3 |
| `$listeners`, `$attrs.listeners` | `$attrs` includes listeners | Vue 3 |
| Event bus (`new Vue()` as bus) | provide/inject or store | removed in Vue 3 |
| `Vue 2 functional component` (`functional: true`) | normal SFC | Vue 3 |
| Vuex 4 new module in greenfield code | Pinia | Vue 3.2+ |

### Warning (proactively flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| `v-model` with `:value` + `@input` boilerplate | `defineModel<T>()` | Vue 3.4 |
| `props.modelValue` + `emit('update:modelValue')` boilerplate | `defineModel<T>()` | Vue 3.4 |
| Manual `withDefaults(defineProps<T>(), {…})` for simple defaults | reactive props destructure (`const { foo = 1 } = defineProps<…>()`) | Vue 3.5+ |
| `ref()` + `.value` ceremony in templates only | template auto-unwrap (no `.value`) | Vue 3 |
| Global `app.component('Foo', Foo)` for every component | local import in `<script setup>` | Vue 3 |
| `this.$refs.foo` (Options API) | template ref `const foo = ref<HTMLElement>(null)` | Vue 3 |

### Info

- Vapor Mode (no Virtual DOM) — experimental, evaluate when stable
- `defineModel` with modifiers (`defineModel({ get, set })`) — Vue 3.4+ refinement

## Performance

- `v-once` / `v-memo` for static or expensive subtrees
- `shallowRef` / `shallowReactive` for large data (skip deep tracking)
- `defineAsyncComponent(() => import('./Foo.vue'))` for code splitting
- Avoid inline functions as `:onclick` handlers in `v-for` (cache miss every render)
- `KeepAlive` for tab-switch UIs (preserves component state, skips remount)

## Tooling

- Build: Vite (HMR, ESM-first, fast cold start)
- Type check: `vue-tsc --noEmit` (TS-in-template) + `tsc --noEmit` (TS-only files)
- Lint: ESLint + `eslint-plugin-vue` + `@typescript-eslint`
- Test: Vitest (Vite-native, `vi.*` API mirrors Jest)
- Devtools: Vue Devtools 7 (Composition API + Pinia + Vuex support)
