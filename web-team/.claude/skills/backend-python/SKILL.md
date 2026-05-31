# SKILL: Backend Python · v2026.11
> Load when: FastAPI/Flask/Django/Starlette backend work.

## DETECT FIRST
```bash
cat requirements.txt pyproject.toml 2>/dev/null | grep -E "fastapi|flask|django|starlette|sqlalchemy|alembic|celery|arq"
python --version && which python
ls src/app src/api config 2>/dev/null
```

## LAYERED ARCHITECTURE
```
api/routes/  → HTTP only — parse, call service, respond
services/    → business logic — pure functions preferred, no HTTP awareness
repositories/→ DB queries only — SQLAlchemy async sessions
schemas/     → Pydantic v2 models — input validation + serialization
core/        → config, dependencies, database, security
tasks/       → background jobs (Celery, arq, or dramatiq)
```

## FASTAPI PATTERNS

### Standard route with DI
```python
# Layered: router → service → repository
router = APIRouter(prefix="/messages", tags=["messages"])

@router.post("/", response_model=MessageOut, status_code=201)
async def create_message(
    body: MessageCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Message:
    return await message_service.create(db, user.id, body)
```

### Service layer — no HTTP, no DB awareness
```python
class MessageService:
    def __init__(self, repo: MessageRepository):
        self.repo = repo

    async def create(self, db: AsyncSession, user_id: str, data: MessageCreate) -> Message:
        async with db.begin():
            return await self.repo.create(db, user_id, data)

    async def list_by_room(self, db: AsyncSession, room_id: str, cursor: str | None, limit: int = 50) -> list[Message]:
        return await self.repo.find_by_room(db, room_id, cursor, limit)
```

### DI container — FastAPI built-in
```python
# core/dependencies.py
from fastapi import Depends
from functools import lru_cache

@lru_cache
def get_settings() -> Settings:
    return Settings()  # pydantic-settings

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session_factory() as session:
        yield session

def get_message_service() -> MessageService:
    return MessageService(MessageRepository())

def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    payload = decode_jwt(token)
    return User(id=payload["sub"], role=payload.get("role", "user"))
```

### Global exception handler
```python
@app.exception_handler(AppError)
async def handle_app_error(request: Request, exc: AppError):
    return JSONResponse(status_code=exc.status_code, content={"error": exc.message, "code": exc.code})

@app.exception_handler(RequestValidationError)
async def handle_validation_error(request: Request, exc: RequestValidationError):
    return JSONResponse(status_code=422, content={"error": "Validation failed", "details": exc.errors()})

@app.exception_handler(Exception)
async def handle_unexpected(request: Request, exc: Exception):
    logger.exception("Unhandled exception")
    return JSONResponse(status_code=500, content={"error": "Internal server error"})
```

## ASYNC PATTERNS — SQLAlchemy 2.0 async
```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import select, func

engine = create_async_engine(os.environ["DATABASE_URL"].replace("postgresql://", "postgresql+asyncpg://"), pool_size=20, max_overflow=10)
async_session_factory = async_sessionmaker(engine, expire_on_commit=False)

# Repository
class MessageRepository:
    async def create(self, db: AsyncSession, user_id: str, data: MessageCreate) -> Message:
        msg = Message(**data.model_dump(), user_id=user_id)
        db.add(msg)
        await db.flush()
        await db.refresh(msg)
        return msg

    async def find_by_room(self, db: AsyncSession, room_id: str, cursor: str | None, limit: int) -> list[Message]:
        stmt = select(Message).where(Message.room_id == room_id, Message.deleted_at.is_(None))
        if cursor:
            stmt = stmt.where(Message.id < cursor)
        stmt = stmt.order_by(Message.created_at.desc()).limit(limit)
        result = await db.execute(stmt)
        return result.scalars().all()
```

## BACKGROUND TASKS

### Celery (for long-running jobs)
```python
# tasks/worker.py
from celery import Celery
celery_app = Celery("app", broker=os.environ["REDIS_URL"], backend=os.environ["REDIS_URL"])
celery_app.conf.update(task_acks_late=True, worker_prefetch_multiplier=1, result_expires=3600)

@celery_app.task(bind=True, max_retries=3, default_retry_delay=60, autoretry_for=(TransientError,))
def send_email(self, user_id: str, template: str):
    user = get_user_sync(user_id)  # synchronous helper
    email_service.send(user.email, template)
    logger.info("Email sent", extra={"user_id": user_id, "template": template})
```

### arq (asyncio-native, lighter)
```python
# tasks/arq_worker.py
from arq import create_pool, Retry
from arq.connections import RedisSettings

async def send_email(ctx, user_id: str, template: str):
    try:
        await email_service.send(user_id, template)
    except TransientError:
        raise Retry(defer=ctx["job_try"] * 5)

class WorkerSettings:
    functions = [send_email]
    redis_settings = RedisSettings(host="localhost", port=6379)
    max_tries = 3
    keep_result = 3600
```

### FastAPI lifespan + background tasks
```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup — create pool, warm connections
    app.state.redis = await create_pool(RedisSettings())
    yield
    # Shutdown — graceful
    app.state.redis.close()
    await app.state.redis.wait_closed()

app = FastAPI(lifespan=lifespan)

# Fire-and-forget via BackgroundTasks
@router.post("/export")
async def export_data(body: ExportRequest, tasks: BackgroundTasks):
    tasks.add_task(generate_export, body.filters)
    return {"status": "queued"}
```

## STRUCTURED LOGGING (structlog)
```python
import structlog
logger = structlog.get_logger()

# In config
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.dev.ConsoleRenderer() if DEBUG else structlog.processors.JSONRenderer(),
    ],
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
    cache_logger_on_first_use=True,
)
# Usage: logger.info("message created", user_id=user.id, room_id=room.id, duration_ms=42)
```

## TESTING (pytest + httpx)
```python
# conftest.py
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

@pytest.fixture
async def db_session():
    async with async_session_factory() as session:
        yield session
        await session.rollback()

# test_messages.py
@pytest.mark.asyncio
async def test_create_message(client: AsyncClient, auth_token: str):
    response = await client.post("/api/v1/messages/", json={"content": "Hello"}, headers={"Authorization": f"Bearer {auth_token}"})
    assert response.status_code == 201
    data = response.json()
    assert "id" in data
    assert data["content"] == "Hello"

@pytest.mark.asyncio
async def test_unauthorized(client: AsyncClient):
    response = await client.post("/api/v1/messages/", json={"content": "Hello"})
    assert response.status_code == 401
```

## FLASK (when you must)
```python
from flask import Flask, request, jsonify
from flask_pydantic import validate
app = Flask(__name__)

@app.route("/api/messages", methods=["POST"])
@validate(body=MessageCreate)
def create_message():
    msg = message_service.create(get_current_user(), request.body_params)
    return jsonify(msg.model_dump()), 201
```

## DJANGO (use DRF + django-ninja as default)
```python
from ninja import NinjaAPI, Schema
from ninja.security import HttpBearer

api = NinjaAPI()

class MessageCreate(Schema):
    content: str
    room_id: str

@api.post("/messages", response=MessageOut, auth=HttpBearer())
def create(request, body: MessageCreate):
    return message_service.create(request.auth, body.dict())
```

## SECURITY
- Pydantic v2 — all input validation, never trust raw request
- passlib[bcrypt] — password hashing
- python-jose or PyJWT — JWT with short expiry (15min access, 7d refresh)
- slowapi or nginx — rate limiting (5/min auth, 100/min API)
- pydantic-settings — validated env config, never hardcode secrets
- CORS: `CORSMiddleware(allow_origins=[...])` — explicit list
- SQLAlchemy: parameterized queries only — no f-string SQL
- Content Security Policy via middleware or nginx headers
