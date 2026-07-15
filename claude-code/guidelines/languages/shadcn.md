# shadcn/ui Guidelines

shadcn CLI v4.13.0 (2026-07-03). Common guidelines: `~/.claude/guidelines/common/`.

---

## Core Principles

- **Copy & paste**: place code directly into the project, not an NPM package
- **Customizable**: fully customizable components
- **Accessibility**: WCAG compliant
- **Radix UI + Tailwind**: solid foundation

---

## Concept

shadcn/ui is **a collection of reusable components, not a component library**:
- Install via CLI code copy, not NPM
- Freely customize after placing in the project
- Minimize dependencies

---

## Key Features since v2.5.0 (CLI v4.11.0)

### "Resolve Anywhere"
- Registry can place files anywhere in the app
- Eliminates fixed file structure constraints
- Automates import resolution

### Framework Auto-detection
- CLI auto-detects framework
- Supports Laravel, Vite, React Router
- Automatically adjusts route config

### Tailwind v4 & React 19 Support
- Tailwind CSS v4 implementation
- React 19 support

### Next.js 16 Support
- `init` command supports Next.js 16

---

## Installation

### Initialize
```bash
npx shadcn@latest init
```

Interactive project setup:
- TypeScript/JavaScript
- Style theme
- Base color
- CSS variables usage

### Add Components
```bash
npx shadcn@latest add button
npx shadcn@latest add form
```

---

## Directory Structure

```
src/
├── components/
│   └── ui/          # shadcn/ui components
├── lib/
│   └── utils.ts     # utility functions
```

---

## Key Components

**Form** (React Hook Form + Zod integration):
```tsx
const formSchema = z.object({ username: z.string().min(2).max(50) })
function ProfileForm() {
  const form = useForm<z.infer<typeof formSchema>>({ resolver: zodResolver(formSchema) })
  return <Form {...form}>...</Form>
}
```

**Button** / **Dialog** — switch appearance with variant. Button: `default / destructive / outline / ghost`. Dialog: `DialogTrigger → DialogContent → DialogHeader` structure.

---

## Blocks (v2.5+)

Ready-to-use layouts:
- Dashboard layout
- Authentication pages
- Responsive, accessible, composable

```bash
npx shadcn@latest add login-01
```

---

## Monorepo Support

CLI supports monorepo:
```bash
npx shadcn@latest init --workspace=apps/web
```

---

## MCP Integration (coming soon)

Zero-config MCP support:
```bash
npx shadcn registry:mcp
```

---

## Ecosystem (2026)

### TanCN
TanStack (Query, Table, Form) integration

### FormCN
Form validation focused

### Motion Primitives
Animation integration

---

## Best Practices

### TypeScript
- All components type-safe
- Explicit Props types

### Accessibility
- ARIA attributes auto-added (Radix UI)
- Keyboard navigation support
- Screen reader support

### Dark Mode
```tsx
import { ThemeProvider } from "@/components/theme-provider"

<ThemeProvider attribute="class" defaultTheme="system">
  {children}
</ThemeProvider>
```

### Customization
Components live in the project, so edit them directly:
- Style changes
- Add features
- Add variants

---

## Recommended Stack

- **Next.js 15+** — App Router
- **React 19** — latest features
- **TypeScript** — type safety
- **Tailwind CSS v4** — styling
- **Zod** — validation
- **React Hook Form** — form management
