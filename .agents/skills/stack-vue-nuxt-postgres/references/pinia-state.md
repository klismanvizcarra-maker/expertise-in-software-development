# Pinia State Management Reference (Nuxt 3)

Convenciones para la gestión del estado global con Pinia en aplicaciones Nuxt 3.

---

## 1. Definición con Setup Syntax (`defineStore`)

Siempre preferir la sintaxis de composición (`Setup Stores`) por su total compatibilidad con TypeScript y composables de Vue:

```typescript
// stores/auth.ts
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export interface User {
  id: string;
  email: string;
  name: string;
  role: 'ADMIN' | 'USER';
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null);
  const isAuthenticated = computed(() => user.value !== null);
  const isAdmin = computed(() => user.value?.role === 'ADMIN');

  function setUser(newUser: User | null) {
    user.value = newUser;
  }

  async function fetchProfile() {
    try {
      const data = await $fetch<{ user: User }>('/api/auth/me');
      user.value = data.user;
    } catch {
      user.value = null;
    }
  }

  function logout() {
    user.value = null;
    const cookie = useCookie('auth_token');
    cookie.value = null;
  }

  return {
    user,
    isAuthenticated,
    isAdmin,
    setUser,
    fetchProfile,
    logout,
  };
});
```

---

## 2. Aislamiento de Estado en SSR

1. **Evitar fugas de estado entre usuarios**:
   En SSR con Node.js, nunca declares estado reactivo global fuera de la función de `defineStore()`. Todo estado debe estar encapsulado dentro del closure del store para que Pinia lo asocie a la instancia de la petición actual (`nuxtApp`).
2. **Hidratación automática**:
   Nuxt serializa el estado de Pinia devuelto durante SSR y lo inyecta en el cliente a través del payload `__NUXT__.pinia`. No inicialices datos duplicados en `onMounted` si ya fueron resueltos en el servidor.
