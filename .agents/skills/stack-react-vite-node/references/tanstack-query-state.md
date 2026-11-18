# TanStack Query & Server State Reference (React 19)

Convenciones para la sincronización y gestión de estado de servidor con TanStack Query v5 en React.

---

## 1. Fábrica de Query Keys (*Query Key Factory*)

Para evitar colisiones de claves de caché y permitir invalidación precisa:

```typescript
// client/src/features/users/api/user-keys.ts
export const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (filters: Record<string, unknown>) => [...userKeys.lists(), filters] as const,
  details: () => [...userKeys.all, 'detail'] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
};
```

---

## 2. Consumo con `useQuery` y Matriz de 4 Estados

Todo componente que consume datos asíncronos debe manejar explícitamente los 4 estados de interfaz:

```tsx
// client/src/features/users/components/UserList.tsx
import { useQuery } from '@tanstack/react-query';
import { apiFetch } from '../../../lib/api-client';
import { userKeys } from '../api/user-keys';

interface User {
  id: string;
  name: string;
  email: string;
}

export function UserList() {
  const { data: users, isLoading, isError, error, refetch } = useQuery({
    queryKey: userKeys.lists(),
    queryFn: () => apiFetch<User[]>('/users'),
  });

  // 1. Estado Loading
  if (isLoading) {
    return <div aria-busy="true" className="animate-pulse p-4">Cargando usuarios...</div>;
  }

  // 2. Estado Error
  if (isError) {
    return (
      <div role="alert" className="p-4 text-red-600">
        <p>Error: {error.message}</p>
        <button onClick={() => refetch()} className="btn btn-secondary mt-2">
          Reintentar
        </button>
      </div>
    );
  }

  // 3. Estado Vacío (Empty)
  if (!users || users.length === 0) {
    return (
      <div className="p-8 text-center text-muted">
        <p>No se encontraron usuarios registrados.</p>
      </div>
    );
  }

  // 4. Estado Éxito (Success)
  return (
    <ul className="divide-y divide-border">
      {users.map((u) => (
        <li key={u.id} className="py-2">
          <span className="font-medium">{u.name}</span> — {u.email}
        </li>
      ))}
    </ul>
  );
}
```

---

## 3. Mutaciones e Invalidación Declarativa

```typescript
// client/src/features/users/hooks/useCreateUser.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '../../../lib/api-client';
import { userKeys } from '../api/user-keys';

export function useCreateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (newUser: { name: string; email: string }) =>
      apiFetch('/users', {
        method: 'POST',
        body: JSON.stringify(newUser),
      }),
    onSuccess: () => {
      // Invalida la lista para refrescar datos automáticamente
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
    },
  });
}
```
