# Presentacion Paso a Paso del Reto CI/CD con Jenkins

Este documento resume, en orden, lo que se realizo para completar el reto de CI/CD usando Jenkins sobre el proyecto ToDoApp.

## 1. Objetivo del reto

El objetivo fue tomar la aplicacion ToDoApp, preparar su automatizacion de integracion y despliegue continuo, y ejecutarla con Jenkins usando una arquitectura con dos maquinas virtuales:

- una VM para Jenkins
- una VM para el agente que ejecuta Docker y despliega la app

## 2. Estado inicial

Al inicio del trabajo no habia una estructura completa de CI/CD en el repositorio de trabajo. Fue necesario:

1. revisar el reto del workshop
2. traer el fork del proyecto al workspace
3. entender la estructura de la aplicacion
4. preparar la infraestructura y el pipeline

## 3. Analisis de la aplicacion

Se reviso el proyecto para identificar:

- scripts disponibles en `package.json`
- puerto de escucha de la app
- rutas HTTP disponibles
- forma de persistencia de datos

Hallazgos principales:

1. La app esta hecha con Node.js y Express.
2. La app expone la ruta `/items` para consultar tareas.
3. En desarrollo puede trabajar con SQLite.
4. En despliegue se conecta a MySQL cuando existe `MYSQL_HOST`.

## 4. Preparacion de archivos de CI/CD

Se agregaron y ajustaron los archivos necesarios para automatizar el flujo:

1. `Jenkinsfile`
2. `Dockerfile`
3. `docker-compose.yml`
4. `nginx/default.conf`
5. `.dockerignore`
6. `.gitignore`
7. `.env.example`
8. `Vagrantfile`

Cada archivo tuvo una funcion especifica:

- `Jenkinsfile`: define el pipeline completo.
- `Dockerfile`: construye la imagen de la aplicacion.
- `docker-compose.yml`: levanta app, base de datos y Nginx.
- `default.conf`: configura el reverse proxy.
- `Vagrantfile`: aprovisiona la infraestructura del reto.

## 5. Diseno de la infraestructura

Se implemento el patron pedido por el reto con dos VMs:

### Jenkins Server

- hostname: `jenkins-server`
- IP privada: `192.168.56.10`
- servicios: Jenkins, Git, Java 21

### App Agent

- hostname: `app-agent`
- IP privada: `192.168.56.11`
- servicios: Docker, Docker Compose, Git, Java 21

La razon de separar estas VMs fue cumplir el enfoque correcto de Jenkins: el servidor coordina y el agente ejecuta la carga de trabajo.

## 6. Provisionamiento con Vagrant

Se levanto la infraestructura con `Vagrant` y `VirtualBox`.

Durante esta etapa hubo varios ajustes:

1. En Windows, `VBoxManage` no estaba en `PATH`.
2. Se corrigio la instalacion de Jenkins para usar la llave y repositorio oficiales.
3. Se corrigio el aprovisionamiento de Docker para evitar errores de `gpg` con TTY.
4. Se verifico que el usuario `vagrant` quedara en el grupo `docker`.

Resultado de esta fase:

- Jenkins quedo activo en la VM `jenkins-server`.
- El agente quedo listo para ejecutar contenedores y pipelines.

## 7. Configuracion de Jenkins

Una vez levantada la infraestructura, se hizo la configuracion funcional del servidor Jenkins:

1. se obtuvo la password inicial de Jenkins
2. se ingreso al panel web
3. se creo el nodo SSH del agente
4. se asigno la etiqueta `docker-agent`
5. se configuraron las credenciales requeridas

Credenciales usadas:

1. `dockerhub`
2. `todo-mysql-password`
3. `todo-mysql-root-password`

## 8. Error importante con el nodo SSH

Al principio el nodo aparecia offline por una configuracion incorrecta del host.

Problema:

- se intento usar la configuracion de reenvio de puertos de Vagrant (`127.0.0.1:2200`)

Correccion:

- se configuro Jenkins para conectarse por la red privada entre VMs
- host correcto: `192.168.56.11`
- puerto correcto: `22`

Con eso el nodo `docker-agent` pudo ejecutar el pipeline.

## 9. Flujo del pipeline implementado

El pipeline quedo dividido en cinco etapas:

### 1. Checkout

Jenkins clona el repositorio desde GitHub y calcula un tag corto con el commit.

### 2. Test

Se ejecutan las pruebas dentro de un contenedor `node:18-bullseye` para asegurar consistencia con un entorno Linux.

Esto fue importante porque la ejecucion local en Windows no era representativa del entorno real del pipeline.

### 3. Build And Release

Se construye la imagen Docker de la aplicacion y se publica en Docker Hub.

### 4. Deploy

Se genera el archivo `.env.deploy`, se hace `docker compose pull` y luego `docker compose up -d --remove-orphans`.

### 5. Smoke Test

Se valida que la aplicacion ya desplegada responda en `http://localhost/items`.

## 10. Error en despliegue: 502 durante el smoke test

Durante la primera ejecucion del pipeline aparecio un `502` en el smoke test.

Diagnostico realizado:

1. Nginx estaba levantado.
2. MySQL estaba levantado y sano.
3. El contenedor `app` reiniciaba constantemente.
4. Los logs de la app mostraron el error `ER_NOT_SUPPORTED_AUTH_MODE`.

Causa raiz:

- la aplicacion estaba intentando conectarse a MySQL 8 con un cliente Node no compatible con el plugin de autenticacion por defecto.

Correccion aplicada:

- se ajusto la capa de persistencia para usar `mysql2`

Con ese cambio, la aplicacion pudo conectarse correctamente a la base de datos y el despliegue termino bien.

## 11. Incidencias adicionales resueltas

Durante el reto tambien se atendieron estos puntos:

1. Archivos `:Zone.Identifier` que afectaban el fork en Windows.
2. Diferencias entre pruebas locales en Windows y pruebas dentro del contenedor Linux.
3. Mensajes temporales de agente offline durante el deploy.
4. Esperas normales por descarga de imagenes y healthcheck de MySQL en la primera ejecucion.

## 12. Resultado final

El flujo termino en `Successful build`, lo que confirma:

1. checkout exitoso del codigo
2. pruebas automatizadas aprobadas
3. imagen construida y publicada
4. despliegue correcto en el agente
5. smoke test satisfactorio

Verificaciones finales esperadas:

- `http://192.168.56.11/` muestra la interfaz de la aplicacion
- `http://192.168.56.11/items` responde con JSON
- Jenkins muestra el job en verde

## 13. Que mostrar en la presentacion

Si necesitas exponer el trabajo, este orden funciona bien:

1. explicar el objetivo del reto
2. mostrar la arquitectura de dos VMs
3. enseñar el `Jenkinsfile` y las etapas del pipeline
4. mostrar `docker-compose.yml` y los servicios desplegados
5. comentar el problema real del `502` y como se diagnostico
6. cerrar con la evidencia de `Successful build`

## 14. Guion corto para explicar el trabajo

Puedes presentarlo asi:

> Tome el fork de ToDoApp y prepare toda la estructura de CI/CD con Jenkins. Cree el pipeline, la imagen Docker, el despliegue con Docker Compose y la infraestructura con Vagrant para separar el servidor Jenkins del agente. Luego configure Jenkins para ejecutar el pipeline sobre el nodo `docker-agent`. Durante las pruebas aparecio un error 502 en el smoke test; al revisar logs detecte una incompatibilidad entre la app y MySQL 8, la corregi en la capa de persistencia usando `mysql2`, y despues de eso el pipeline completo termino en `Successful build`.

## 15. Cierre

El reto no solo quedo funcionando, sino documentado y reproducible. El repositorio ya contiene la configuracion necesaria para volver a levantar el entorno y repetir la demostracion.
