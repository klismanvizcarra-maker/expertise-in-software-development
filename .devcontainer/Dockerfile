FROM mcr.microsoft.com/devcontainers/javascript-node:1-22-bookworm

# Actualizar paquetes e instalar dependencias del entorno multi-agente
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        git \
        curl \
        procps \
        ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Configurar directorio de trabajo
WORKDIR /workspaces/skill-maestro

# Mantener permisos adecuados para el usuario 'node'
RUN chown -R node:node /workspaces
USER node
