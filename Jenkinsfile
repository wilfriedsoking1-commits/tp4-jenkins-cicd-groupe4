pipeline {
    agent any

    environment {
        // Compte Docker Hub du chef d'equipe : Wilfried Keumeka Soking
        DOCKER_IMAGE      = "wilfriedsoking1/tp4-app-groupe4"
        DOCKER_CRED_ID    = "dockerhub-creds"
        STAGING_CONTAINER = "app-staging-g4"
        APP_PORT          = "3000"
        STAGING_PORT      = "3001"
    }

    options {
        // Le conteneur de staging occupe le port 3001 : un seul build a la fois
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        // ETAPE 1 - Recuperation du code source depuis GitHub
        stage('1. Clone du repository') {
            steps {
                echo "Clonage de la branche ${env.BRANCH_NAME} - commit ${env.GIT_COMMIT}"
                checkout scm
            }
        }

        // ETAPE 2 - Tests unitaires dans un conteneur Node.js jetable
        stage('2. Test de l application') {
            steps {
                sh '''
                    docker run --rm \
                        -v "$PWD/app":/app \
                        -w /app \
                        node:20-alpine \
                        sh -c "npm install --no-audit --no-fund && npm test"
                '''
            }
        }

        // ETAPE 3 - Construction de l image applicative (2 tags)
        stage('3. Build de l image Docker') {
            steps {
                sh '''
                    docker build \
                        -t ${DOCKER_IMAGE}:${BUILD_NUMBER} \
                        -t ${DOCKER_IMAGE}:latest \
                        .
                '''
            }
        }

        // ETAPE 4 - Publication sur Docker Hub (identifiants Jenkins)
        stage('4. Push vers Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: "${DOCKER_CRED_ID}",
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout
                    '''
                }
            }
        }

        // ETAPE 5 - Deploiement de l environnement de staging (3001 -> 3000)
        stage('5. Deploiement Staging') {
            steps {
                sh '''
                    docker rm -f ${STAGING_CONTAINER} || true
                    docker run -d \
                        --name ${STAGING_CONTAINER} \
                        --restart unless-stopped \
                        -p ${STAGING_PORT}:${APP_PORT} \
                        ${DOCKER_IMAGE}:latest

                    sleep 5
                    docker ps --filter "name=${STAGING_CONTAINER}"
                    docker logs --tail 20 ${STAGING_CONTAINER}
                '''
            }
        }
    }

    post {
        success {
            echo "SUCCES : Build #${BUILD_NUMBER} publie sur Docker Hub et deploye en staging sur http://localhost:${STAGING_PORT}"
            // Notification externe optionnelle (Discord / Slack / Teams) :
            // sh 'curl -fsS -X POST -H "Content-Type: application/json" \
            //     --data "{\"text\":\"Build #${BUILD_NUMBER} TP4 Groupe 4 : SUCCES\"}" TON_WEBHOOK_URL'
        }
        failure {
            echo "ECHEC : Build #${BUILD_NUMBER} du pipeline TP4 Groupe 4 interrompu. Consulter la Console Output de l etape en erreur."
            // Notification externe optionnelle (Discord / Slack / Teams) :
            // sh 'curl -fsS -X POST -H "Content-Type: application/json" \
            //     --data "{\"text\":\"Build #${BUILD_NUMBER} TP4 Groupe 4 : ECHEC\"}" TON_WEBHOOK_URL'
        }
        always {
            echo "Statut final du build #${BUILD_NUMBER} : ${currentBuild.currentResult}"
        }
    }
}
