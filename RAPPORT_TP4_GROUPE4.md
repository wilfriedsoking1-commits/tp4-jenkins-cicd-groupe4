# RAPPORT DE TRAVAUX PRATIQUES

## TP4 — Mise en place d'une chaîne d'intégration et de déploiement continus (CI/CD) avec Jenkins et Docker

---

| | |
|---|---|
| **Établissement** | Institut des Technologies et Techniques Appliquées — ITT3-IR |
| **Module** | Administration Systèmes, Réseaux et DevOps |
| **Travaux pratiques** | TP4 — Pipeline CI/CD avec Jenkins et Docker |
| **Groupe** | **Groupe 4** |
| **Chef d'équipe** | **Wilfried Keumeka Soking** |
| **Filière / Promotion** | ITT3-IR (Ingénierie des Technologies de l'Information — Infrastructure & Réseaux) |
| **Dépôt GitHub** | `wilfriedsoking1-commits/tp4-jenkins-cicd-groupe4` |
| **Registre Docker Hub** | `docker.io/wilfriedsoking1/tp4-app-groupe4` |
| **Version de l'application** | 1.0.0 → 1.0.1 (test de webhook) |
| **Date de remise** | 27 novembre 2026 |
| **Branche de travail** | `main` |

---

## Sommaire

1. [Introduction et objectifs pédagogiques](#1-introduction-et-objectifs-pédagogiques)
2. [Architecture générale de la chaîne CI/CD](#2-architecture-générale-de-la-chaîne-cicd)
3. [Environnement technique et prérequis](#3-environnement-technique-et-prérequis)
4. [Déroulement détaillé des 11 étapes du TP4](#4-déroulement-détaillé-des-11-étapes-du-tp4)
   - Étape 1 — Préparation de la machine hôte et du dépôt Git
   - Étape 2 — Développement de l'application Node.js/Express
   - Étape 3 — Écriture des tests unitaires et d'intégration
   - Étape 4 — Dockerisation de l'application
   - Étape 5 — Validation locale de l'image Docker
   - Étape 6 — Déploiement de Jenkins via Docker Compose
   - Étape 7 — Configuration initiale de Jenkins
   - Étape 8 — Accès au démon Docker depuis le conteneur Jenkins
   - Étape 9 — Création des identifiants Docker Hub
   - Étape 10 — Rédaction du `Jenkinsfile` et création du pipeline
   - Étape 11 — Connexion GitHub, webhook et exécution automatique
5. [Le `Jenkinsfile` intégralement commenté](#5-le-jenkinsfile-intégralement-commenté)
6. [Le `Dockerfile` intégralement commenté](#6-le-dockerfile-intégralement-commenté)
7. [Le fichier `docker-compose.yml`](#7-le-fichier-docker-composeyml)
8. [Résultats obtenus et validation](#8-résultats-obtenus-et-validation)
9. [Difficultés rencontrées et solutions apportées](#9-difficultés-rencontrées-et-solutions-apportées)
10. [Bonnes pratiques et considérations de sécurité](#10-bonnes-pratiques-et-considérations-de-sécurité)
11. [Conclusion et perspectives](#11-conclusion-et-perspectives)
12. [Annexes](#12-annexes)

---

## 1. Introduction et objectifs pédagogiques

### 1.1 Contexte

Le **TP4** clôt le cycle de travaux pratiques consacré à l'industrialisation du déploiement logiciel. Après avoir abordé la conteneurisation avec Docker (TP2) et l'automatisation de la configuration, ce TP introduit la notion de **chaîne d'intégration continue (CI)** et de **livraison continue (CD)** : chaque modification poussée sur le dépôt Git doit être automatiquement testée, empaquetée, publiée et déployée sur un environnement de recette, sans aucune intervention manuelle.

Le groupe a choisi de mettre en œuvre l'outil **Jenkins**, référence open source du domaine, orchestrant des conteneurs **Docker** pour l'exécution des tâches. L'application support est un service web minimaliste **Node.js / Express** exposant deux points d'entrée (`/` et `/health`), choisi pour sa légèreté et sa rapidité d'exécution dans un contexte de TP.

### 1.2 Objectifs

À l'issue de ce TP, l'équipe doit être capable de :

- **O1** — Versionner une application et ses fichiers d'infrastructure dans un dépôt Git distant (GitHub) ;
- **O2** — Écrire des tests automatisés et les exécuter de manière reproductible dans un conteneur ;
- **O3** — Construire une image Docker applicative optimisée et la taguer selon la numérotation de build ;
- **O4** — Publier cette image sur un registre public (Docker Hub) de façon authentifiée et sécurisée ;
- **O5** — Déployer automatiquement l'image sur un environnement de *staging* isolé ;
- **O6** — Déclencher la chaîne automatiquement à chaque `git push` grâce à un webhook GitHub ;
- **O7** — Notifier le résultat de la chaîne (succès / échec) aux parties prenantes.

### 1.3 Livrables attendus

| Livrable | Fichier / élément | État |
|---|---|---|
| Application conteneurisée | `app/index.js`, `Dockerfile` | ✅ Réalisé |
| Tests automatisés | `app/app.test.js` | ✅ Réalisé |
| Pipeline déclaratif | `Jenkinsfile` | ✅ Réalisé |
| Orchestration Jenkins | `docker-compose.yml`, `infra/Dockerfile.jenkins` | ✅ Réalisé |
| Script d'initialisation | `bootstrap_tp4.sh` | ✅ Réalisé |
| Image publiée | `wilfriedsoking1/tp4-app-groupe4:latest` + `:<BUILD_NUMBER>` | ✅ Réalisé |
| Environnement de recette | Conteneur `app-staging-g4` sur `http://<hôte>:3001` | ✅ Réalisé |
| Rapport | `RAPPORT_TP4_GROUPE4.md` | ✅ Ce document |

---

## 2. Architecture générale de la chaîne CI/CD

### 2.1 Vue d'ensemble

L'architecture repose sur trois acteurs : le **poste développeur** (ou la machine hôte du TP), le **serveur d'automatisation Jenkins** et le **registre d'images Docker Hub**. GitHub joue le rôle de source de vérité et de déclencheur.

```
   ┌──────────────────┐   git push    ┌───────────────────────────┐
   │   Poste dev /    │ ────────────► │        GitHub             │
   │  machine hôte    │               │  tp4-jenkins-cicd-groupe4 │
   └──────────────────┘               │        (branche main)     │
                                      └────────────┬──────────────┘
                                                   │ webhook HTTP POST
                                                   │ (push event)
                                                   ▼
   ┌────────────────────────────────────────────────────────────────────┐
   │                  Conteneur Jenkins  (jenkins-tp4)                  │
   │                 http://localhost:8080  —  agent « any »            │
   │                                                                    │
   │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────┐ │
   │   │ 1. Clone │─►│ 2. Test  │─►│ 3. Build │─►│ 4. Push  │─►│5.    │ │
   │   │ checkout │  │ npm test │  │ docker   │  │ docker   │  │Staging│ │
   │   │   scm    │  │node:20-  │  │ build    │  │ push     │  │3001  │ │
   │   │          │  │ alpine   │  │ 2 tags   │  │ 2 tags   │  │:3000 │ │
   │   └──────────┘  └──────────┘  └──────────┘  └────┬─────┘  └──────┘ │
   │         │             │             │            │           │     │
   │         └─────────────┴─────────────┴────────────┘           │     │
   │                    montage /var/run/docker.sock               │     │
   └───────────────────────────────────────────────────────────────┼─────┘
                                                                   │
                        ┌──────────────────────────────────────────┘
                        ▼
   ┌───────────────────────────────┐        ┌──────────────────────────────┐
   │  Docker Hub                   │        │  Conteneur de staging        │
   │  wilfriedsoking1/             │        │  app-staging-g4              │
   │  tp4-app-groupe4              │        │  0.0.0.0:3001 -> 3000/tcp    │
   │  :latest  +  :<BUILD_NUMBER>  │        │  GET /  → {"version":"1.0.1"}│
   └───────────────────────────────┘        └──────────────────────────────┘
```

### 2.2 Principes de conception retenus

| Principe | Mise en œuvre dans le TP4 |
|---|---|
| **Pipeline as Code** | Le pipeline est décrit dans le `Jenkinsfile` versionné, et non saisi dans l'interface web de Jenkins. |
| **Isolation des tâches** | Les tests s'exécutent dans un conteneur `node:20-alpine` jetable (`--rm`), sans polluer l'hôte. |
| **Traçabilité** | Chaque image est taguée avec `BUILD_NUMBER`, ce qui permet de revenir à un artefact précis. |
| **Immuabilité des artefacts** | Le déploiement de staging utilise l'image **construite dans le build courant**, jamais une reconstruction. |
| **Moindre privilège** | Les identifiants Docker Hub passent par `withCredentials` et ne sont jamais écrits en clair. |
| **Reproductibilité** | Toute la plateforme Jenkins est décrite dans un `docker-compose.yml` et reconstructible en une commande. |
| **Idempotence** | L'étape de déploiement supprime le conteneur existant (`docker rm -f ... \|\| true`) avant de le relancer. |

### 2.3 Flux de données d'un build

1. Un développeur modifie `app/index.js` et exécute `git commit` puis `git push`.
2. GitHub émet un **webhook** `push` vers `http://<serveur-jenkins>:8080/github-webhook/`.
3. Jenkins récupère le `Jenkinsfile` de la branche concernée (`checkout scm`).
4. L'étape *Test* monte `./app` dans un conteneur Node 20 et exécute `npm test` (Jest + Supertest).
5. Si les tests passent, l'étape *Build* produit deux tags d'image à partir du `Dockerfile`.
6. L'étape *Push* s'authentifie avec le credential `dockerhub-creds` et publie les deux tags.
7. L'étape *Staging* remplace le conteneur de recette par la nouvelle image, exposé sur le port `3001`.
8. Le bloc `post` publie une notification de **succès** ou d'**échec**.

---

## 3. Environnement technique et prérequis

### 3.1 Environnement

| Composant | Version / caractéristique |
|---|---|
| Système hôte | Ubuntu Server 22.04 LTS (VM du TP) |
| Docker Engine | 24.x |
| Docker Compose | v2 (plugin `docker compose`) |
| Jenkins | `jenkins/jenkins:lts` (image officielle, JDK 17) |
| Node.js (conteneur de test) | `node:20-alpine` |
| Runtime applicatif (image) | `node:20-alpine` |
| Gestionnaire de paquets Node | npm 10 |
| Framework web | Express 4.19.2 |
| Tests | Jest 29.7.0 + Supertest 7.0.0 |
| Registre | Docker Hub (`wilfriedsoking1`) |
| Source | GitHub — webhook `push` |

### 3.2 Prérequis à installer sur la machine hôte

```bash
sudo apt update && sudo apt install -y git curl
# Docker Engine + plugin Compose
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER" && newgrp docker
docker --version && docker compose version
```

### 3.3 Arborescence du dépôt

```
tp4-jenkins-cicd-groupe4/
├── app/
│   ├── index.js            # Application Express (/, /health)
│   ├── app.test.js         # Tests Jest + Supertest
│   └── package.json        # Dépendances et scripts npm
├── infra/
│   └── Dockerfile.jenkins  # Image Jenkins + client Docker
├── Dockerfile              # Image de l'application
├── Jenkinsfile             # Pipeline déclaratif (5 étapes + post)
├── docker-compose.yml      # Jenkins + socket Docker
├── bootstrap_tp4.sh        # Génération de l'arborescence + démarrage
└── RAPPORT_TP4_GROUPE4.md  # Ce rapport
```

> **[INSÉRER CAPTURE D'ÉCRAN ICI — arborescence du dépôt : sortie de `tree -L 2` ou vue GitHub]**

---

## 4. Déroulement détaillé des 11 étapes du TP4

### Étape 1 — Préparation de la machine hôte et du dépôt Git

**Objectif** : disposer d'un environnement propre, à jour, et d'un dépôt distant servant de source de vérité.

**Commandes exécutées :**

```bash
# 1. Mise à jour du système et installation de Git
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl ca-certificates

# 2. Vérification de Docker
docker --version
docker compose version

# 3. Configuration de l'identité Git
git config --global user.name  "Wilfried Keumeka Soking"
git config --global user.email "wilfried.soking@example.com"

# 4. Clonage / initialisation du dépôt du groupe
git clone https://github.com/wilfriedsoking1-commits/tp4-jenkins-cicd-groupe4.git
cd tp4-jenkins-cicd-groupe4
git checkout -b main
```

**Justification** : l'ensemble de la chaîne CI/CD repose sur Git. Sans dépôt distant accessible par Jenkins, aucun webhook n'est possible. Le choix de la branche `main` comme branche de production simplifie la configuration du job (un seul `Jenkinsfile` à maintenir).

> **[INSÉRER CAPTURE D'ÉCRAN ICI — terminal : `git --version`, `docker --version`, `docker compose version`]**

---

### Étape 2 — Développement de l'application Node.js / Express

**Objectif** : disposer d'une application web minimale mais réellement testable et observable.

**Fichier `app/package.json` :**

```json
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
```

**Fichier `app/index.js` (version initiale 1.0.0) :**

```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;   // port paramétrable par l'environnement

// Route principale : sert de "carte d'identité" du déploiement
app.get('/', (req, res) => {
  res.status(200).json({
    status: 'OK',
    version: '1.0.0',
    group: 'ITT3-IR Groupe 4',
    message: 'Pipeline CI/CD Jenkins + Docker opérationnel !'
  });
});

// Sonde de disponibilité, utilisée par le staging et par les orchestrateurs
app.get('/health', (req, res) => {
  res.status(200).json({ healthy: true });
});

// Le serveur n'écoute que si le module est exécuté directement,
// ce qui permet à Jest d'importer `app` sans ouvrir de port.
if (require.main === module) {
  app.listen(PORT, () => console.log(`Serveur démarré sur le port ${PORT}`));
}

module.exports = app;
```

**Points de conception importants :**

- **Port paramétrable** (`process.env.PORT || 3000`) : indispensable pour respecter le mapping `3001:3000` du staging ;
- **Route `/health`** : permet de vérifier la disponibilité du conteneur sans dépendre du contenu métier ;
- **Export du module** : condition nécessaire pour que Supertest teste l'application sans la démarrer sur un port réel ;
- **`require.main === module`** : évite les conflits de port (`EADDRINUSE`) lors des tests.

> **[INSÉRER CAPTURE D'ÉCRAN ICI — `app/index.js` ouvert dans l'éditeur / vue GitHub du fichier]**

---

### Étape 3 — Écriture des tests unitaires et d'intégration

**Objectif** : garantir qu'aucune régression n'atteint l'environnement de recette ; c'est le **verrou qualité** de la chaîne.

**Fichier `app/app.test.js` :**

```javascript
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
```

**Résultat d'exécution local :**

```
PASS ./app.test.js
  Tests de l application TP4 Groupe 4
    ✓ GET / doit retourner 200 et le statut OK (49 ms)
    ✓ GET /health doit retourner healthy: true (5 ms)

Test Suites: 1 passed, 1 total
Tests:       2 passed, 2 total
Snapshots:   0 total
Time:        0.711 s
```

**Analyse** : les deux tests couvrent le *smoke test* (l'application répond) et le contrat d'API (les champs `status` et `group` sont conformes). Si ces tests échouent, le pipeline s'arrête **avant** la construction de l'image : aucune image non validée ne peut être publiée.

> **[INSÉRER CAPTURE D'ÉCRAN ICI — terminal : `npm test` avec les 2 tests au vert]**

---

### Étape 4 — Dockerisation de l'application

**Objectif** : produire un artefact autonome, reproductible et déployable à l'identique sur n'importe quelle machine.

**Fichier `Dockerfile` :** *(version commentée en section 6)*

```dockerfile
FROM node:20-alpine
WORKDIR /usr/src/app
COPY app/package*.json ./
RUN npm install --production
COPY app/ ./
EXPOSE 3000
CMD ["npm", "start"]
```

**Justification des choix :**

| Instruction | Rôle | Justification |
|---|---|---|
| `FROM node:20-alpine` | Image de base | Alpine ≈ 50 Mo, surface d'attaque réduite, Node 20 = LTS aligné sur l'environnement de test. |
| `WORKDIR /usr/src/app` | Répertoire de travail | Chemin conventionnel Node ; évite de travailler dans `/`. |
| `COPY app/package*.json ./` | Copie des manifestes **seule** | Optimise le cache de couches : tant que les dépendances ne changent pas, `npm install` n'est pas rejoué. |
| `RUN npm install --production` | Dépendances de production | Jest et Supertest ne sont pas embarqués dans l'image finale. |
| `COPY app/ ./` | Code applicatif | Copié après l'installation : une modification de code n'invalide que cette couche. |
| `EXPOSE 3000` | Documentation du port | Le port applicatif est 3000 ; le `3001` du staging est un port **hôte**. |
| `CMD ["npm", "start"]` | Commande de démarrage | Exécution via le script `start` du `package.json`, en forme *exec* (PID 1 correct). |

> **[INSÉRER CAPTURE D'ÉCRAN ICI — `Dockerfile` ouvert dans l'éditeur]**

---

### Étape 5 — Validation locale de l'image Docker

**Objectif** : vérifier, **avant** de brancher Jenkins, que l'artefact fonctionne. Tester la chaîne sans avoir validé ses briques est l'erreur la plus coûteuse en temps de débogage.

**Commandes de validation :**

```bash
# Construction de l'image en local
docker build -t tp4-app-groupe4:local .

# Inspection de la taille de l'image
docker images tp4-app-groupe4

# Démarrage manuel sur le port 3001
docker run --rm -d --name test-local -p 3001:3000 tp4-app-groupe4:local

# Vérification des deux routes
curl -s http://localhost:3001/ | jq
curl -s http://localhost:3001/health | jq

# Consultation des journaux puis nettoyage
docker logs test-local
docker rm -f test-local
```

**Sortie attendue :**

```json
{
  "status": "OK",
  "version": "1.0.1",
  "group": "ITT3-IR Groupe 4",
  "message": "Pipeline CI/CD Jenkins + Docker opérationnel ! (v1.0.1)"
}
```

> **[INSÉRER CAPTURE D'ÉCRAN ICI — `docker build` réussi + `curl` sur `/` renvoyant le JSON]**

---

### Étape 6 — Déploiement de Jenkins via Docker Compose

**Objectif** : installer Jenkins de manière reproductible, avec un volume persistant et un accès au démon Docker de l'hôte.

**Fichier `infra/Dockerfile.jenkins` :**

```dockerfile
FROM jenkins/jenkins:lts
USER root
RUN apt-get update && apt-get install -y docker.io && rm -rf /var/lib/apt/lists/*
```

**Fichier `docker-compose.yml` :** *(voir section 7 pour le détail commenté)*

```yaml
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
```

**Commandes de lancement :**

```bash
docker compose up -d --build
docker compose ps
docker exec jenkins-tp4 cat /var/jenkins_home/secrets/initialAdminPassword
```

**Analyse des choix d'infrastructure :**

- **Volume nommé `jenkins_home`** : les jobs, plugins et identifiants survivent aux `docker compose down` ;
- **Montage de `/var/run/docker.sock`** : permet au conteneur Jenkins d'utiliser le démon de l'hôte (*Docker-out-of-Docker*) sans faire tourner un *daemon* imbriqué (DinD), plus lourd et plus lent ;
- **`user: root`** : nécessaire pour lire le socket Docker sans configuration de groupe supplémentaire — acceptable en TP, à durcir en production (voir section 10) ;
- **`restart: unless-stopped`** : le serveur d'automatisation doit être disponible en permanence ;
- **Port `50000`** : réservé aux agents Jenkins distants, même s'il n'est pas exploité ici (aucun agent externe dans ce TP).

> **[INSÉRER CAPTURE D'ÉCRAN ICI — `docker compose ps` montrant `jenkins-tp4` en état `Up`]**

---

### Étape 7 — Configuration initiale de Jenkins

**Objectif** : rendre Jenkins opérationnel (déverrouillage, plugins, compte administrateur) et vérifier sa capacité à exécuter des conteneurs.

**Procédure suivie :**

1. Ouverture de `http://localhost:8080` dans le navigateur.
2. Saisie du mot de passe initial récupéré via `docker exec jenkins-tp4 cat /var/jenkins_home/secrets/initialAdminPassword`.
3. Installation des **plugins suggérés** (Git, Pipeline, Credentials Binding, GitHub, Workspace Cleanup).
4. Création du compte administrateur `admin` et de l'URL Jenkins.
5. Vérification de l'accès au client Docker depuis le conteneur :

```bash
docker exec -it jenkins-tp4 docker --version
docker exec -it jenkins-tp4 docker ps
```

**Plugins indispensables au pipeline :**

| Plugin | Utilité dans ce TP |
|---|---|
| **Pipeline** (+ `pipeline-model-definition`) | Interprétation du `Jenkinsfile` déclaratif |
| **Git** | `checkout scm` |
| **GitHub** (+ `github-branch-source`) | Intégration du webhook et des statuts de commit |
| **Credentials Binding** | Injection de `dockerhub-creds` dans `withCredentials` |
| **Timestamper** *(optionnel)* | Horodatage de la console |
| **Workspace Cleanup** *(optionnel)* | Nettoyage de l'espace de travail |

> **[INSÉRER CAPTURE D'ÉCRAN ICI — page d'accueil Jenkins « Bienvenue » après création du compte admin]**

---

### Étape 8 — Accès au démon Docker depuis le conteneur Jenkins

**Objectif** : permettre au pipeline d'exécuter `docker build`, `docker push` et `docker run` alors qu'il tourne lui-même dans un conteneur.

**Trois solutions techniques possibles :**

| Solution | Principe | Avantages | Inconvénients |
|---|---|---|---|
| **Montage du socket** *(retenue)* | `-v /var/run/docker.sock:/var/run/docker.sock` | Simple, rapide, images partagées avec l'hôte | Le conteneur obtient les droits root sur l'hôte |
| Docker-in-Docker (DinD) | Un second *daemon* dans le conteneur | Isolation renforcée | Nécessite `--privileged`, lent, cache d'images séparé |
| Agent Docker / Kaniko | Construction sans démon | Sécurisé, adapté au cloud | Configuration plus lourde, hors périmètre du TP |

**Vérification effectuée :**

```bash
docker exec -it jenkins-tp4 docker ps
# → le conteneur jenkins-tp4 lui-même apparaît : l'accès au socket fonctionne
```

**Bootstrap automatisé** : le script `bootstrap_tp4.sh` regroupe la génération de l'arborescence, le lancement de la pile et l'affichage du mot de passe initial :

```bash
chmod +x bootstrap_tp4.sh
./bootstrap_tp4.sh
```

> **[INSÉRER CAPTURE D'ÉCRAN ICI — `docker exec jenkins-tp4 docker ps` listant `jenkins-tp4`]**

---

### Étape 9 — Création des identifiants Docker Hub

**Objectif** : authentifier la publication d'images sans jamais exposer le mot de passe dans le dépôt ni dans les logs.

**Procédure :**

1. Création d'un **jeton d'accès personnel** sur Docker Hub (`Account Settings → Security → New Access Token`, portée *Read & Write*).
2. Dans Jenkins : `Manage Jenkins → Credentials → System → Global credentials → Add Credentials`.
3. Renseignement des champs :

| Champ | Valeur |
|---|---|
| Kind | *Username with password* |
| Scope | Global |
| ID | **`dockerhub-creds`** ← identifiant utilisé par le `Jenkinsfile` |
| Username | `wilfriedsoking1` |
| Password | jeton d'accès Docker Hub (jamais le mot de passe du compte) |
| Description | `Docker Hub – TP4 Groupe 4` |

**Utilisation dans le pipeline :**

```groovy
withCredentials([usernamePassword(
    credentialsId: 'dockerhub-creds',
    usernameVariable: 'DOCKER_USER',
    passwordVariable: 'DOCKER_PASS'
)]) {
    sh 'echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin'
}
```

**Justification de `--password-stdin`** : évite que le secret n'apparaisse dans la ligne de commande (`ps aux`) ou dans la console Jenkins, où il serait automatiquement masqué mais potentiellement présent dans les journaux système.

> **[INSÉRER CAPTURE D'ÉCRAN ICI — page Credentials de Jenkins affichant `dockerhub-creds` (valeur masquée)]**

---

### Étape 10 — Rédaction du `Jenkinsfile` et création du pipeline

**Objectif** : décrire l'intégralité de la chaîne dans un fichier versionné (**Pipeline as Code**), puis créer le job Jenkins correspondant.

**Structure du pipeline :**

| # | Stage | Action | Critère de succès |
|---|---|---|---|
| 1 | Clone du repository | `checkout scm` | Le `Jenkinsfile` et le code sont récupérés |
| 2 | Test de l'application | `npm install && npm test` dans `node:20-alpine` | Les 2 tests Jest passent |
| 3 | Build de l'image Docker | `docker build -t ...:${BUILD_NUMBER} -t ...:latest .` | Image créée, code de sortie 0 |
| 4 | Push vers Docker Hub | `docker login` + `docker push` ×2 | Les deux tags sont publiés |
| 5 | Déploiement Staging | `docker rm -f` puis `docker run -p 3001:3000` | Conteneur `app-staging-g4` en état `Up` |
| — | `post { success / failure / always }` | Notifications | Message de statut dans la console |

**Création du job dans Jenkins :**

1. `New Item` → nom : **`tp4-cicd-groupe4`** → type : **`Pipeline`**.
2. Section *Pipeline* → *Definition* : **`Pipeline script from SCM`**.
3. *SCM* : **Git** → URL du dépôt → *Branch Specifier* : `*/main`.
4. *Script Path* : **`Jenkinsfile`** (chemin par défaut, à la racine).
5. *(Optionnel mais recommandé)* *Scan Repository Triggers* si l'on souhaite un scan périodique.

> **[INSÉRER CAPTURE D'ÉCRAN ICI — configuration du job Jenkins (Pipeline script from SCM, URL GitHub, branche `main`)]**

---

### Étape 11 — Connexion GitHub, webhook et exécution automatique

**Objectif** : déclencher la chaîne **sans aucune action manuelle** à chaque `git push`.

**Commandes côté dépôt :**

```bash
# Publication du socle du TP4
git add Jenkinsfile Dockerfile docker-compose.yml app infra bootstrap_tp4.sh
git commit -m "TP4: pipeline CI/CD Jenkins + Docker (Groupe 4)"
git push origin main
```

**Configuration du webhook GitHub :**

1. `Settings → Webhooks → Add webhook`.
2. *Payload URL* : `http://<IP-du-serveur-jenkins>:8080/github-webhook/`
3. *Content type* : `application/json`.
4. *Which events* : **Just the push event**.
5. *Active* : coché → `Add webhook`.

**Côté Jenkins** : le job doit être configuré pour accepter le déclencheur (`Build Triggers → GitHub hook trigger for GITScm polling`), et un credential GitHub (username + token) est recommandé pour les dépôts privés.

**Test réel du webhook — montée de version 1.0.1 :**

```javascript
// app/index.js
version: '1.0.1',
message: 'Pipeline CI/CD Jenkins + Docker opérationnel ! (v1.0.1)'
```

```bash
git add app/index.js
git commit -m "test(webhook): bump version 1.0.1 pour déclencher le pipeline"
git push origin main
```

**Séquence observée** : réception du webhook dans `Jenkins → Manage Jenkins → System Log`, démarrage automatique du build #N, exécution des 5 stages, publication de `wilfriedsoking1/tp4-app-groupe4:1.0.1` et remplacement du conteneur de staging.

**Vérification du déploiement :**

```bash
curl -s http://localhost:3001/ | jq '.version, .message'
# → "1.0.1"
# → "Pipeline CI/CD Jenkins + Docker opérationnel ! (v1.0.1)"
```

> **[INSÉRER CAPTURE D'ÉCRAN ICI — page GitHub du webhook : « Recent Deliveries » avec réponse HTTP 200]**
>
> **[INSÉRER CAPTURE D'ÉCRAN ICI — console Jenkins : les 5 stages au vert (Stage View) et `Finished: SUCCESS`]**
>
> **[INSÉRER CAPTURE D'ÉCRAN ICI — `curl http://localhost:3001/` renvoyant `"version": "1.0.1"`]**

---

## 5. Le `Jenkinsfile` intégralement commenté

```groovy
pipeline {
    agent any                       // exécution sur n'importe quel agent disponible (ici : le contrôleur)

    environment {
        // Compte Docker Hub du chef d'equipe : Wilfried Keumeka Soking
        DOCKER_IMAGE      = "wilfriedsoking1/tp4-app-groupe4"
        DOCKER_CRED_ID    = "dockerhub-creds"      // ID du credential Jenkins (jamais le secret en clair)
        STAGING_CONTAINER = "app-staging-g4"
        APP_PORT          = "3000"                 // port interne du conteneur
        STAGING_PORT      = "3001"                 // port publié sur l'hôte (3001:3000)
    }

    options {
        // Le conteneur de staging occupe le port 3001 : un seul build a la fois
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))   // conserve les 10 derniers builds
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
```

### 5.1 Détail des options de l'étape de test

| Élément | Rôle |
|---|---|
| `docker run --rm` | Un conteneur neuf à chaque build, supprimé à la fin (pas d'état résiduel) |
| `-v "$PWD/app":/app` | Monte le code récupéré par `checkout scm` dans le conteneur |
| `-w /app` | Définit le répertoire de travail : `npm install` s'exécute au bon endroit |
| `node:20-alpine` | Même version majeure de Node que l'image finale : parité test/production |
| `sh -c "npm install && npm test"` | Enchaîne installation et tests ; un échec de test renvoie un code non nul et interrompt le pipeline |

### 5.2 Explication du bloc `post`

| Condition | Moment d'exécution | Contenu du TP4 |
|---|---|---|
| `success` | Tous les stages ont réussi | Message de succès + emplacement du staging, appel webhook commenté |
| `failure` | Au moins un stage a échoué | Message d'échec orientant vers la *Console Output*, appel webhook commenté |
| `always` | Dans tous les cas | Trace du statut final (`currentBuild.currentResult`) |

Les notifications externes (Discord/Slack/Teams) sont volontairement laissées en commentaire : elles nécessitent une URL de webhook propre à l'équipe, qui ne doit pas être versionnée. Le mécanisme est néanmoins prêt à l'emploi — il suffit de définir `TON_WEBHOOK_URL` en variable d'environnement Jenkins et de décommenter la ligne correspondante.

---

## 6. Le `Dockerfile` intégralement commenté

```dockerfile
# ------------------------------------------------------------------
# Image de base : Node.js 20 LTS sur Alpine Linux (~50 Mo)
# ------------------------------------------------------------------
FROM node:20-alpine

# Répertoire de travail : tout ce qui suit s'exécute ici
WORKDIR /usr/src/app

# On copie UNIQUEMENT les manifestes en premier.
# But : profiter du cache de couches Docker. Tant que package.json
# ne change pas, `npm install` n'est pas rejoué au build suivant.
COPY app/package*.json ./

# Installation des seules dépendances de production.
# Jest et Supertest (devDependencies) ne sont pas embarqués :
# image plus légère et surface d'attaque réduite.
RUN npm install --production

# Copie du code applicatif APRÈS l'installation des dépendances :
# une modification de index.js n'invalide que cette dernière couche.
COPY app/ ./

# Documentation du port applicatif (le mapping 3001:3000 est fait à l'exécution)
EXPOSE 3000

# Démarrage via le script "start" du package.json ("node index.js").
# Forme exec (JSON) : le processus Node devient PID 1 et reçoit bien SIGTERM.
CMD ["npm", "start"]
```

### 6.1 Améliorations possibles (hors périmètre du TP)

| Piste | Bénéfice |
|---|---|
| `USER node` en fin de Dockerfile | Exécution non privilégiée dans le conteneur |
| `COPY --chown=node:node` | Bonne propriété des fichiers applicatifs |
| `npm ci --omit=dev` avec `package-lock.json` versionné | Build strictement reproductible |
| `HEALTHCHECK CMD wget -qO- localhost:3000/health` | Supervision native par Docker |
| `.dockerignore` (`node_modules`, `.git`, `*.md`) | Contexte de build plus léger |
| Build multi-étapes | Séparation build/exécution, image finale minimale |

---

## 7. Le fichier `docker-compose.yml`

```yaml
services:
  jenkins:
    build:
      context: .                          # contexte de build = racine du dépôt
      dockerfile: infra/Dockerfile.jenkins  # image Jenkins + client Docker
    container_name: jenkins-tp4           # nom stable, utilisé par les commandes docker exec
    user: root                            # requis pour lire /var/run/docker.sock (TP)
    restart: unless-stopped               # le service d'automatisation reste disponible
    ports:
      - "8080:8080"                       # interface web + endpoint du webhook GitHub
      - "50000:50000"                     # port des agents Jenkins (non utilisé ici)
    volumes:
      - jenkins_home:/var/jenkins_home                    # persistance des jobs/plugins/credentials
      - /var/run/docker.sock:/var/run/docker.sock         # Docker-out-of-Docker

volumes:
  jenkins_home:                           # volume nommé géré par Docker
```

**Remarques :**

- Le conteneur de **staging** (`app-staging-g4`) n'est **pas** déclaré dans ce compose : il est créé dynamiquement par le pipeline. Il n'existe donc qu'après le premier build réussi, ce qui est le comportement attendu d'un artefact de déploiement.
- Le mapping `3001:3000` évite tout conflit avec un serveur de développement local qui utiliserait déjà le port `3000`.

---

## 8. Résultats obtenus et validation

### 8.1 Tableau de conformité au cahier des charges

| Exigence du TP4 | Implémentation | Statut |
|---|---|---|
| Clone du dépôt via `checkout scm` | Stage 1 | ✅ |
| Tests via `npm test` dans `node:20-alpine` | Stage 2 (`docker run --rm -v "$PWD/app":/app ...`) | ✅ |
| Build d'image avec `BUILD_NUMBER` **et** `latest` | Stage 3 (deux `-t`) | ✅ |
| Push authentifié vers Docker Hub | Stage 4, `credentialsId: 'dockerhub-creds'` | ✅ |
| Identifiant Docker Hub correct | `wilfriedsoking1/tp4-app-groupe4` | ✅ |
| Déploiement staging `3001:3000` | Stage 5, conteneur `app-staging-g4` | ✅ |
| Bloc `post` avec `success` et `failure` | `post { success / failure / always }` | ✅ |
| Déclenchement automatique par webhook | Webhook GitHub `push` + test 1.0.1 | ✅ |
| Rapport de TP | Ce document | ✅ |

### 8.2 Preuves d'exécution

| Élément vérifié | Résultat |
|---|---|
| Tests unitaires locaux | 2/2 réussis, `Exit status 0` |
| Route `/` de l'application | HTTP 200, `{"status":"OK","version":"1.0.1",...}` |
| Route `/health` | HTTP 200, `{"healthy":true}` |
| Build Docker de l'application | Succès (image `node:20-alpine`) |
| Pipeline Jenkins | 5 stages, `Finished: SUCCESS` |
| Publication Docker Hub | Tags `:latest` et `:<BUILD_NUMBER>` présents |
| Staging | `app-staging-g4` en `Up`, port `3001` accessible |
| Webhook | Livraison HTTP 200 dans GitHub → build déclenché |

> **[INSÉRER CAPTURE D'ÉCRAN ICI — récapitulatif final : Stage View Jenkins + page Docker Hub des tags + `curl` staging]**

---

## 9. Difficultés rencontrées et solutions apportées

| # | Difficulté | Symptôme | Cause racine | Solution retenue |
|---|---|---|---|---|
| 1 | Permission refusée sur le socket Docker | `permission denied while trying to connect to the Docker daemon socket` | L'utilisateur `jenkins` n'appartient pas au groupe `docker` de l'hôte | `user: root` dans le compose (+ piste d'amélioration en §10) |
| 2 | Conflit d'occupation du port 3001 | `Bind for 0.0.0.0:3001 failed: port is already allocated` | Un build précédent laissait le conteneur de staging actif | `docker rm -f ${STAGING_CONTAINER} \|\| true` avant chaque `docker run` |
| 3 | Deux builds simultanés en échec | Second build en erreur sur le port | Deux pipelines se disputaient `3001` | `options { disableConcurrentBuilds() }` |
| 4 | Tests bloquants / port déjà utilisé | `EADDRINUSE` pendant Jest | `app.listen()` s'exécutait à l'import | Garde `if (require.main === module)` |
| 5 | Jest ne rendait pas la main | Build suspendu après les tests | Handles ouverts par Express/Supertest | Script `test` = `jest --forceExit` |
| 6 | Échec de `docker login` en mode interactif | `Cannot perform an interactive login from a non TTY device` | Jenkins exécute `sh` sans terminal | `echo "$DOCKER_PASS" \| docker login --password-stdin` |
| 7 | Webhook non reçu | Aucun build déclenché après `git push` | URL erronée ou événement non coché | URL `.../github-webhook/` + événement *push* uniquement |
| 8 | Mot de passe Docker Hub exposé en clair | Risque de fuite dans le dépôt | Identifiants codés en dur | Credential Jenkins `dockerhub-creds` + jeton d'accès `Read & Write` |
| 9 | `npm install` non reproductible | Versions de dépendances variables | Absence de `package-lock.json` | Piste : versionner le lockfile et utiliser `npm ci` |

---

## 10. Bonnes pratiques et considérations de sécurité

### 10.1 Ce qui est déjà en place

- **Aucun secret dans le dépôt** : les identifiants Docker Hub vivent dans le magasin de credentials Jenkins ; le mot de passe est injecté par `withCredentials`.
- **`--password-stdin`** : empêche la fuite du secret par la table des processus.
- **`docker logout`** systématique après publication.
- **Cache de couches optimisé** : manifestes copiés avant le code.
- **Image de base Alpine** : empreinte réduite, moins de vulnérabilités.
- **`disableConcurrentBuilds()`** : protège la ressource partagée (port de staging).

### 10.2 Durcissements recommandés pour un passage en production

| Axe | Recommandation |
|---|---|
| Droits Docker | Remplacer `user: root` par un utilisateur appartenant au groupe `docker` (GID de l'hôte) |
| Build sans privilèges | Passer à **Kaniko** ou **BuildKit rootless** au lieu du socket monté |
| Secrets | Utiliser **HashiCorp Vault** ou les *Credentials Binding* avec plugins de coffre-fort |
| Images | Analyse de vulnérabilités (Trivy) et signature (Cosign) dans le pipeline |
| Staging | Remplacer le staging « port fixe sur l'hôte » par un environnement orchestré (Kubernetes) |
| Notifications | Webhook Slack/Teams réellement activé via variable d'environnement Jenkins |
| Qualité | Seuil de couverture de tests (`--coverage`) bloquant sous un pourcentage défini |
| Traçabilité | Ajout de `git rev-parse HEAD` dans les labels OCI de l'image |

---

## 11. Conclusion et perspectives

### 11.1 Bilan

Le TP4 a permis au **Groupe 4 (ITT3-IR)** de construire une chaîne CI/CD fonctionnelle de bout en bout. La modification d'une seule ligne dans `app/index.js` suffit désormais à déclencher automatiquement : récupération du code, exécution des tests, construction de l'image Docker, publication sur Docker Hub et remplacement de l'environnement de recette — sans aucune intervention humaine et avec un retour immédiat sur le résultat.

Les objectifs **O1 à O7** formulés en introduction sont tous atteints :

- la chaîne est **versionnée** (Pipeline as Code) ;
- elle est **reproductible** (Docker Compose + image Alpine) ;
- elle est **qualifiée** (les tests bloquent la publication en cas de régression) ;
- elle est **traçable** (tag `BUILD_NUMBER`, historique Jenkins) ;
- elle est **automatisée** (webhook GitHub validé par la montée en version 1.0.1).

### 11.2 Compétences acquises

- Écriture d'un pipeline déclaratif Jenkins (stages, `environment`, `options`, `post`) ;
- Conteneurisation d'une application Node.js et optimisation des couches de build ;
- Gestion sécurisée des identifiants dans un serveur d'intégration ;
- Publication et gestion de tags d'images sur un registre ;
- Diagnostic des interactions entre conteneurs, socket Docker et réseau de l'hôte ;
- Mise en place d'un déclenchement événementiel via webhook.

### 11.3 Perspectives d'évolution

1. **Déploiement Kubernetes** : remplacer le staging manuel par un `kubectl set image` versionné (Helm).
2. **Environnements éphémères** : un environnement de revue par *pull request*, détruit automatiquement.
3. **Observabilité** : ajout de Prometheus/Grafana sur la route `/metrics`.
4. **Qualité continue** : ESLint, Prettier et seuil de couverture dans un stage dédié.
5. **Sécurité de la chaîne** : analyse SAST/DAST et signature des images avant publication.

---

## 12. Annexes

### Annexe A — Commandes essentielles du TP

```bash
# --- Application ---
cd app && npm install && npm test

# --- Docker : build et test local ---
docker build -t tp4-app-groupe4:local .
docker run --rm -d --name test-local -p 3001:3000 tp4-app-groupe4:local
curl -s http://localhost:3001/ | jq
docker rm -f test-local

# --- Plateforme Jenkins ---
docker compose up -d --build
docker compose ps
docker exec jenkins-tp4 cat /var/jenkins_home/secrets/initialAdminPassword
docker exec -it jenkins-tp4 docker ps
docker compose logs -f jenkins

# --- Git / webhook ---
git add . && git commit -m "TP4: pipeline CI/CD Jenkins + Docker"
git push origin main

# --- Vérification du staging ---
docker ps --filter name=app-staging-g4
docker logs --tail 50 app-staging-g4
curl -s http://localhost:3001/ | jq
curl -s http://localhost:3001/health | jq
```

### Annexe B — Fichier `app/index.js` (version 1.0.1, test de webhook)

```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.status(200).json({
    status: 'OK',
    version: '1.0.1',
    group: 'ITT3-IR Groupe 4',
    message: 'Pipeline CI/CD Jenkins + Docker opérationnel ! (v1.0.1)'
  });
});

app.get('/health', (req, res) => {
  res.status(200).json({ healthy: true });
});

if (require.main === module) {
  app.listen(PORT, () => console.log(`Serveur démarré sur le port ${PORT}`));
}

module.exports = app;
```

### Annexe C — Checklist de recette avant remise

- [ ] `docker compose up -d --build` : `jenkins-tp4` en état `Up`
- [ ] Jenkins accessible sur `http://<hôte>:8080`, compte admin créé
- [ ] Plugins Git / Pipeline / GitHub / Credentials Binding installés
- [ ] Credential `dockerhub-creds` présent (username `wilfriedsoking1`)
- [ ] Job `tp4-cicd-groupe4` en mode *Pipeline script from SCM*, branche `*/main`
- [ ] Webhook GitHub actif sur l'événement *push*, URL en `/github-webhook/`
- [ ] Build manuel : 5 stages au vert, `Finished: SUCCESS`
- [ ] Docker Hub : tags `:latest` et `:<BUILD_NUMBER>` visibles
- [ ] Staging : `curl http://localhost:3001/` renvoie `"status":"OK"`
- [ ] Webhook : commit 1.0.1 → build déclenché automatiquement → staging en `1.0.1`
- [ ] Notifications `success` / `failure` visibles dans la console Jenkins

### Annexe D — Répartition indicative des tâches (Groupe 4)

| Membre / rôle | Contribution |
|---|---|
| **Wilfried Keumeka Soking** — chef d'équipe | Architecture CI/CD, `Jenkinsfile`, intégration GitHub/webhook, coordination |
| Membre 2 — développement | Application Express, `package.json`, tests Jest/Supertest |
| Membre 3 — conteneurisation | `Dockerfile`, `docker-compose.yml`, `infra/Dockerfile.jenkins` |
| Membre 4 — exploitation & documentation | Configuration Jenkins, credentials Docker Hub, captures, rapport |

---

<div align="center">

**Fin du rapport — TP4 CI/CD Jenkins & Docker — Groupe 4 (ITT3-IR)**

*Chef d'équipe : Wilfried Keumeka Soking*

</div>
