# SKILL: Message Queues / Event Streaming · v2026.10
> Load when: adding async processing, decoupling services, or handling high throughput.
> Covers: RabbitMQ, Kafka, Pub/Sub patterns, idempotency, dead-letter queues

## DETECT FIRST
```bash
cat package.json | grep -E "amqplib|kafkajs|mqtt|bull|redis|sqs|pubsub"
cat pubspec.yaml | grep -E "mqtt|amqp|kafka|redis|pubsub"
grep -r "Queue\|Topic\|Exchange\|Producer\|Consumer\|Publisher\|Subscriber" lib/ --include="*.dart" -l | head -3
docker ps | grep -E "rabbitmq|kafka|redis|nats" 2>/dev/null
```

---

## WHEN TO USE QUEUES

| Scenario | Use Queue? | Alternative |
|----------|-----------|-------------|
| Send email after signup | ✅ Yes | Could be inline but slow |
| Real-time chat message | ❌ No | WebSocket/Supabase Realtime |
| Process image upload | ✅ Yes | Can't keep HTTP connection open |
| User sees notification | ❌ No | Direct push notification |
| Aggregate analytics events | ✅ Yes | Kafka better for high volume |
| Update search index | ✅ Yes | Async, don't block write path |
| User-to-user message | ❌ No | Needs immediate delivery |
| Daily report generation | ✅ Yes | Scheduled job, not real-time |

---

## RABBITMQ (AMQP)

### Core Concepts
```
Producer → Exchange → Binding → Queue → Consumer
                      ↓
                  Dead Letter Exchange → Dead Letter Queue
```

### Exchange Types
| Type | Routing | Use Case |
|------|---------|----------|
| Direct | Exact routing key | Point-to-point, task queues |
| Topic | Pattern match (room.*) | Pub/sub with filtering |
| Fanout | Broadcast to all queues | Event broadcasting |
| Headers | Match message headers | Complex routing |

### Node.js with amqplib
```typescript
import amqp from 'amqplib';

// Producer
async function sendMessage(roomId: string, message: MessageDTO) {
  const conn = await amqp.connect(process.env.RABBITMQ_URL!);
  const channel = await conn.createChannel();

  const exchange = 'chat.events';
  await channel.assertExchange(exchange, 'topic', { durable: true });

  const routingKey = `room.${roomId}.message`;
  channel.publish(exchange, routingKey, Buffer.from(JSON.stringify(message)), {
    persistent: true,
    contentType: 'application/json',
  });

  await channel.close();
  await conn.close();
}

// Consumer
async function consumeMessages(roomId: string) {
  const conn = await amqp.connect(process.env.RABBITMQ_URL!);
  const channel = await conn.createChannel();

  const exchange = 'chat.events';
  await channel.assertExchange(exchange, 'topic', { durable: true });

  const { queue } = await channel.assertQueue(`chat.room.${roomId}`, {
    durable: true,
    deadLetterExchange: 'chat.dlx',  // failed messages go here
    messageTtl: 86400000,            // 24h TTL
  });

  const routingKey = `room.${roomId}.*`;
  await channel.bindQueue(queue, exchange, routingKey);

  channel.consume(queue, async (msg) => {
    if (!msg) return;
    try {
      const data = JSON.parse(msg.content.toString());
      await processMessage(data);
      channel.ack(msg);              // acknowledge success
    } catch (error) {
      channel.nack(msg, false, false); // reject → dead letter queue
    }
  });
}
```

### Flutter/Dart with dart_amqp
```dart
import 'package:dart_amqp/dart_amqp.dart';

Future<void> publishMessage(String roomId, Map<String, dynamic> message) async {
  final client = Client();
  await client.connect(ServerConfig(
    host: 'localhost',
    virtualHost: '/',
    credentials: Credentials('guest', 'guest'),
  ));

  final channel = await client.channel();
  final exchange = await channel.exchange('chat.events', ExchangeType.TOPIC, durable: true);
  exchange.publish(jsonEncode(message), routingKey: 'room.$roomId.message');
  await client.close();
}
```

---

## KAFKA

### Core Concepts
```
Producer → Topic (partitioned, replicated) → Consumer Group
                                               ↓
                                           Offset (committed)
                                               ↓
                                           Exactly Once / At Least Once
```

### Topics & Partitions
```bash
kafka-topics.sh --create --topic chat.messages --partitions 6 --replication-factor 3 --bootstrap-server localhost:9092
kafka-topics.sh --describe --topic chat.messages --bootstrap-server localhost:9092
```

### Node.js with KafkaJS
```typescript
import { Kafka, logLevel } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'chat-service',
  brokers: ['kafka-1:9092', 'kafka-2:9092'],
  logLevel: logLevel.INFO,
});

// Producer
const producer = kafka.producer({ allowAutoTopicCreation: true });
await producer.connect();

await producer.send({
  topic: 'chat.messages',
  messages: [
    {
      key: message.roomId,           // all messages for same room → same partition → ordered
      value: JSON.stringify(message),
      headers: { 'message-type': 'text' },
      timestamp: Date.now().toString(),
    },
  ],
});

// Consumer
const consumer = kafka.consumer({ groupId: 'message-processor' });
await consumer.connect();
await consumer.subscribe({ topic: 'chat.messages', fromBeginning: false });

await consumer.run({
  eachMessage: async ({ topic, partition, message }) => {
    const data = JSON.parse(message.value!.toString());
    await processMessage(data);
    // Offset auto-committed (or manual: consumer.commitOffsets(...))
  },
  autoCommitInterval: 5000,  // commit every 5s
});
```

### Key Kafka Rules
- Consumer group = one logical consumer (scales within group)
- Partition = unit of parallelism (max consumers per group = partitions)
- Within a partition: messages are ordered. Across partitions: no order guarantee
- Set message key = roomId → all messages for same room go to same partition → ordered
- Retention: time-based (7 days default) or size-based (1GB default)
- Compacted topics: keep only latest value per key (useful for state snapshots)

---

## GOOGLE PUB/SUB

```typescript
// Topic → Subscription → Pull/Push
// Push: endpoint receives POST
// Pull: consumer pulls messages

// Publisher
const { PubSub } = require('@google-cloud/pubsub');
const pubsub = new PubSub();
await pubsub.topic('chat-messages').publishMessage({ json: message });

// Subscriber (pull)
const sub = pubsub.subscription('chat-messages-sub');
sub.on('message', (msg) => {
  processMessage(msg.data);
  msg.ack();
});
sub.on('error', console.error);
```

---

## REDIS PUB/SUB (simple, no persistence)

```typescript
// ✅ Good for: ephemeral messages, realtime notifications
// ❌ Bad for: guaranteed delivery, persistence, replay

const publisher = redis.createClient();
publisher.publish('chat:room:123', JSON.stringify(message));

// Subscriber
const subscriber = redis.createClient();
subscriber.subscribe('chat:room:123', (raw) => {
  const message = JSON.parse(raw);
  // Messages delivered to ALL subscribers
  // No persistence — if subscriber is offline, message lost
});
```

---

## PATTERNS

### Competing Consumers (work queue)
```
Multiple consumers share same queue
Each message goes to ONE consumer
✅ Parallel processing, horizontal scaling
Used for: email sending, image processing, report generation
```

### Pub/Sub (broadcast)
```
Each consumer gets a copy of every message
✅ Fan-out pattern, multiple independent processors
Used for: audit logging, analytics, cache invalidation
```

### Dead Letter Queue
```
Messages that fail processing → sent to DLQ after N retries
✅ Never lose a message
Used: manual inspection, replay after fix
```

### Idempotent Consumer
```typescript
// Same message delivered twice → same result

async function processMessage(msg: Message) {
  const processed = await redis.get(`processed:${msg.id}`);
  if (processed) return;  // already processed — skip

  await db.message.create(msg);
  await redis.set(`processed:${msg.id}`, '1', { EX: 86400 });  // 24h dedup
}
```

### Outbox Pattern
```typescript
// Avoid dual-write problem (write to DB + publish event = inconsistent if one fails)

// 1. Write to DB + outbox table in SAME transaction
await db.$transaction(async (tx) => {
  await tx.message.create({ data: msg });
  await tx.outbox.create({ data: { type: 'MessageSent', payload: msg } });
});

// 2. Background process polls outbox → publishes → deletes
async function processOutbox() {
  const entries = await db.outbox.findMany({ take: 100 });
  for (const entry of entries) {
    await messageQueue.publish(entry.type, entry.payload);
    await db.outbox.delete({ where: { id: entry.id } });
  }
}
```

---

## QUEUE COMPARISON

| Feature | RabbitMQ | Kafka | Redis Pub/Sub | Google Pub/Sub | AWS SQS/SNS |
|---------|----------|-------|---------------|----------------|-------------|
| Persistence | Disk | Disk | None | Disk | Disk |
| Ordering | Per queue | Per partition | None | Best effort | No (FIFO queue available) |
| Delivery | At least once | At least once | At most once | At least once | At least once |
| Throughput | ~10k/s | ~100k/s | ~100k/s | ~10k/s | ~10k/s |
| Consumer model | Queue (competing) | Consumer group | Pub/sub | Subscription | Queue/Topic |
| Replay | No (acked = gone) | Yes (offset) | No | Yes (snapshot) | No (FIFO: limited) |
| Best for | Task queues, RPC | Event streaming, analytics | Real-time, ephemeral | Serverless apps | AWS-native apps |

---

## PRODUCTION CHECKLIST

- [ ] Dead letter queue configured
- [ ] Retry with backoff (exponential backoff, max 3 retries)
- [ ] Idempotent consumers (same message processed twice = same result)
- [ ] Monitoring: queue depth, consumer lag, error rate
- [ ] Alerts: queue growing (consumer down), error rate spike
- [ ] Security: TLS encryption, authentication on connection
- [ ] Connection pooling (don't open/close connections per message)
- [ ] Graceful shutdown (finish processing current messages)
- [ ] Message schema versioning (never break consumers)
- [ ] Circuit breaker for downstream services
