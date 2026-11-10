# FastAPI: esquemas, dependencias y errores

## Configuración desde el entorno
```python
# app/core/config.py
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    database_url: str
    jwt_secret: str          # sin valor por defecto: la app no arranca sin él
    cors_origins: list[str] = []

settings = Settings()
```

## Esquemas de entrada y salida (separados del modelo)
```python
# app/schemas/user.py
from pydantic import BaseModel, ConfigDict, EmailStr, Field

class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=12, max_length=128)

class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    email: EmailStr          # nunca incluye password_hash
```

## Router delgado + dependencias
```python
# app/api/users.py
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_session
from app.schemas.user import UserCreate, UserOut
from app.services import users as users_service

router = APIRouter(prefix="/users", tags=["users"])

@router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def create_user(data: UserCreate, session: AsyncSession = Depends(get_session)):
    return await users_service.create(session, data)
```

## Autorización por objeto (previene IDOR)
El servicio recibe el usuario actual y filtra por propietario; si el recurso no es suyo responde `404`, no `403`, para no revelar que existe.
```python
stmt = select(Project).where(Project.id == project_id, Project.owner_id == current_user.id)
```

## Errores sin filtrar detalles internos
```python
# app/main.py
@app.exception_handler(Exception)
async def unhandled(_: Request, exc: Exception):
    logger.exception("error no controlado")       # el detalle va al log, no al cliente
    return JSONResponse(status_code=500, content={"detail": "Error interno"})
```

## Seguridad básica
- Contraseñas con `argon2-cffi` o `bcrypt`; nunca SHA simple.
- JWT con `PyJWT`: caducidad corta, algoritmo fijado explícitamente al verificar.
- CORS con lista explícita de orígenes (`CORSMiddleware`), nunca `"*"` con credenciales.
- Límite de tasa en login y registro (`slowapi` o en el proxy).

## Tests de la API
```python
import pytest
from httpx import ASGITransport, AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_health():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        r = await client.get("/health")
    assert r.status_code == 200
```
Sustituye la dependencia de sesión con `app.dependency_overrides[get_session]` para usar una base de datos de pruebas.
