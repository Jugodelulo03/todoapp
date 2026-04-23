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
