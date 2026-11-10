# SQLAlchemy 2 + Alembic + PostgreSQL

## Motor y sesión async
```python
# app/db/session.py
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.core.config import settings

engine = create_async_engine(settings.database_url, pool_size=5, max_overflow=5, pool_pre_ping=True)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)

# app/api/deps.py
async def get_session():
    async with SessionLocal() as session:
        yield session
```

## Modelos con `Mapped[]`
```python
# app/models/project.py
from datetime import datetime
from sqlalchemy import ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base

class Project(Base):
    __tablename__ = "projects"
    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)  # índice en cada FK
    name: Mapped[str] = mapped_column(nullable=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    owner: Mapped["User"] = relationship(back_populates="projects")
```
Usa `DateTime(timezone=True)` para fechas y `UUID` si los IDs no deben ser enumerables.

## Consultas
```python
stmt = select(Project).where(Project.owner_id == user_id).options(selectinload(Project.owner))
result = await session.scalars(stmt)
```
Evita el problema N+1 cargando relaciones con `selectinload()` en la misma consulta. Para listados usa paginación (`limit`/`offset` o cursor) y un orden estable.

## Alembic
- `alembic/env.py` importa `app.db.base` (que importa todos los modelos) y toma la URL del entorno, no de `alembic.ini`.
- Flujo: cambia el modelo → `alembic revision --autogenerate -m "..."` → **revisa el archivo generado** → `alembic upgrade head`.
- Cada migración tiene `downgrade()` funcional.
- Cambios destructivos en producción en dos fases (Expand/Contract): primero añade lo nuevo y migra los datos; en otro despliegue elimina lo antiguo.
- En CI aplica `alembic upgrade head` sobre una base vacía y luego `alembic downgrade base` para comprobar que el ciclo completo funciona.

## Tests con base de datos
Usa una base PostgreSQL real para pruebas (contenedor), no SQLite: los tipos y el comportamiento difieren. Aísla cada test con una transacción que se revierte al terminar, o recrea el esquema con Alembic al inicio de la sesión de pruebas.
