# Rust Guidelines

Rust 2024 Edition, stable 1.97.0 (2026-07-09). Common guidelines: `~/.claude/guidelines/common/`.

---

## Core Principles

- **Ownership**: follow the borrow checker
- **Zero-cost abstractions**: prioritize performance
- **Safety**: minimize `unsafe`
- **Tools**: `cargo fmt`, `clippy`, `rustfmt` required
- **Idiom-first**: follow official documentation patterns

---

## Directory Structure

- `src/` — source code
  - `main.rs` or `lib.rs`
  - `bin/` — multiple binaries
- `tests/` — integration tests
- `benches/` — benchmarks
- `Cargo.toml` — dependencies

---

## Type System

### Basics
- `struct` — data structures
- `enum` — algebraic data types
- `trait` — interfaces
- `impl` — implementation blocks

### Generics
- `fn process<T: Display>(item: T)` — trait bounds
- `where T: Clone + Send` — complex bounds
- `impl<T> Trait for Type<T>` — blanket impl

---

## Naming Conventions

- **Crate/Module**: `snake_case`
- **Type/Trait**: `PascalCase`
- **Function/Variable**: `snake_case`
- **Constant**: `SCREAMING_SNAKE_CASE`
- **Lifetime**: `'a`, `'static`

---

## Quick Reference

### Error Handling

| Pattern | Code | Use |
|---------|------|-----|
| Result | `fn f() -> Result<T, E>` | recoverable errors |
| Option | `fn find() -> Option<T>` | presence/absence |
| ? operator | `let x = try_fn()?;` | error propagation |
| anyhow | `anyhow::Result<T>` | application errors |
| thiserror | `#[derive(Error)]` | library errors |

### Ownership

| Pattern | Code | Use |
|---------|------|-----|
| Move | `let b = a;` | transfer ownership |
| Borrow | `&value` | immutable reference |
| Mutable borrow | `&mut value` | mutable reference |
| Clone | `value.clone()` | explicit copy |
| Rc/Arc | `Arc::new(data)` | shared ownership |

### Async

| Pattern | Code | Use |
|---------|------|-----|
| async fn | `async fn fetch() -> Result<T>` | async definition |
| await | `result.await?` | async wait |
| spawn | `tokio::spawn(task)` | task creation |
| join | `tokio::join!(a, b)` | concurrent execution |

### Testing

| Pattern | Code | Use |
|---------|------|-----|
| Unit | `#[test] fn test_fn()` | unit test |
| Async | `#[tokio::test]` | async test |
| Expect panic | `#[should_panic]` | panic test |
| Skip | `#[ignore]` | skip |

## Common Mistakes

| Avoid | Use | Reason |
|-------|-----|--------|
| `.unwrap()` overuse | `?` or `expect()` | prevent panic |
| `.clone()` overuse | solve with borrowing | performance |
| Heavy `unsafe` use | safe alternatives | memory safety |
| Return `String` | borrow `&str` | unnecessary allocation |
| Large `enum` | `Box<dyn Trait>` | stack size |

---

## Deprecated Pattern Detection (review / implementation)

Check `Cargo.toml` `edition` and `rust-version` before flagging.

### Critical (always flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| `#[async_trait]` macro (most cases) | native `async fn` in trait (RPITIT) | Edition 2024 |
| Cannot return `impl Trait` (in trait) | `fn f() -> impl Trait` in trait | 1.75 |
| `lazy_static!` macro | `std::sync::LazyLock` / `std::cell::LazyCell` | 1.80 |
| `once_cell::sync::Lazy` | `std::sync::LazyLock` | 1.80 |

### Warning (proactively flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| `Box<dyn Fn()>` closure return | `impl Fn()` return (RPITIT) | 1.75 |
| Nested `if let Some(x) = a { if let Some(y) = b { } }` | `let chains`: `if let Some(x) = a && let Some(y) = b` | Edition 2024 |
| Manual iterator impl | `gen` block (generators) | Edition 2024 |
| `async move \|\| { }` | `async \|\| { }` (async closure stabilized) | Edition 2024 |
| `log` crate | `tracing` crate (structured logging + spans) | recommended |
| `failure` crate | `thiserror` + `anyhow` | recommended |
| `reqwest::blocking` | `reqwest` async + tokio | recommended |
| `println!` debugging | `tracing::debug!` / `dbg!` | recommended |
| Manual `#[derive(Clone, Debug)]` enumeration | use `#[diagnostic]` attribute for improved error messages | 1.80 |

### Info

| Item | Detail | Since |
|------|--------|-------|
| `cargo clippy --fix` | auto-fixes many deprecated patterns | always |
| Edition 2024 migration | `cargo fix --edition` for auto-migration | 2024 |

---

## Recommended Crates

| Category | Crate |
|----------|-------|
| Async | `tokio`, `futures` |
| Web | `axum`, `reqwest`, `serde` |
| Error | `thiserror` (library), `anyhow` (application) |
| CLI | `clap`, `tracing`, `color-eyre` |
