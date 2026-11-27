#!/bin/bash
set -e

mkdir -p app infra

# 1. Application Node.js (Express)
cat << 'APP_PKG' > app/package.json
{
  "name": "tp4-cicd-groupe4",
  "version": "1.0.0",
  "description": "Application Web TP4 CI/CD ITT3-IR Groupe 4",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "test": "jest --forceExit"
  },
  "dependencies": {
    "express": "^4.19.2"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "supertest": "^7.0.0"
  }
}
APP_PKG

cat << 'APP_JS' > app/index.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.status(200).json({
    status: 'OK',
    version: '1.0.0',
    group: 'ITT3-IR Groupe 4',
    message: 'Pipeline CI/CD Jenkins + Docker opérationnel !'
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ healthy: true });
});

if (require.main === module) {
  app.listen(PORT, () => console.log(`Serveur démarré sur le port ${PORT}`));
}

module.exports = app;
APP_JS

cat << 'APP_TEST' > app/app.test.js
const request = require('supertest');
const app = require('./index');

describe('Tests de l application TP4 Groupe 4', () => {
  it('GET / doit retourner 200 et le statut OK', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toEqual(200);
    expect(res.body.status).toBe('OK');
    expect(res.body.group).toBe('ITT3-IR Groupe 4');
  });

  it('GET /health doit retourner healthy: true', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toEqual(200);
    expect(res.body.healthy).toBe(true);
  });
});
APP_TEST

# 2. Dockerfile de l'application
cat << 'DOCKER_APP' > Dockerfile
FROM node:20-alpine
WORKDIR /usr/src/app
COPY app/package*.json ./
RUN npm install --production
COPY app/ ./
EXPOSE 3000
CMD ["npm", "start"]
DOCKER_APP

# 3. Dockerfile de Jenkins avec Docker CLI intégré
cat << 'DOCKER_JENKINS' > infra/Dockerfile.jenkins
FROM jenkins/jenkins:lts
USER root
RUN apt-get update && apt-get install -y docker.io && rm -rf /var/lib/apt/lists/*
DOCKER_JENKINS

# 4. Docker Compose pour Jenkins
cat << 'COMPOSE' > docker-compose.yml
services:
  jenkins:
    build:
      context: .
      dockerfile: infra/Dockerfile.jenkins
    container_name: jenkins-tp4
    user: root
    restart: unless-stopped
    ports:
      - "8080:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock

volumes:
  jenkins_home:
COMPOSE

# 5. Jenkinsfile complet (Clone, Test, Build, Push, Staging, Notification)
cat << 'JENKINSFILE' > Jenkinsfile
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
JENKINSFILE

# 6. Initialisation Git et lancement de Jenkins
git init -b main
docker compose up -d --build

echo "Attente du démarrage de Jenkins (20 secondes)..."
sleep 20
echo "=========================================================="
echo "MOT DE PASSE ADMIN INITIAL JENKINS :"
docker exec jenkins-tp4 cat /var/jenkins_home/secrets/initialAdminPassword
echo "=========================================================="
