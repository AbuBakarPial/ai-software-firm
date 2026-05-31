# SKILL: TanStack · v2026.11
> Load when: TanStack Query (React Query v5), Router, Form, or Table work.
> Install: `npx @tanstack/intent install` (auto-wires from node_modules) or add `@tanstack/react-query` manually.

## DETECT FIRST
```bash
cat package.json | grep -E '"@tanstack/react-query|"@tanstack/react-router|"@tanstack/react-form|"@tanstack/react-table"'
cat package.json | grep -E '"@tanstack/vue-query|"@tanstack/solid-query|"@tanstack/svelte-query"'
ls src/queries src/hooks src/api 2>/dev/null
```

## QUERY — FUNDAMENTALS

### Core config (app-wide)
```tsx
// Always configure QueryClient with sane defaults
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,       // 30s — don't refetch same data on every mount
      gcTime: 5 * 60_000,     // 5min — keep in cache after unmount
      retry: 2,                // retry twice on failure
      retryDelay: (attempt) => Math.min(1000 * 2 ** attempt, 10_000),
      refetchOnWindowFocus: false,  // opt-in, not default
    },
    mutations: {
      retry: 0,                // mutations: never retry automatically (user-facing)
    },
  },
});

function Providers({ children }: { children: ReactNode }) {
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}
```

### Standard query
```tsx
const { data, isLoading, error } = useQuery({
  queryKey: ['messages', roomId],
  queryFn: () => fetchMessages(roomId),
  staleTime: 10_000,
  // enabled: !!roomId,        // skip if no room
  select: (data) => data.sort((a, b) => b.createdAt - a.createdAt), // transform
});
```

### Dependent / parallel queries
```tsx
// Parallel — just call twice, they run concurrently
const users = useQuery({ queryKey: ['users'], queryFn: fetchUsers });
const settings = useQuery({ queryKey: ['settings'], queryFn: fetchSettings });

// Dependent — enabled only after first resolves
const user = useQuery({ queryKey: ['user', userId], queryFn: () => fetchUser(userId) });
const posts = useQuery({
  queryKey: ['posts', user.data?.id],
  queryFn: () => fetchPostsByUser(user.data!.id),
  enabled: !!user.data,       // waits for user
});
```

## INFINITE QUERIES — cursor/offset pagination
```tsx
function MessageList() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteQuery({
    queryKey: ['messages', roomId],
    queryFn: ({ pageParam }) => fetchMessages(roomId, pageParam),
    initialPageParam: undefined as string | undefined,
    getNextPageParam: (lastPage) => lastPage.nextCursor,
  });

  // Flat list from pages
  const messages = useMemo(() => data?.pages.flatMap(p => p.items) ?? [], [data]);

  return (
    <div>
      {messages.map(msg => <MessageItem key={msg.id} msg={msg} />)}
      <button onClick={() => fetchNextPage()} disabled={!hasNextPage || isFetchingNextPage}>
        {isFetchingNextPage ? 'Loading...' : hasNextPage ? 'Load more' : 'All loaded'}
      </button>
    </div>
  );
}
```

## OPTIMISTIC MUTATIONS
```tsx
const mutation = useMutation({
  mutationFn: addMessage,
  onMutate: async (newMsg) => {
    // Cancel outgoing refetches (so they don't overwrite)
    await queryClient.cancelQueries({ queryKey: ['messages', roomId] });
    // Snapshot previous value
    const previous = queryClient.getQueryData(['messages', roomId]);
    // Optimistically update
    queryClient.setQueryData(['messages', roomId], (old) => ({
      ...old,
      pages: old.pages.map((page, i) =>
        i === 0 ? { ...page, items: [newMsg, ...page.items] } : page
      ),
    }));
    return { previous };
  },
  onError: (_, __, context) => {
    // Rollback on error
    queryClient.setQueryData(['messages', roomId], context?.previous);
  },
  onSettled: () => {
    // Always refetch after mutation settles
    queryClient.invalidateQueries({ queryKey: ['messages', roomId] });
  },
});
```

## QUERY INVALIDATION STRATEGIES
```tsx
// Precise invalidation — best for performance
queryClient.invalidateQueries({ queryKey: ['messages', roomId] });

// Refetch exact match only (no fuzzy match)
queryClient.refetchQueries({ queryKey: ['messages', roomId], exact: true });

// Remove from cache
queryClient.removeQueries({ queryKey: ['stale-data'] });

// Reset to initial state
queryClient.resetQueries({ queryKey: ['form-state'] });
```

## PREFETCHING — data before user clicks
```tsx
// Server-side (Next.js App Router)
async function Page({ params }: { params: { id: string } }) {
  const queryClient = new QueryClient();
  await queryClient.prefetchQuery({
    queryKey: ['message', params.id],
    queryFn: () => fetchMessage(params.id),
  });
  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <MessageDetail />
    </HydrationBoundary>
  );
}

// Client-side — hover-to-prefetch
function MessageLink({ msg }: { msg: Message }) {
  const queryClient = useQueryClient();
  return (
    <Link
      to={`/messages/$id`}
      params={{ id: msg.id }}
      onMouseEnter={() => queryClient.prefetchQuery({
        queryKey: ['message', msg.id],
        queryFn: () => fetchMessage(msg.id),
        staleTime: 60_000,
      })}
    />
  );
}
```

## SUSPENSE MODE
```tsx
// Enable per query — wrap with <Suspense>
const { data } = useQuery({
  queryKey: ['message', id],
  queryFn: () => fetchMessage(id),
  suspense: true,
});

// Parent:
<Suspense fallback={<MessageSkeleton />}>
  <MessageDetail />
</Suspense>

// ErrorBoundary catches query errors automatically
```

## DEVTOOLS
```bash
npm install -D @tanstack/react-query-devtools
```
```tsx
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';

function Providers({ children }: { children: ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <ReactQueryDevtools initialIsOpen={false} buttonPosition="bottom-left" />
    </QueryClientProvider>
  );
}
```

## ROUTER (TanStack Router)
```tsx
// Type-safe routes — never string paths
const router = createRouter({ routeTree });
// <Link to="/items/$id" params={{ id: '123' }} />     ← typed
// navigate({ to: '/items/$id', params: { id } })       ← typed
// useNavigate()()                                      ← typed

// Route with loader (data fetching)
const route = new Route({
  getParentPath: () => rootRoute,
  path: '/items/$itemId',
  component: ItemDetail,
  loader: async ({ params, context: { queryClient } }) => {
    return queryClient.ensureQueryData({
      queryKey: ['item', params.itemId],
      queryFn: () => fetchItem(params.itemId),
    });
  },
});
```

## FORM
```tsx
const form = useForm({
  defaultValues: { name: '', email: '' },
  validators: { onSubmit: schema },  // Zod or Valibot schema
  onSubmit: async ({ value }) => {
    await mutation.mutateAsync(value);
  },
});
// Never: DIY form state with useState
// Built-in: dirty/ touched/ errors/ submitting states, field arrays, async validation
```

## TABLE
```tsx
const columnHelper = createColumnHelper<Message>();

const columns = [
  columnHelper.accessor('content', { header: 'Message', cell: info => info.getValue() }),
  columnHelper.accessor(row => row.author.name, { id: 'author', header: 'Author' }),
  columnHelper.display({ id: 'actions', cell: ({ row }) => <Actions id={row.original.id} /> }),
];

const table = useReactTable({
  data, columns,
  getCoreRowModel: getCoreRowModel(),
  getSortedRowModel: getSortedRowModel(),
  getFilteredRowModel: getFilteredRowModel(),
  getPaginationRowModel: getPaginationRowModel(),
  state: { sorting, globalFilter },
  onSortingChange: setSorting,
  onGlobalFilterChange: setGlobalFilter,
});
// Always use columnHelper — never raw column objects
```

## CACHE PATTERNS
| Pattern | staleTime | gcTime | Use case |
|---------|-----------|--------|----------|
| Fresh | 0 | 5min | Live data, chat, notifications |
| Stale-while-revalidate | 30s–5min | 30min | List views, dashboards |
| Long-lived | 1h | 1h | Reference data, config, settings |
| Infinity | Infinity | Infinity | Static content, i18n strings |
