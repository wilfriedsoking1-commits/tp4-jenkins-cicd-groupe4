pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "TON_USER_DOCKERHUB/tp4-app-groupe4"
        DOCKER_CRED_ID = "dockerhub-creds"
        STAGING_CONTAINER = "app-staging-g4"
    }

    stages {
        stage('1. Clone du repository') {
            steps {
                checkout scm
            }
        }

        stage('2. Test de l application') {
            steps {
                sh '''
                    docker run --rm -v "$PWD/app":/app -w /app node:20-alpine sh -c "npm install && npm test"
                '''
            }
        }

        stage('3. Build de l image Docker') {
            steps {
                sh '''
                    docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} -t ${DOCKER_IMAGE}:latest .
                '''
            }
        }

        stage('4. Push vers Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: "${DOCKER_CRED_ID}", usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}
                        docker push ${DOCKER_IMAGE}:latest
                    '''
                }
            }
        }

        stage('5. Déploiement Staging') {
            steps {
                sh '''
                    docker rm -f ${STAGING_CONTAINER} || true
                    docker run -d --name ${STAGING_CONTAINER} -p 3001:3000 ${DOCKER_IMAGE}:latest
                '''
            }
        }
    }

    post {
        success {
            echo "SUCCÈS : Pipeline TP4 Groupe 4 déployé en staging sur le port 3001 !"
            // Décommente et ajoute ton URL Discord/Slack pour notification externe :
            // sh 'curl -X POST -H "Content-type: application/json" --data "{\"text\":\"✅ Build #${BUILD_NUMBER} TP4 Groupe 4 réussi !\"}" TON_WEBHOOK_URL'
        }
        failure {
            echo "ÉCHEC : Le pipeline TP4 Groupe 4 a échoué à l'étape en cours."
        }
    }
}
