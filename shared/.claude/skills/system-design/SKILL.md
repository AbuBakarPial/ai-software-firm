# SKILL: System Design · v2026.10
> Load when: architecting new features, choosing patterns, or reviewing architecture.
> Covers: CQRS, event sourcing, microservices, hexagonal architecture, DDD, scaling

## FIRST PRINCIPLE

Every architecture is a set of tradeoffs. The right one depends on:
- Team size and skill
- Scale requirements (users, data, throughput)
- Consistency vs availability needs
- Deployment environment
- Speed of iteration needed

---

## ARCHITECTURE PATTERNS

### Monolith (start here)
```typescript
// Single deployable unit. All code in one project.
// ✅ Simple, fast iteration, one DB transaction
// ❌ Scales to team size, not traffic (vertical scale)
// Best for: <10 devs, <100k users, early-stage products
src/
├── modules/
│   ├── auth/       (controller + service + repository)
│   ├── chat/       (controller + service + repository)
│   └── billing/    (controller + service + repository)
└── shared/         (db, middleware, utils)
```

### Modular Monolith
```typescript
// Single deployable, but strict module boundaries
// Each module has OWN database schema (shared DB, separate tables)
// Modules communicate via in-memory events or sync calls
// ✅ Best "default" choice — simple deploy, clear boundaries, no network overhead
// ❌ Modules can still耦合 via shared DB
// Best for: 10-50 devs, 100k-1M users
```

### Microservices
```typescript
// Each service is independent deployable with its own DB
// Communication via HTTP/gRPC/Message Queue
// ✅ Independent scaling, team autonomy, tech diversity
// ❌ Distributed transactions, network latency, debugging complexity
// Best for: >50 devs, >1M users, multiple teams
```

### CQRS (Command Query Responsibility Segregation)
```typescript
// Separate models for reads and writes
// Commands: mutate state (POST/PUT/DELETE)
// Queries: read state (GET) — often denormalized for speed

// Command side
class SendMessageCommand {
  constructor(
    public readonly roomId: string,
    public readonly senderId: string,
    public readonly content: string,
  ) {}
}

class MessageCommandHandler {
  async handle(cmd: SendMessageCommand): Promise<void> {
    await this.repo.save(Message.create(cmd.roomId, cmd.senderId, cmd.content));
    await this.eventBus.publish(new MessageSentEvent(cmd.roomId, cmd.senderId));
  }
}

// Query side (denormalized read model)
class MessageQueryHandler {
  async getMessages(roomId: string, cursor?: string): Promise<MessageDTO[]> {
    return this.readRepo.findByRoom(roomId, { cursor, limit: 50 });
  }
}
// ✅ Reads optimized independently of writes
// ❌ Eventual consistency — writes may not be immediately readable
```

### Event Sourcing
```typescript
// Store facts (events), not current state
// Current state = fold over all past events
// Events are immutable, append-only

// Event store append
await eventStore.append('message', [
  { type: 'MessageSent', data: { messageId, roomId, content }, version: 1 },
  { type: 'MessageRead', data: { messageId, userId }, version: 2 },
]);

// Reconstruct state
class Message {
  static fromEvents(events: MessageEvent[]): Message {
    let msg = new Message();
    for (const e of events) {
      switch (e.type) {
        case 'MessageSent': msg._applySent(e.data); break;
        case 'MessageRead': msg._applyRead(e.data); break;
      }
    }
    return msg;
  }
}
// ✅ Full audit trail, time travel, strong consistency within aggregate
// ❌ Complex, storage heavy, eventual consistency across services
```

### Hexagonal / Clean Architecture
```typescript
// Core business logic has zero dependencies on frameworks/DB/UI
// All external concerns are "ports" (interfaces) and "adapters" (implementations)

// Domain layer — pure business logic, no imports from outside
class Order {
  constructor(public items: OrderItem[]) {}
  get total(): Money { return this.items.reduce((sum, i) => sum.add(i.price), Money.ZERO); }
}

// Application layer — use cases / ports
interface OrderRepository {
  save(order: Order): Promise<void>;
  findById(id: string): Promise<Order | null>;
}

// Infrastructure layer — adapters
class PostgresOrderRepository implements OrderRepository {
  async save(order: Order): Promise<void> {
    await db.query('INSERT INTO orders ...', [order]);
  }
}

// ✅ Testable domain, framework-independent, swap infra anytime
// ❌ Boilerplate interfaces, overkill for simple CRUD
```

---

## DOMAIN-DRIVEN DESIGN (DDD) TERMS

| Term | Meaning | Example |
|------|---------|---------|
| Entity | Object with identity (ID) | User, Order, Message |
| Value Object | Immutable, defined by attributes | Money, Address, Color |
| Aggregate | Cluster of entities treated as unit | Order + OrderItems |
| Repository | Collection-like access to aggregates | OrderRepository |
| Domain Event | Something meaningful that happened | OrderPlaced, PaymentReceived |
| Service | Stateless operation | PaymentService |
| Bounded Context | Explicit boundary where a model applies | "Sales" context ≠ "Shipping" context |

---

## SCALING PATTERNS

```
Vertical scaling         → bigger machine (simple, hard limit)
Horizontal scaling       → more machines (complex, nearly unlimited)
Database replication     → read replicas (eventual consistency)
Database sharding        → split data by key (complex queries)
Caching                  → Redis/CDN (stale data risk)
CDN                      → static assets, images (must invalidate)
Queue                    → async processing (RabbitMQ, Kafka, SQS)
Read replicas            → SELECT from replica, INSERT/UPDATE to primary
Materialized views       → pre-computed query results
Connection pooling       → reuse DB connections
```

---

## DATABASE CHOICE GUIDE

| Need | Choice | Why |
|------|--------|-----|
| Relational, ACID | PostgreSQL | Best default for most apps |
| Key-value, fast | Redis | Caching, sessions, realtime |
| Document, flexible | MongoDB | JSON-like data, no joins |
| Time-series | InfluxDB, TimescaleDB | Metrics, logs, analytics |
| Full-text search | ElasticSearch | Search, log aggregation |
| Graph | Neo4j | Friend graphs, recommendations |
| Blob storage | S3 / GCS / R2 | Files, images, backups |

**Rule of thumb:** Start with PostgreSQL. Add others only when PostgreSQL proves inadequate for a specific workload.

---

## API STYLE GUIDE

| Style | Pros | Cons | Best for |
|-------|------|------|----------|
| REST | Universal, cacheable, simple | Over/under-fetching, many endpoints | CRUD, public APIs |
| GraphQL | Exact data, single endpoint, strong types | Complex caching, query cost | Complex UIs, mobile |
| gRPC | Fast, typed, streaming | Browser support limited | Internal services, realtime |
| WebSocket | Bidirectional, realtime | No request/response mapping | Chat, live updates |
| Webhook | Server→server events | Delivery guarantees | Notifications, integrations |
---

## EVENT-DRIVEN ARCHITECTURE

```typescript
// Event schema — always versioned
interface DomainEvent {
  id: string;
  type: string;
  version: number;
  timestamp: string;
  data: Record<string, unknown>;
}

// Producer
await messageQueue.publish('chat.message.sent', {
  id: uuid(),
  type: 'MessageSent',
  version: 1,
  timestamp: new Date().toISOString(),
  data: { messageId, roomId, senderId, content },
});

// Consumer
messageQueue.subscribe('chat.message.sent', async (event) => {
  // Update read model
  await readModel.appendMessage(event.data);
  // Send notification
  await notificationService.send(event.data);
  // Invalidate cache
  await cache.del(`messages:${event.data.roomId}`);
});
```

---

## TYPICAL SYSTEM DESIGN QUESTIONS

When building any feature, answer:
1. What's the data model? (entities, relationships, cardinality)
2. Read vs write ratio? (cache? denormalize?)
3. Consistency requirements? (strong vs eventual?)
4. Scale: how many users? how many requests/second?
5. Failure modes? (what breaks, how does it degrade?)
6. Cost constraints? (compute, storage, bandwidth)

---

## ANTI-PATTERNS

- Microservices for a 2-person team (transactional nightmare)
- Event sourcing for a blog (unnecessary complexity)
- CQRS without separate read store (just adds code, no benefit)
- Distributed monolith (services that can't be deployed independently)
- Premature optimization (caching before measuring)
- No caching then wondering why DB is slow (obvious in hindsight)
