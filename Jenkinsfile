pipeline {
    // Todo el pipeline debe ejecutarse en el agente que tenga Docker disponible.
    agent { label 'docker-agent' }

    options {
        // Evita dos builds simultaneos del mismo job para no pisar workspaces ni despliegues.
        disableConcurrentBuilds()
        // Agrega hora a cada linea del log para facilitar el diagnostico.
        timestamps()
    }

    environment {
        // Nombre base del repositorio de imagen que se publicara en Docker Hub.
        IMAGE_REPOSITORY = 'todoapp'
        // Archivo temporal con variables de entorno para el despliegue.
        DEPLOY_ENV_FILE = '.env.deploy'
        MYSQL_DATABASE = 'todoapp'
        MYSQL_USER = 'todoapp'
    }

    stages {
        // Descarga el codigo y prepara un tag reproducible para la imagen.
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // Usa el hash corto del commit para que el tag apunte exactamente al codigo construido.
                    env.SHORT_COMMIT = sh(
                        script: 'git rev-parse --short=7 HEAD',
                        returnStdout: true,
                    ).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.SHORT_COMMIT}"
                }
            }
        }

        // Ejecuta pruebas en un contenedor Linux aislado, sin depender del sistema operativo del host.
        stage('Test') {
            steps {
                // Monta el workspace de Jenkins dentro del contenedor y fuerza SQLite temporal.
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

        // Solo desde ramas principales se construye y publica una imagen reutilizable.
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
                    // Tag final que se publicara en Docker Hub.
                    // Estas variables completan docker-compose durante la build, pero no son secretos reales.
                    // Login, build y push de la imagen de la aplicacion.
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

        // Despliega la imagen publicada junto con MySQL y Nginx en el agente.
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
                    // Genera el archivo que docker compose usara para inyectar secretos y nombre de imagen.
                    // Descarga la imagen exacta y actualiza el stack en segundo plano.
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

        // Verifica que el despliegue ya responda por HTTP antes de dar el pipeline por exitoso.
        stage('Smoke Test') {
            when {
                expression {
                    !env.BRANCH_NAME || env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master'
                }
            }
            steps {
                // Reintenta varias veces porque MySQL y la app pueden tardar en quedar listos.
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
            // Limpia archivos temporales del workspace para dejar el agente listo para el siguiente build.
            sh 'rm -f "$DEPLOY_ENV_FILE" package-lock.json; rm -rf .tmp node_modules'
            // Guarda estos archivos como evidencia del build ejecutado.
            archiveArtifacts artifacts: 'Dockerfile,Jenkinsfile,Vagrantfile,docker-compose.yml,nginx/default.conf', fingerprint: true
        }
    }
}
