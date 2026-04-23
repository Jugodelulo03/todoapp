# Imagen base liviana con Node.js 18 sobre Debian Bullseye.
FROM node:18-bullseye-slim

# Dependencias del sistema necesarias para compilar modulos nativos de npm.
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

# Carpeta de trabajo dentro del contenedor.
WORKDIR /app

# Copiamos primero los manifiestos para aprovechar mejor la cache de Docker.
COPY package.json yarn.lock ./
# En la imagen final solo se instalan dependencias de produccion.
RUN npm install --omit=dev --no-package-lock

# Copia el codigo fuente de la aplicacion.
COPY src ./src

# La app escucha en el puerto 3000 dentro del contenedor.
EXPOSE 3000

# Comando principal que arranca la API al iniciar el contenedor.
CMD ["node", "src/index.js"]
