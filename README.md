# ToDoApp con CI/CD en Jenkins

Aplicacion de tareas construida con Node.js y Express, preparada para ejecutarse en desarrollo con SQLite y desplegarse con MySQL, Nginx, Docker Compose y Jenkins.

Este repositorio fue adaptado para el reto de CI/CD del workshop usando Jenkins como herramienta principal.

Para una explicacion detallada del proceso realizado durante el reto, revisa [README.presentacion.md](README.presentacion.md).

Para una explicacion detallada y orientada a principiantes de `docker-compose.yml`, `Dockerfile`, `Jenkinsfile` y `Vagrantfile`, revisa [README.archivos.md](README.archivos.md).

## Arquitectura

- `src/`: aplicacion Express y rutas REST.
- `Dockerfile`: imagen de la aplicacion.
- `docker-compose.yml`: stack de despliegue con `app`, `db` y `nginx`.
- `Jenkinsfile`: pipeline declarativo de CI/CD.
- `Vagrantfile`: provisionamiento de las VMs `jenkins-server` y `app-agent`.

Flujo general:

1. Jenkins clona el repositorio desde GitHub.
2. El agente `docker-agent` ejecuta pruebas dentro de un contenedor `node:18-bullseye`.
3. Jenkins construye la imagen Docker y la publica en Docker Hub.
4. El agente despliega con Docker Compose.
5. Se ejecuta un smoke test contra `http://localhost/items`.

## Requisitos

### Desarrollo local

- Node.js 18 o superior
- npm

### Ejecucion con contenedores

- Docker
- Docker Compose

### Infraestructura del workshop

- Vagrant 2.4+
- VirtualBox 7+
- Acceso a Docker Hub

En Windows, si `vagrant` no encuentra `VBoxManage`, agrega esta ruta al `PATH` de la sesion:

```powershell
$env:PATH = "C:\Program Files\Oracle\VirtualBox;" + $env:PATH
```

## Variables de entorno

Ejemplo base en `.env.example`:

```env
APP_IMAGE=todoapp:local
MYSQL_DATABASE=todoapp
MYSQL_USER=todoapp
MYSQL_PASSWORD=change-me
MYSQL_ROOT_PASSWORD=change-me
```

Variables importantes:

- `APP_IMAGE`: nombre de la imagen a desplegar.
- `MYSQL_DATABASE`: base de datos de la aplicacion.
- `MYSQL_USER`: usuario de aplicacion.
- `MYSQL_PASSWORD`: password del usuario de aplicacion.
- `MYSQL_ROOT_PASSWORD`: password del usuario root de MySQL.
- `SQLITE_DB_LOCATION`: ruta del archivo SQLite para desarrollo o pruebas locales.

## Ejecucion local

La aplicacion usa SQLite cuando `MYSQL_HOST` no esta definido.

```powershell
npm install
New-Item -ItemType Directory -Force .\.tmp | Out-Null
$env:SQLITE_DB_LOCATION = (Join-Path (Get-Location).Path '.tmp\todo.db')
npm run dev
```

Endpoints utiles en desarrollo:

- `http://localhost:3000/`: interfaz web.
- `http://localhost:3000/items`: API que devuelve un arreglo JSON de tareas.

## Ejecucion con Docker Compose

1. Crea un archivo de entorno a partir del ejemplo.
2. Ajusta las contrasenas.
3. Levanta el stack.

```powershell
Copy-Item .env.example .env.deploy
docker compose --env-file .env.deploy up --build -d
```

Verificacion:

```powershell
docker compose --env-file .env.deploy ps
curl http://localhost/items
```

Para detener y limpiar el stack:

```powershell
docker compose --env-file .env.deploy down
```

Si tambien quieres borrar la base de datos persistida:

```powershell
docker compose --env-file .env.deploy down -v
```

## Jenkins + Vagrant

El `Vagrantfile` crea dos maquinas virtuales:

- `jenkins-server` en `192.168.56.10`
- `app-agent` en `192.168.56.11`

Provisionamiento:

```powershell
$env:PATH = "C:\Program Files\Oracle\VirtualBox;" + $env:PATH
vagrant up
```

Servicios instalados:

- Jenkins con Java 21 en `jenkins-server`
- Docker, Docker Compose, Git y Java 21 en `app-agent`

Accesos esperados:

- Jenkins: `http://192.168.56.10:8080`
- Aplicacion desplegada: `http://192.168.56.11/`
- API desplegada: `http://192.168.56.11/items`

## Configuracion minima de Jenkins

1. Desbloquear Jenkins con la password inicial.
2. Crear el nodo SSH con label `docker-agent`.
3. Configurar el nodo con host `192.168.56.11` y puerto `22`.
4. Crear las credenciales:
   - `dockerhub`
   - `todo-mysql-password`
   - `todo-mysql-root-password`
5. Crear un pipeline desde SCM apuntando al fork del repositorio.

## Etapas del pipeline

El `Jenkinsfile` ejecuta estas etapas:

1. `Checkout`: obtiene el codigo y genera el tag de imagen.
2. `Test`: instala dependencias y ejecuta `npm test -- --runInBand` dentro de un contenedor Linux.
3. `Build And Release`: construye la imagen y la publica en Docker Hub.
4. `Deploy`: genera `.env.deploy` y levanta el stack con Docker Compose.
5. `Smoke Test`: valida que `http://localhost/items` responda correctamente.

## Solucion de problemas

### `docker-agent is offline`

Verifica que el nodo SSH use `192.168.56.11` como host y no el puerto reenviado `127.0.0.1:2200` de Vagrant.

### `VBoxManage` no se encuentra

Agrega VirtualBox al `PATH` de la sesion de PowerShell antes de ejecutar `vagrant`.

### `502` en el smoke test

Si Nginx responde `502`, revisa los logs del contenedor `app`. La causa reportada durante el reto fue la incompatibilidad entre MySQL 8 y el cliente Node antiguo; se corrigio usando `mysql2` en la capa de persistencia.

## Comandos utiles

```powershell
# Estado de las VMs
vagrant status

# Entrar al agente
vagrant ssh app-agent

# Ver estado del stack en el agente
cd /home/vagrant/jenkins-agent/workspace/todoapp-pipeline
docker compose ps

# Ver logs de la app
docker compose logs --tail=100 app
```

## Resultado esperado

Cuando todo esta correcto:

- Jenkins termina en `Successful build`.
- `http://192.168.56.11/` muestra la interfaz de ToDoApp.
- `http://192.168.56.11/items` responde `200` con un arreglo JSON.
