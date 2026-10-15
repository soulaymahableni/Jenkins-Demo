# TP Jenkins CI/CD : Spring Boot, Docker et Kubernetes (K3S)

**Réalisé par :** Soulayma Hableni
**Environnement :** VM Ubuntu (VirtualBox) avec Docker, K3S, Maven, Java 17 et Jenkins
**Application de démo :** https://github.com/wahid007/Jenkins-Demo.git (Spring Boot, port 2222)
**Image Docker Hub :** `hablani/spring-demo`

## Sommaire
1. Partie I : Workflow manuel
2. Partie II : Jenkins Freestyle
3. Problèmes rencontrés
4. Conclusion

---

# Partie I : Workflow manuel

## Étape 1 : Dockerfile

L'application écoute sur le port **2222** (`server.port=2222` dans `application.properties`).

```dockerfile
FROM eclipse-temurin:17-jre
EXPOSE 2222
WORKDIR /app
COPY target/*.jar app.jar
CMD ["java", "-jar", "app.jar"]
```

## Étape 2 : Build Maven et image Docker

```bash
mvn clean install
docker build -t spring-demo:1.0 .
docker run --detach --name spring-test -p 9090:2222 spring-demo:1.0
curl http://localhost:9090
```

Test de l'application dans le conteneur depuis la machine physique (`192.168.190.141:9090`) :

![Application dans Docker](images/08-app-navigateur.png)

## Étape 3 : Push sur Docker Hub

Connexion avec un *Personal Access Token* (permission Read & Write), puis tag et push :

```bash
cat ~/token.txt | docker login -u hablani --password-stdin
docker tag spring-demo:1.0 hablani/spring-demo:1.0
docker push hablani/spring-demo:1.0
```

Connexion réussie :

![docker login](images/02-docker-login.png)

Image envoyée sur Docker Hub :

![docker push](images/03-docker-push.png)

## Étape 4 : Déploiement sur K3S

`deployment.yaml` :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-app-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spring-app
  template:
    metadata:
      labels:
        app: spring-app
    spec:
      containers:
      - name: spring-app-container
        image: hablani/spring-demo:1.0
        ports:
        - containerPort: 2222
```

`service.yaml` :

```yaml
apiVersion: v1
kind: Service
metadata:
  name: spring-app-service
spec:
  selector:
    app: spring-app
  ports:
  - protocol: TCP
    port: 2222
    targetPort: 2222
  type: NodePort
```

Application du déploiement :

```bash
kubectl apply -f deployment.yaml
kubectl get pods
```

![kubectl apply deployment](images/04-kubectl-apply.png)

Les deux pods passent de `ContainerCreating` à `Running` :

![Pods Running](images/05-pods-running.png)

Création du service et lecture du NodePort (**32030**) :

```bash
kubectl apply -f service.yaml
kubectl get svc
```

![kubectl get svc](images/06-service-nodeport.png)

Test de l'application :

```bash
curl http://localhost:32030
```

![curl NodePort](images/07-curl-nodeport.png)

---

# Partie II : Jenkins Freestyle

## Étape 1 : Premier job `freestyle_demo`

Script shell du job :

```bash
echo 'Bonjour'
ls -l
echo 'Bonjour DevOps' > test.txt
ls -l
```

Job exécuté avec succès :

![Job freestyle_demo](images/09-freestyle-job.png)

Sortie de la console du build #1 :

![Console build 1](images/10-console-build1.png)

Le fichier est créé dans `/var/lib/jenkins/workspace/freestyle_demo` :

```bash
cat /var/lib/jenkins/workspace/freestyle_demo/test.txt
```

![test.txt](images/01-test-txt.png)

## Étape 2 : Fichier `Test.java`

`Test.java` affiche `Hi Master DevOps`, et la commande `java Test.java` est ajoutée au job :

```java
public class Test {
    public static void main(String[] args) {
        System.out.println("Hi Master DevOps");
    }
}
```

Build #2 :

![Console build 2](images/11-console-build2-java.png)

## Étape 3 : Script récupéré depuis GitHub

Le dépôt `https://github.com/soulaymahableni/jenkins-tp.git` contient `script.sh` et `Test.java`. Jenkins le clone (section **Gestion de code source**), puis exécute :

```bash
chmod +x script.sh
./script.sh
```

Build #3 (clonage Git puis exécution du script) :

![Console build 3](images/12-console-build3-git.png)

Résultat de l'exécution (`Hi Master DevOps`, `Finished: SUCCESS`) :

![Résultat script.sh](images/13-script-sh-success.png)

## Étape 4 : Déclenchement automatique et rétention

Configuration du job `freestyle_demo` :

| Paramètre | Valeur |
|---|---|
| Construire périodiquement | `H/5 * * * *` |
| Supprimer les anciens builds | 2 builds conservés |
| Delete workspace before build starts | activé |


## Étape 5 : Challenge, déploiement automatique sur Kubernetes

### Identifiants Docker Hub

Les identifiants sont stockés dans Jenkins (`dockerhub-creds`), et non en clair dans le script :

![Credentials](images/14-credentials.png)

### Job `spring-deploy`

Les identifiants sont injectés dans les variables `DOCKER_USER` et `DOCKER_PASS`. Script shell du build :

```bash
set -e

IMAGE="$DOCKER_USER/spring-demo:$BUILD_NUMBER"

mvn clean install
docker build -t "$IMAGE" .

echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
docker push "$IMAGE"

sed -i "s|image: .*|image: $IMAGE|" deployment.yaml

kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl rollout status deployment/spring-app-deployment --timeout=180s
kubectl get pods
kubectl get svc
```

Le job enchaîne : build Maven, build de l'image, push Docker Hub, mise à jour de l'image dans `deployment.yaml`, puis déploiement sur K3S.

Résultat (`deployment successfully rolled out`, `Finished: SUCCESS`) :

![spring-deploy SUCCESS](images/15-spring-deploy-success.png)

---

---

# Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|---|---|---|
| `docker build` : `COPY failed: no source files` | Commande lancée hors du projet, JAR absent | Se placer dans `~/Jenkins-Demo`, exécuter `mvn clean install` |
| `curl` : `Connection reset by peer` | Mapping `-p 9090:8080` alors que l'app écoute sur 2222 | `-p 9090:2222` |
| `address already in use` (port 2222) | Port déjà occupé sur la VM | Mapper un autre port côté VM (9090) |
| `docker login` : `malformed HTTP Authorization header` | Placeholder `VOTRE_USER` laissé dans la commande | Utiliser le vrai username `hablani` |
| `docker login` : `incorrect username or password` | Token mal collé ou jamais utilisé | Nouveau token, lu depuis un fichier avec `--password-stdin` |
| `kubectl` bloqué | VM surchargée (3,3 Go de RAM) | Arrêter les conteneurs inutiles, redémarrer K3S |
| Application inaccessible depuis la machine physique | Adresse Host-only injoignable | Utiliser `192.168.190.141` |
| `mvn` : `can't cd to /home/automatisation/...` | L'utilisateur `jenkins` n'a pas accès au dossier personnel | Lancer le test depuis `/tmp` |
| `spring-deploy` : `docker login` en échec | Mauvais mot de passe dans le credential | Recréer le credential `dockerhub-creds` |

---

# Conclusion

Ce TP a permis de mettre en place une chaîne CI/CD complète : conteneurisation d'une application Spring Boot avec Docker, publication sur Docker Hub, déploiement sur Kubernetes (K3S), puis automatisation avec Jenkins jusqu'au job `spring-deploy` (build Maven, image Docker, push, déploiement). Les identifiants sont stockés dans les *Credentials* de Jenkins, jamais en clair dans les scripts.
