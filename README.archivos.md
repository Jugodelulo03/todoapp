# Guia Detallada de Archivos de Infraestructura

Este documento explica, de forma pedagogica, que hace cada parte de estos archivos:

1. `docker-compose.yml`
2. `Dockerfile`
3. `Jenkinsfile`
4. `Vagrantfile`

Objetivo de esta guia:

- ayudarte a entender que hace cada linea importante
- mostrar como se conectan Docker, Jenkins y Vagrant
- servirte como material de estudio para la presentacion

Nota: las lineas que solo abren o cierran bloques, como `{`, `}`, `do`, `end` o niveles de indentacion, se explican junto a la linea anterior o la linea del bloque al que pertenecen.

## 1. docker-compose.yml

### Que hace este archivo

Este archivo define el despliegue de tres contenedores:

1. `app`: la aplicacion Node.js
2. `db`: la base de datos MySQL
3. `nginx`: el proxy inverso que expone la app por el puerto 80

### Contenido explicado

```yaml
services:
  app:
    build:
      context: .
    image: ${APP_IMAGE:-todoapp:local}
    restart: unless-stopped
    environment:
      MYSQL_HOST: db
      MYSQL_DB: ${MYSQL_DATABASE:-todoapp}
      MYSQL_USER: ${MYSQL_USER:-todoapp}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    depends_on:
      db:
        condition: service_healthy
    expose:
      - "3000"

  db:
    image: mysql:8.0
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE:-todoapp}
      MYSQL_USER: ${MYSQL_USER:-todoapp}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -uroot -p$$MYSQL_ROOT_PASSWORD --silent"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s
    volumes:
      - mysql-data:/var/lib/mysql

  nginx:
    image: nginx:1.27-alpine
    restart: unless-stopped
    depends_on:
      - app
    ports:
      - "80:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro

volumes:
  mysql-data:
```

### Explicacion linea por linea

1. `services:`
Define la lista de contenedores que Docker Compose va a administrar.

2. `app:`
Empieza la definicion del servicio de la aplicacion.

3. `build:`
Indica que la imagen de la app puede construirse localmente.

4. `context: .`
Le dice a Docker que use la carpeta actual como contexto de build. Eso significa que puede leer el `Dockerfile`, `src/`, `package.json` y demas archivos del proyecto.

5. `image: ${APP_IMAGE:-todoapp:local}`
Define el nombre de la imagen. Si existe la variable `APP_IMAGE`, usa ese valor. Si no existe, usa `todoapp:local`.

6. `restart: unless-stopped`
Le dice a Docker que reinicie el contenedor automaticamente si se cae, salvo que alguien lo detenga manualmente.

7. `environment:`
Empieza la seccion de variables de entorno para la app.

8. `MYSQL_HOST: db`
Le dice a la aplicacion que la base de datos esta en el servicio `db`. Docker Compose resuelve ese nombre internamente.

9. `MYSQL_DB: ${MYSQL_DATABASE:-todoapp}`
Nombre de la base de datos. Si no hay variable, usa `todoapp`.

10. `MYSQL_USER: ${MYSQL_USER:-todoapp}`
Usuario con el que la app se conecta a MySQL.

11. `MYSQL_PASSWORD: ${MYSQL_PASSWORD}`
Password del usuario anterior. Aqui no se pone un valor fijo para no exponer secretos en el repositorio.

12. `depends_on:`
Empieza la declaracion de dependencias de arranque.

13. `db:`
La app depende del servicio `db`.

14. `condition: service_healthy`
No basta con que el contenedor exista: Docker Compose espera a que el healthcheck de MySQL diga que la base ya esta sana.

15. `expose:`
Expone el puerto internamente dentro de la red de Docker Compose.

16. `- "3000"`
La app escucha en el puerto 3000, pero solo dentro de la red interna. No se publica directamente al host porque Nginx es quien la expone.

17. `db:`
Empieza el servicio de base de datos.

18. `image: mysql:8.0`
Usa la imagen oficial de MySQL 8.

19. `restart: unless-stopped`
MySQL tambien se reinicia automaticamente si falla.

20. `environment:`
Empieza las variables de entorno necesarias para inicializar MySQL.

21. `MYSQL_DATABASE: ${MYSQL_DATABASE:-todoapp}`
Crea una base de datos inicial llamada `todoapp` si no se define otro nombre.

22. `MYSQL_USER: ${MYSQL_USER:-todoapp}`
Crea un usuario de aplicacion.

23. `MYSQL_PASSWORD: ${MYSQL_PASSWORD}`
Asigna la contrasena del usuario de aplicacion.

24. `MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}`
Asigna la contrasena del usuario root de MySQL.

25. `healthcheck:`
Define como Docker comprueba si la base de datos ya esta lista.

26. `test: ["CMD-SHELL", "mysqladmin ping -h 127.0.0.1 -uroot -p$$MYSQL_ROOT_PASSWORD --silent"]`
Ejecuta un comando dentro del contenedor para confirmar que MySQL responde. Se usa `$$` para que Docker Compose no intente expandir esa variable antes de tiempo y se la deje al shell del contenedor.

27. `interval: 10s`
Hace la comprobacion cada 10 segundos.

28. `timeout: 5s`
Si la comprobacion tarda mas de 5 segundos, se considera fallida.

29. `retries: 10`
Permite hasta 10 intentos fallidos antes de marcar el servicio como no sano.

30. `start_period: 20s`
Da 20 segundos iniciales de margen antes de empezar a contar fallos.

31. `volumes:`
Empieza la definicion de volumenes montados en MySQL.

32. `- mysql-data:/var/lib/mysql`
Guarda los datos de MySQL en un volumen persistente llamado `mysql-data`. Eso evita perder la base cuando el contenedor se destruye.

33. `nginx:`
Empieza el servicio Nginx.

34. `image: nginx:1.27-alpine`
Usa una imagen ligera de Nginx basada en Alpine Linux.

35. `restart: unless-stopped`
Hace que Nginx tambien se reinicie automaticamente si falla.

36. `depends_on:`
Indica que Nginx depende de la app.

37. `- app`
Nginx arranca despues del servicio `app`.

38. `ports:`
Empieza la publicacion de puertos hacia la maquina host.

39. `- "80:80"`
Expone el puerto 80 del contenedor Nginx como puerto 80 de la maquina donde corre Docker. Por eso se puede abrir la aplicacion en el navegador sin escribir el puerto 3000.

40. `volumes:`
Empieza los montajes de archivos para Nginx.

41. `- ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro`
Monta el archivo de configuracion local de Nginx dentro del contenedor. `:ro` significa solo lectura.

42. `volumes:`
Empieza la lista global de volumenes de Docker Compose.

43. `mysql-data:`
Declara formalmente el volumen persistente usado por MySQL.

### Resumen mental rapido

- `app` corre la aplicacion
- `db` guarda los datos
- `nginx` recibe las peticiones web
- `mysql-data` evita perder informacion al reiniciar contenedores

## 2. Dockerfile

### Que hace este archivo

Este archivo dice como construir la imagen Docker de la aplicacion.

### Contenido explicado

```dockerfile
FROM node:18-bullseye-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json yarn.lock ./
RUN npm install --omit=dev --no-package-lock

COPY src ./src

EXPOSE 3000

CMD ["node", "src/index.js"]
```

### Explicacion linea por linea

1. `FROM node:18-bullseye-slim`
Define la imagen base. Aqui partimos de una imagen oficial de Node.js 18 sobre Debian Bullseye en su variante reducida `slim`.

2. `RUN apt-get update \`
Actualiza el indice de paquetes de Debian dentro de la imagen.

3. `&& apt-get install -y --no-install-recommends python3 make g++ \`
Instala herramientas de compilacion. Son utiles porque algunas dependencias de Node, como `sqlite3`, pueden necesitar compilar modulos nativos.

4. `&& rm -rf /var/lib/apt/lists/*`
Limpia la cache de `apt` para que la imagen final pese menos.

5. `WORKDIR /app`
Define `/app` como carpeta de trabajo dentro del contenedor. A partir de aqui, las siguientes instrucciones se ejecutan desde esa ruta.

6. `COPY package.json yarn.lock ./`
Copia los archivos de definicion de dependencias al contenedor.

7. `RUN npm install --omit=dev --no-package-lock`
Instala dependencias de produccion, dejando fuera las de desarrollo. `--no-package-lock` evita generar o usar `package-lock.json` durante la build.

8. `COPY src ./src`
Copia el codigo fuente de la aplicacion.

9. `EXPOSE 3000`
Documenta que el contenedor escucha en el puerto 3000. No publica el puerto por si solo, pero sirve como convencion para quien use la imagen.

10. `CMD ["node", "src/index.js"]`
Define el comando principal del contenedor: arrancar la aplicacion Node.js.

### Resumen mental rapido

1. partir de Node.js
2. instalar herramientas del sistema
3. copiar dependencias
4. instalar paquetes npm
5. copiar el codigo
6. arrancar la app

## 3. Jenkinsfile

### Que hace este archivo

Este archivo define el pipeline de CI/CD de Jenkins. Es el corazon de la automatizacion.

### Contenido explicado

```groovy
pipeline {
    agent { label 'docker-agent' }

    options {
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        IMAGE_REPOSITORY = 'todoapp'
        DEPLOY_ENV_FILE = '.env.deploy'
        MYSQL_DATABASE = 'todoapp'
        MYSQL_USER = 'todoapp'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.SHORT_COMMIT = sh(
                        script: 'git rev-parse --short=7 HEAD',
                        returnStdout: true,
                    ).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.SHORT_COMMIT}"
                }
            }
        }

        stage('Test') {
            steps {
                sh '''
                    set -eu
                    docker run --rm \
                      --user "$(id -u):$(id -g)" \
                      -v "$WORKSPACE:/workspace" \
                      -w /workspace \
                      -e SQLITE_DB_LOCATION=/tmp/todo.db \
                      node:18-bullseye \
                      bash -lc "npm install --include=dev --no-package-lock && npm test -- --runInBand"
                '''
            }
        }

        stage('Build And Release') {
            when {
                expression {
                    !env.BRANCH_NAME || env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master'
                }
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_TOKEN',
                    ),
                ]) {
                    sh '''
                        set -eu
                        export APP_IMAGE="$DOCKERHUB_USERNAME/$IMAGE_REPOSITORY:$IMAGE_TAG"
                        export MYSQL_PASSWORD=build-only
                        export MYSQL_ROOT_PASSWORD=build-only
                        echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
                        docker compose build app
                        docker compose push app
                        docker logout
                    '''
                }
            }
        }

        stage('Deploy') {
            when {
                expression {
                    !env.BRANCH_NAME || env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master'
                }
            }
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_TOKEN',
                    ),
                    string(
                        credentialsId: 'todo-mysql-password',
                        variable: 'MYSQL_PASSWORD',
                    ),
                    string(
                        credentialsId: 'todo-mysql-root-password',
                        variable: 'MYSQL_ROOT_PASSWORD',
                    ),
                ]) {
                    sh '''
                        set -eu
                        cat > "$DEPLOY_ENV_FILE" <<EOF
APP_IMAGE=$DOCKERHUB_USERNAME/$IMAGE_REPOSITORY:$IMAGE_TAG
MYSQL_DATABASE=$MYSQL_DATABASE
MYSQL_USER=$MYSQL_USER
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
EOF
                        echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
                        docker compose --env-file "$DEPLOY_ENV_FILE" pull
                        docker compose --env-file "$DEPLOY_ENV_FILE" up -d --remove-orphans
                        docker logout
                    '''
                }
            }
        }

        stage('Smoke Test') {
            when {
                expression {
                    !env.BRANCH_NAME || env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master'
                }
            }
            steps {
                sh '''
                    set -eu
                    for attempt in $(seq 1 15); do
                        if curl --silent --fail http://localhost/items >/dev/null; then
                            exit 0
                        fi
                        sleep 2
                    done
                    curl --fail http://localhost/items
                '''
            }
        }
    }

    post {
        always {
            sh 'rm -f "$DEPLOY_ENV_FILE" package-lock.json; rm -rf .tmp node_modules'
            archiveArtifacts artifacts: 'Dockerfile,Jenkinsfile,Vagrantfile,docker-compose.yml,nginx/default.conf', fingerprint: true
        }
    }
}
```

### Explicacion linea por linea

1. `pipeline {`
Empieza la definicion del pipeline declarativo de Jenkins.

2. `agent { label 'docker-agent' }`
Le dice a Jenkins que este pipeline debe correr en un nodo que tenga la etiqueta `docker-agent`.

3. `options {`
Empieza opciones globales del pipeline.

4. `disableConcurrentBuilds()`
Evita que Jenkins ejecute dos builds del mismo job al mismo tiempo.

5. `timestamps()`
Hace que el log muestre hora en cada linea para facilitar diagnosticos.

6. `environment {`
Empieza variables globales del pipeline.

7. `IMAGE_REPOSITORY = 'todoapp'`
Nombre del repositorio de imagen en Docker.

8. `DEPLOY_ENV_FILE = '.env.deploy'`
Nombre del archivo temporal que se genera para el despliegue.

9. `MYSQL_DATABASE = 'todoapp'`
Nombre de la base que se pasara al despliegue.

10. `MYSQL_USER = 'todoapp'`
Usuario de MySQL que usara la app.

11. `stages {`
Empieza la lista de etapas del pipeline.

12. `stage('Checkout') {`
Primera etapa: obtener el codigo fuente.

13. `steps {`
Empieza las acciones de esta etapa.

14. `checkout scm`
Jenkins descarga el repositorio configurado en el job.

15. `script {`
Permite ejecutar logica Groovy un poco mas flexible dentro de un pipeline declarativo.

16. `env.SHORT_COMMIT = sh(...)`
Ejecuta un comando shell y guarda su salida en una variable de entorno llamada `SHORT_COMMIT`.

17. `script: 'git rev-parse --short=7 HEAD',`
Obtiene el hash corto del commit actual, con 7 caracteres.

18. `returnStdout: true,`
Le pide a Jenkins que devuelva la salida del comando en vez de solo ejecutarlo.

19. `).trim()`
Quita espacios o saltos de linea al final del texto obtenido.

20. `env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.SHORT_COMMIT}"`
Genera una etiqueta unica para la imagen Docker, por ejemplo `15-ab12cd3`.

21. `stage('Test') {`
Empieza la etapa de pruebas.

22. `sh ''' ... '''`
Ejecuta un bloque de comandos shell en el agente Linux.

23. `set -eu`
`-e` hace que el script falle si un comando falla. `-u` hace que falle si se usa una variable no definida.

24. `docker run --rm \`
Lanza un contenedor temporal para ejecutar las pruebas. `--rm` lo borra al terminar.

25. `--user "$(id -u):$(id -g)" \`
Hace que el contenedor use el mismo usuario y grupo del agente para evitar problemas de permisos en archivos generados.

26. `-v "$WORKSPACE:/workspace" \`
Monta el workspace de Jenkins dentro del contenedor.

27. `-w /workspace \`
Define `/workspace` como directorio de trabajo dentro del contenedor.

28. `-e SQLITE_DB_LOCATION=/tmp/todo.db \`
Fuerza a las pruebas a usar SQLite temporal en vez de MySQL.

29. `node:18-bullseye \`
Imagen base usada solo para correr pruebas.

30. `bash -lc "npm install --include=dev --no-package-lock && npm test -- --runInBand"`
Instala dependencias incluyendo las de desarrollo y luego ejecuta Jest en modo secuencial.

31. `stage('Build And Release') {`
Empieza la etapa de construccion y publicacion de imagen.

32. `when { expression { ... } }`
Hace que esta etapa solo se ejecute en ramas principales como `main` o `master`.

33. `withCredentials([ ... ]) {`
Carga credenciales seguras desde Jenkins para usarlas dentro del bloque.

34. `usernamePassword(...)`
Toma una credencial de usuario y password.

35. `credentialsId: 'dockerhub',`
Nombre de la credencial guardada en Jenkins.

36. `usernameVariable: 'DOCKERHUB_USERNAME',`
Guarda el usuario en esta variable temporal.

37. `passwordVariable: 'DOCKERHUB_TOKEN',`
Guarda el token o password en esta otra variable temporal.

38. `set -eu`
Mantiene el comportamiento estricto del script shell.

39. `export APP_IMAGE="$DOCKERHUB_USERNAME/$IMAGE_REPOSITORY:$IMAGE_TAG"`
Construye el nombre completo de la imagen, por ejemplo `usuario/todoapp:15-ab12cd3`.

40. `export MYSQL_PASSWORD=build-only`
Define una password ficticia solo para satisfacer variables requeridas durante la build.

41. `export MYSQL_ROOT_PASSWORD=build-only`
Lo mismo para el usuario root. Aqui no se despliega todavia, solo se construye la imagen.

42. `echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin`
Inicia sesion en Docker Hub sin mostrar el secreto en el log.

43. `docker compose build app`
Construye la imagen del servicio `app` usando `docker-compose.yml`.

44. `docker compose push app`
Publica la imagen del servicio `app` en Docker Hub.

45. `docker logout`
Cierra la sesion de Docker por limpieza y seguridad.

46. `stage('Deploy') {`
Empieza la etapa de despliegue.

47. `when { expression { ... } }`
Igual que antes: solo despliega desde ramas principales.

48. `withCredentials([ ... ]) {`
Carga tanto credenciales de Docker Hub como secretos de MySQL.

49. `string(credentialsId: 'todo-mysql-password', variable: 'MYSQL_PASSWORD')`
Trae el password del usuario de MySQL desde Jenkins.

50. `string(credentialsId: 'todo-mysql-root-password', variable: 'MYSQL_ROOT_PASSWORD')`
Trae el password root de MySQL.

51. `cat > "$DEPLOY_ENV_FILE" <<EOF`
Crea un archivo `.env.deploy` con las variables necesarias para Docker Compose.

52. `APP_IMAGE=...`
Guarda el nombre de la imagen que se debe desplegar.

53. `MYSQL_DATABASE=...`
Guarda el nombre de la base de datos.

54. `MYSQL_USER=...`
Guarda el usuario de MySQL.

55. `MYSQL_PASSWORD=...`
Guarda el password del usuario de MySQL.

56. `MYSQL_ROOT_PASSWORD=...`
Guarda el password root.

57. `EOF`
Marca el final del archivo generado en shell.

58. `echo "$DOCKERHUB_TOKEN" | docker login ...`
Inicia sesion otra vez en Docker Hub para poder hacer `pull` si hace falta.

59. `docker compose --env-file "$DEPLOY_ENV_FILE" pull`
Descarga la imagen indicada en el archivo de entorno.

60. `docker compose --env-file "$DEPLOY_ENV_FILE" up -d --remove-orphans`
Levanta o actualiza el stack en segundo plano y elimina contenedores viejos que ya no pertenezcan al compose actual.

61. `docker logout`
Cierra la sesion de Docker al terminar el despliegue.

62. `stage('Smoke Test') {`
Empieza la etapa de comprobacion rapida posterior al despliegue.

63. `for attempt in $(seq 1 15); do`
Hace hasta 15 intentos para dar tiempo a que la aplicacion termine de arrancar.

64. `if curl --silent --fail http://localhost/items >/dev/null; then`
Prueba si el endpoint `/items` responde con exito.

65. `exit 0`
Si responde bien, se termina la etapa con exito inmediatamente.

66. `sleep 2`
Espera 2 segundos antes del siguiente intento.

67. `curl --fail http://localhost/items`
Si los intentos se agotan, hace una ultima llamada visible para que el error quede registrado en el log.

68. `post { always { ... } }`
Empieza acciones finales que siempre se ejecutan, salga bien o salga mal el pipeline.

69. `sh 'rm -f "$DEPLOY_ENV_FILE" package-lock.json; rm -rf .tmp node_modules'`
Limpia archivos temporales o generados durante la build.

70. `archiveArtifacts artifacts: 'Dockerfile,Jenkinsfile,Vagrantfile,docker-compose.yml,nginx/default.conf', fingerprint: true`
Guarda esos archivos como artefactos del build para auditoria o consulta posterior. `fingerprint: true` ayuda a rastrearlos entre builds.

71. `}`
Cierra el pipeline.

### Resumen mental rapido

1. descargar codigo
2. probar codigo
3. construir imagen
4. publicar imagen
5. desplegar stack
6. probar que el despliegue responda

## 4. Vagrantfile

### Que hace este archivo

Este archivo levanta la infraestructura virtual del reto: una VM para Jenkins y otra para el agente.

### Contenido explicado

```ruby
Vagrant.configure('2') do |config|
  config.vm.box = 'bento/ubuntu-22.04'

  config.vm.provider 'virtualbox' do |vb|
    vb.memory = 2048
    vb.cpus = 2
  end

  config.vm.define 'jenkins-server' do |jenkins|
    jenkins.vm.hostname = 'jenkins-server'
    jenkins.vm.network 'private_network', ip: '192.168.56.10'

    jenkins.vm.provision 'shell', inline: <<-SHELL
      rm -f /etc/apt/sources.list.d/jenkins.list
      rm -f /etc/apt/keyrings/jenkins-keyring.asc
      apt-get update
      apt-get install -y ca-certificates curl fontconfig git gnupg openjdk-21-jre
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc
      echo deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list
      apt-get update
      apt-get install -y jenkins
      systemctl enable --now jenkins
    SHELL
  end

  config.vm.define 'app-agent' do |agent|
    agent.vm.hostname = 'app-agent'
    agent.vm.network 'private_network', ip: '192.168.56.11'

    agent.vm.provision 'shell', inline: <<-SHELL
      apt-get update
      apt-get install -y ca-certificates curl git gnupg openjdk-21-jre-headless
      install -m 0755 -d /etc/apt/keyrings
      rm -f /etc/apt/keyrings/docker.gpg
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.asc
      gpg --dearmor --batch --yes --no-tty -o /etc/apt/keyrings/docker.gpg /tmp/docker.asc
      rm -f /tmp/docker.asc
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      usermod -aG docker vagrant
      mkdir -p /home/vagrant/jenkins-agent
      chown -R vagrant:vagrant /home/vagrant/jenkins-agent
    SHELL
  end
end
```

### Explicacion linea por linea

1. `Vagrant.configure('2') do |config|`
Empieza la configuracion de Vagrant usando la version 2 del formato.

2. `config.vm.box = 'bento/ubuntu-22.04'`
Define la imagen base que usaran las maquinas virtuales: Ubuntu 22.04 mantenido por Bento.

3. `config.vm.provider 'virtualbox' do |vb|`
Empieza la configuracion especifica del proveedor VirtualBox.

4. `vb.memory = 2048`
Asigna 2048 MB de RAM a cada VM.

5. `vb.cpus = 2`
Asigna 2 CPUs virtuales a cada VM.

6. `config.vm.define 'jenkins-server' do |jenkins|`
Empieza la definicion de la VM del servidor Jenkins.

7. `jenkins.vm.hostname = 'jenkins-server'`
Define el nombre interno de host de esa maquina.

8. `jenkins.vm.network 'private_network', ip: '192.168.56.10'`
Le asigna una IP privada fija para que otras VMs y tu host puedan localizarla facilmente.

9. `jenkins.vm.provision 'shell', inline: <<-SHELL`
Empieza un script shell que se ejecuta automaticamente al provisionar la VM.

10. `rm -f /etc/apt/sources.list.d/jenkins.list`
Elimina configuraciones antiguas del repositorio de Jenkins para evitar duplicados o errores.

11. `rm -f /etc/apt/keyrings/jenkins-keyring.asc`
Elimina una llave vieja de Jenkins si existia.

12. `apt-get update`
Actualiza la lista de paquetes del sistema.

13. `apt-get install -y ca-certificates curl fontconfig git gnupg openjdk-21-jre`
Instala dependencias basicas y Java 21, necesario para Jenkins.

14. `install -m 0755 -d /etc/apt/keyrings`
Crea la carpeta de keyrings con permisos adecuados.

15. `curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc`
Descarga la llave oficial del repositorio de Jenkins.

16. `echo deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list`
Registra el repositorio oficial de Jenkins en `apt`.

17. `apt-get update`
Vuelve a actualizar la lista de paquetes, ahora incluyendo Jenkins.

18. `apt-get install -y jenkins`
Instala Jenkins.

19. `systemctl enable --now jenkins`
Activa y arranca el servicio Jenkins inmediatamente.

20. `config.vm.define 'app-agent' do |agent|`
Empieza la definicion de la VM del agente.

21. `agent.vm.hostname = 'app-agent'`
Nombre interno de host del agente.

22. `agent.vm.network 'private_network', ip: '192.168.56.11'`
Asigna una IP privada fija al agente.

23. `agent.vm.provision 'shell', inline: <<-SHELL`
Empieza el script de aprovisionamiento del agente.

24. `apt-get update`
Actualiza lista de paquetes.

25. `apt-get install -y ca-certificates curl git gnupg openjdk-21-jre-headless`
Instala herramientas base y Java 21 sin entorno grafico.

26. `install -m 0755 -d /etc/apt/keyrings`
Crea el directorio donde se guardaran llaves para `apt`.

27. `rm -f /etc/apt/keyrings/docker.gpg`
Elimina una llave anterior de Docker para evitar conflictos.

28. `curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.asc`
Descarga la llave oficial de Docker.

29. `gpg --dearmor --batch --yes --no-tty -o /etc/apt/keyrings/docker.gpg /tmp/docker.asc`
Convierte la llave al formato que `apt` necesita y evita problemas interactivos con TTY.

30. `rm -f /tmp/docker.asc`
Elimina el archivo temporal descargado.

31. `chmod a+r /etc/apt/keyrings/docker.gpg`
Da permisos de lectura para que `apt` pueda usar la llave.

32. `echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" > /etc/apt/sources.list.d/docker.list`
Registra el repositorio oficial de Docker usando la arquitectura y version de Ubuntu de esa VM.

33. `apt-get update`
Actualiza la lista de paquetes para incluir Docker.

34. `apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
Instala Docker Engine, su CLI, containerd, Buildx y el plugin de Docker Compose.

35. `usermod -aG docker vagrant`
Agrega al usuario `vagrant` al grupo `docker` para que pueda ejecutar comandos Docker sin `sudo`.

36. `mkdir -p /home/vagrant/jenkins-agent`
Crea la carpeta donde Jenkins usara su workspace en el agente.

37. `chown -R vagrant:vagrant /home/vagrant/jenkins-agent`
Asigna esa carpeta al usuario `vagrant` para evitar problemas de permisos.

38. `end`
Cierra la definicion de la VM del agente y luego la configuracion de Vagrant.

### Resumen mental rapido

1. crear 2 VMs
2. instalar Jenkins en una
3. instalar Docker en la otra
4. conectarlas por red privada
5. dejar listo el workspace del agente

## Relacion entre los 4 archivos

Estos archivos trabajan juntos asi:

1. `Vagrantfile` crea las maquinas virtuales.
2. `Jenkinsfile` define el pipeline que corre en el agente.
3. `Dockerfile` define como construir la imagen de la app.
4. `docker-compose.yml` define como desplegar esa imagen junto con MySQL y Nginx.

## Camino mental completo

Si quieres recordarlo facil, piensa asi:

1. Vagrant levanta las maquinas.
2. Jenkins coordina el proceso.
3. Dockerfile empaqueta la app.
4. Docker Compose levanta la app completa.
