# SKILL: React Patterns · v2026.11
> Load when: building React components, custom hooks, or React performance work.

## COMPONENT RULES
- Under 150 lines → extract if larger
- Single responsibility
- Props interface typed + exported
- `forwardRef` when wrapping native elements
- Default export for pages, named export for components

## CUSTOM HOOKS
```tsx
// Extract any stateful logic used in 2+ places
function useMessages(roomId: string) {
  const [state, setState] = useState<State>({ data: [], loading: true, error: null })
  useEffect(() => {
    let cancelled = false
    fetchMessages(roomId)
      .then(data => { if (!cancelled) setState({ data, loading: false, error: null }) })
      .catch(error => { if (!cancelled) setState(s => ({ ...s, loading: false, error })) })
    return () => { cancelled = true }  // always cancel on unmount
  }, [roomId])
  return state
}
```

## PERFORMANCE (measure first with React DevTools Profiler)
```tsx
// memo — only for pure presentational components with expensive renders
const MessageBubble = memo(({ message }: { message: Message }) => <Bubble {...message} />)

// useCallback — only when passing to memoized child or as effect dep
const onSend = useCallback((text: string) => mutation.mutate(text), [mutation])

// useMemo — only with Profiler evidence of slowness
// ❌ premature: const sorted = useMemo(() => data.sort(), [data])

// Virtualize large lists
import { useVirtualizer } from '@tanstack/react-virtual'
```

## ERROR BOUNDARIES
```tsx
'use client'  // Next.js
export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  useEffect(() => captureException(error), [error])
  return (
    <div role="alert" className="flex flex-col items-center gap-4 p-8">
      <p className="text-destructive">Something went wrong</p>
      <button onClick={reset} className="btn-primary">Try again</button>
    </div>
  )
}
```

## COMPOSITION PATTERNS
```tsx
// Compound components — flexible, colocated
function Card({ children }: { children: React.ReactNode }) {
  return <div className="card">{children}</div>
}
Card.Header = function CardHeader({ children }: { children: React.ReactNode }) {
  return <div className="card-header">{children}</div>
}
// Usage: <Card><Card.Header>Title</Card.Header>...</Card>

// Render props — for sharing stateful logic (prefer hooks when possible)
// HOC — avoid; use hooks instead
```

## ANTI-PATTERNS
- `useEffect` for data fetching → use TanStack Query or server components
- `useState` for server state → use TanStack Query
- Prop drilling >2 levels → use context or state management
- `any` type anywhere
- `useLayoutEffect` in SSR components → `useEffect` or `suppressHydrationWarning`
- Key as array index for dynamic lists → use stable ID
