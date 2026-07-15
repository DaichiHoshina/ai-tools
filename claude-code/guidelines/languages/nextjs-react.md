# Next.js / React Guidelines

Next.js 16.3 (2026-06-29) + React 19.2.7 (2026-06-01). Common guidelines: `~/.claude/guidelines/common/`.

16.2 で導入・16.3 継続: React Compiler stable (auto-memoization), Turbopack Server Fast Refresh, Web Worker Origin for WASM, Subresource Integrity。16.3: Turbopack 最適化 / Instant Navigations。

## Core Principles

- **Server Components First**: Server Component by default
- **Client Component**: minimize `'use client'` (only when interaction is required)
- **Concurrent Rendering**: enabled by default in React 19
- **React Compiler**: auto-optimization eliminates most `useMemo`/`useCallback` needs
- **Type safety**: explicit types for Props and event handlers

## Directory Structure

`app/` (App Router, API Routes) / `features/` (domain/application/presentation) / `shared/` (common).

## Quick Reference

### Component Types

| Type | Use | Characteristics |
|------|-----|-----------------|
| Server Component | data fetching, static rendering | async/await support, default |
| Client Component | interaction, state | `'use client'` required |
| Server Action | mutations | `'use server'` |

### Common Hooks

| Hook | Use | Constraint |
|------|-----|------------|
| `useState` | local state | Client only |
| `useEffect` | side effects | Client only |
| `use()` | streaming data | Server/Client both |
| `useActionState` | Server Action state | React 19+ |
| `useOptimistic` | optimistic UI | React 19+ |

### Data Fetching

| Method | Use | Cache |
|--------|-----|-------|
| `fetch()` | Server Component | enabled by default |
| TanStack Query | Client Component | auto-managed |
| Server Actions | mutations | `revalidatePath()` |

## Common Mistakes

| Avoid | Use | Reason |
|-------|-----|--------|
| `ssr: false` in Server Component | normal `import` | error in Next.js 15+ |
| `dynamic(..., {ssr: false})` in Client Component | normal `import` | redundant |
| Direct `process.env.NEXT_PUBLIC_*` in functions | via config file | statically replaced at build time |
| Context for global state | Zustand/Jotai | performance |
| `useEffect` for data fetching | Server Component or TanStack Query | handle server-side |

## Deprecated Pattern Detection

Check `package.json` `next`/`react` version before flagging.

### Critical (always flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| `pages/` (Pages Router) | `app/` (App Router) | Next 13 |
| `getServerSideProps`/`getStaticProps` | direct `fetch`/DB in Server Component | Next 13 |
| `getInitialProps` | Server Component or Server Actions | Next 13 |
| class component | function component + Hooks | React 16.8 |
| `next/router` | `next/navigation` (`useRouter`/`usePathname`) | Next 13 |
| `next.config.js` | `next.config.ts` | Next 15 |

### Warning (proactively flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| Heavy `useMemo`/`useCallback` use | React Compiler auto-optimization | React 19 |
| `useFormState` | `useActionState` | React 19 |
| `forwardRef` | accept `ref` directly as prop | React 19 |
| `<Context.Provider>` | provide directly via `<Context>` | React 19 |
| `useContext(Ctx)` | `use(Ctx)` | React 19 |
| Resolve Promise in `useEffect` | `use(promise)` inside render | React 19 |
| `next/head` | `export const metadata` (App Router) | Next 13 |
| Proxy in `middleware.ts` | `proxy.ts` (clear network boundary) | Next 16 |
| Manual cache control | `"use cache"` directive | Next 16 |
| CSS-in-JS (styled-components etc.) | Tailwind / CSS Modules | Next 13+ (RSC incompatible) |

### Info

| Item | Detail | Since |
|------|--------|-------|
| Activity Component | `<Activity mode="hidden">` for show/hide control | React 19.2 |
| useEffectEvent | separate non-reactive logic from effects | React 19.2 |
| View Transitions | navigation animations | Next 16 |

## Component Design

### Server Components (default)

- Use async/await directly
- Execute DB/API calls server-side
- Use `use()` Hook for streaming data

### Client Components (only when needed)

`'use client'` required when:
- state / events (`onClick`, `onChange`)
- lifecycle (`useEffect`)
- browser APIs (`localStorage`, `window`)

Strategy: small Client Islands; only leaf components as Client.

### dynamic import

- In general: `'use client'` files do not need `dynamic` + `ssr: false` (already client-executed)
- Next.js 15+: `ssr: false` in Server Component is an error
- Recommended: normal `import` (inside Client) / `dynamic()` for code splitting (no `ssr: false`)

## State Management

| Type | Recommended |
|------|-------------|
| Server State | TanStack Query (cache, revalidation, optimistic updates) |
| Local UI | `useState` |
| Complex local | `useReducer` |
| Global | Zustand/Jotai (minimal) |
| Static values (DI, theme) | Context |

## Data Fetching (Next.js 15-16)

### Cache Configuration

- `export const dynamic = 'force-dynamic'` — force SSR
- `export const revalidate = 60` — ISR (60 seconds)
- `fetch(..., { next: { revalidate: 3600 } })` — per-request

### Server Actions

Mutations via `'use server'`. Revalidate with `revalidatePath()` / `revalidateTag()`.

### Error Handling

`error.tsx` (error boundary) / `loading.tsx` (Suspense loading) / `not-found.tsx` (404).

## Environment Variables

Do not reference `process.env.NEXT_PUBLIC_*` directly inside function scope (may not embed due to Next.js static replacement at build time).

Recommended: centralize in `src/config/*.ts`.

```ts
export const appConfig = {
  apiUrl: process.env.NEXT_PUBLIC_API_URL ?? ""
} as const
```

## Forms (React 19)

New Hooks: `useActionState` (form processing + state) / `useFormStatus` (submit state) / `useOptimistic` (optimistic updates).

Recommended libraries: React Hook Form + zod / Conform (Server Actions integration).

## Security

CVE-2025-55182 (React2Shell) addressed (19.0.3/19.1.4/19.2.3).

## Performance

- Next.js: `next/image` (image optimization) / `revalidateTag()` (cache strategy) / `export const runtime = 'edge'` (global speed) / Turbopack (5-10x build speedup)
- React 19: `useTransition` (smooth UX) / Concurrent Rendering (prevent UI freeze)

## Hooks Rules

Top-level only (forbidden inside conditions/loops) / inside React functions only / accurate dependency arrays (follow ESLint warnings).

## Type Definitions

### Props

```ts
type Props = {
  title: string
  children: React.ReactNode
  onClick?: () => void
}
```

### Event Handlers

`React.MouseEvent<HTMLButtonElement>` / `React.FormEvent<HTMLFormElement>` / `React.ChangeEvent<HTMLInputElement>`

### Ref

```ts
useRef<HTMLDivElement>(null)
```
