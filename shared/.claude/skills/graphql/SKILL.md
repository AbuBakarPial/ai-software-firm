# SKILL: GraphQL · v2026.10
> Load when: using or setting up GraphQL in a project.
> Covers: Apollo Client/Server, codegen, caching, subscriptions, federation

## DETECT FIRST
```bash
cat package.json | grep -E "graphql|apollo|urql|relay|pothos|type-graphql|graphql-codegen"
cat pubspec.yaml | grep -E "graphql|ferry|artemis"
ls graphql/ schema/ *.graphql 2>/dev/null
```

---

## SCHEMA DESIGN PRINCIPLES

```graphql
# Define your schema in SDL (Schema Definition Language)

# Node interface — every type has an ID
interface Node {
  id: ID!
}

type User implements Node {
  id: ID!
  name: String!
  email: String!        # @deprecated(reason: "Use emailVerified")
  emailVerified: Boolean!
  avatarUrl: String
  messages(first: Int, after: String): MessageConnection!
}

type Message implements Node {
  id: ID!
  content: String!
  createdAt: DateTime!
  sender: User!
  room: Room!
}

type Room implements Node {
  id: ID!
  name: String!
  members: [User!]!
  messages(first: Int, after: String): MessageConnection!
}

# Connection pattern (cursor-based pagination)
type MessageConnection {
  edges: [MessageEdge!]!
  pageInfo: PageInfo!
}

type MessageEdge {
  node: Message!
  cursor: String!       # opaque cursor for pagination
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

# Queries
type Query {
  me: User!
  room(id: ID!): Room
  searchMessages(query: String!, first: Int): [Message!]!
}

# Mutations
type Mutation {
  sendMessage(roomId: ID!, content: String!): Message!
  deleteMessage(id: ID!): Boolean!
  createRoom(name: String!, memberIds: [ID!]!): Room!
}

# Subscriptions
type Subscription {
  messageSent(roomId: ID!): Message!
  userTyping(roomId: ID!): User!
}
```

---

## APOLLO SERVER (Node.js)

### Setup
```typescript
import { ApolloServer } from '@apollo/server';
import { expressMiddleware } from '@apollo/server/express4';
import { ApolloServerPluginDrainHttpServer } from '@apollo/server/plugin/drainHttpServer';

const server = new ApolloServer({
  typeDefs,        // from schema.graphql
  resolvers,       // resolver map
  plugins: [ApolloServerPluginDrainHttpServer({ httpServer })],
  csrfPrevention: true,
  cache: 'bounded',   // bounded cache size
});

await server.start();
app.use('/graphql', expressMiddleware(server, {
  context: async ({ req }) => ({
    user: await authenticate(req),
    dataSources: { messageAPI: new MessageAPI() },
  }),
}));
```

### Resolvers
```typescript
const resolvers = {
  Query: {
    me: async (_, __, { user }) => user,
    room: async (_, { id }, { dataSources }) => dataSources.roomAPI.find(id),
    searchMessages: async (_, { query, first }, { dataSources }) =>
      dataSources.messageAPI.search(query, first),
  },
  Mutation: {
    sendMessage: async (_, { roomId, content }, { user, dataSources }) => {
      if (!user) throw new AuthenticationError('Not logged in');
      return dataSources.messageAPI.create(user.id, roomId, content);
    },
  },
  Subscription: {
    messageSent: {
      subscribe: withFilter(
        (_, { roomId }) => pubsub.asyncIterator(`MESSAGE_SENT:${roomId}`),
        (payload, variables) => payload.messageSent.roomId === variables.roomId,
      ),
    },
  },
  Room: {
    messages: async (parent, { first, after }, { dataSources }) =>
      dataSources.messageAPI.findByRoom(parent.id, { first, after }),
    members: async (parent, _, { dataSources }) =>
      dataSources.memberAPI.findByRoom(parent.id),
  },
  // Type resolver for interfaces/unions
  Node: {
    __resolveType(obj) {
      if (obj.email) return 'User';
      if (obj.content) return 'Message';
      return null;
    },
  },
};
```

### DataLoader (batching + caching)
```typescript
// Prevents N+1 problem — batches queries by key
import DataLoader from 'dataloader';

class UserAPI {
  private loader = new DataLoader<string, User>(async (ids) => {
    const users = await db.user.findMany({ where: { id: { in: ids } } });
    return ids.map(id => users.find(u => u.id === id) || new NotFoundError());
  });

  async find(id: string): Promise<User> {
    return this.loader.load(id);
  }
}
```

---

## APOLLO CLIENT (React/Next.js)

### Setup
```typescript
import { ApolloClient, InMemoryCache, createHttpLink, split } from '@apollo/client';
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { getMainDefinition } from '@apollo/client/utilities';

const httpLink = createHttpLink({ uri: '/api/graphql', credentials: 'include' });
const wsLink = new GraphQLWsLink(createClient({ url: 'ws://localhost:4000/graphql' }));

const splitLink = split(
  ({ query }) => {
    const def = getMainDefinition(query);
    return def.kind === 'OperationDefinition' && def.operation === 'subscription';
  },
  wsLink,
  httpLink,
);

const client = new ApolloClient({
  link: splitLink,
  cache: new InMemoryCache({
    typePolicies: {
      Room: {
        fields: {
          messages: {
            // Merge paginated results
            keyArgs: false,
            merge(existing, incoming) {
              const edges = existing?.edges ?? [];
              return { ...incoming, edges: [...edges, ...incoming.edges] };
            },
          },
        },
      },
    },
  }),
});
```

### Queries + Mutations
```typescript
// Queries — use Apollo hooks
function RoomPage({ roomId }: { roomId: string }) {
  const { loading, error, data, fetchMore } = useQuery(GET_ROOM, {
    variables: { roomId, first: 50 },
  });
  // ... render
}

// Mutations
const [sendMessage, { loading }] = useMutation(SEND_MESSAGE, {
  update(cache, { data: { sendMessage } }) {
    cache.modify({
      fields: {
        messages(existingMessages = []) {
          return [sendMessage, ...existingMessages];
        },
      },
    });
  },
});
```

### Subscriptions
```typescript
function MessageList({ roomId }: { roomId: string }) {
  const { data } = useSubscription(MESSAGE_SENT, { variables: { roomId } });
  // Append new messages as they arrive
}
```

### Fragments (reusable field selections)
```graphql
# fragments/MessageFields.graphql
fragment MessageFields on Message {
  id
  content
  createdAt
  sender { id name avatarUrl }
}
```
```typescript
// Use fragment in queries
const GET_ROOM = gql`
  ${MessageFields}
  query GetRoom($roomId: ID!, $first: Int) {
    room(id: $roomId) {
      id
      name
      messages(first: $first) {
        edges { node { ...MessageFields } cursor }
      }
    }
  }
`;
```

---

## GRAPHQL CODECGEN (type-safe code)

```bash
# codegen.ts
import type { CodegenConfig } from '@graphql-codegen/cli';
const config: CodegenConfig = {
  schema: './schema.graphql',
  documents: ['src/**/*.tsx'],
  generates: {
    './gql/': {
      preset: 'client',
      plugins: [],
    },
  },
};
export default config;
```

```bash
npx graphql-codegen --config codegen.ts
# Generates: gql/graphql.ts — fully typed operations
```

Generated types:
```typescript
import { useQuery } from '@apollo/client';
import { GetRoomDocument, useSendMessageMutation } from '../gql/graphql';

// Fully typed — query returns Room | null, variables are RoomId, First
const { data } = useQuery(GetRoomDocument, { variables: { roomId: '123', first: 50 } });
```

---

## FEDERATION (microservices GraphQL)

```typescript
// Each service owns part of the schema
// Gateway composes them into one endpoint

// User Service
extend type Query {
  me: User!
}
type User @key(fields: "id") {
  id: ID! @external
  name: String!
  email: String!
}

// Message Service
extend type Query {
  messages(roomId: ID!): [Message!]!
}
type Message @key(fields: "id") {
  id: ID!
  content: String!
  sender: User! @requires(fields: "senderId")
}
```

---

## SECURITY

- Depth limiting: `graphql-depth-limit` — prevent deep nested queries
- Query complexity analysis: `graphql-query-complexity` — reject expensive queries
- Rate limiting: per-user per-minute query count
- Persisted queries: only allow known query hashes (no arbitrary queries in prod)
- CSRF protection: Apollo Server has built-in csrfPrevention
- No introspection in production: `introspection: false`
- Authentication: check every resolver/context, not just in middleware
- Authorization: check field-level permissions

---

## ANTI-PATTERNS

- No pagination on list fields (user can query ALL messages at once)
- N+1 queries from resolvers (always use DataLoader)
- Mutations returning wrong shape (always return the mutated entity)
- No error handling in resolvers (throw ApolloError with proper code)
- Mixing REST and GraphQL auth (inconsistent)
- Large queries with no depth limiting (server overload)
- Fragments duplication (use shared fragment files)
