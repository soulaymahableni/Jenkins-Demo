pipeline {
    agent any

    tools {
        maven 'maven-3.5.2'
    }

    environment {
        registry = "soulaymahableni/demo-jenkins"
    }

    stages {
        stage('Clone Repo') {
            steps {
                git branch: 'main', url: 'https://github.com/soulaymahableni/Jenkins-Demo.git'
            }
        }

        stage('Build App') {
            steps {
                sh "mvn clean package"
            }
        }

        stage('Build image') {
            steps {
                sh "docker build -t $registry:$BUILD_NUMBER ."
            }
        }

        stage('Deploy Docker container') {
            steps {
                sh "docker rm -f demo-jenkins || true"
                sh "docker run --name demo-jenkins -d -p 2222:2222 $registry:$BUILD_NUMBER"
            }
        }
    }

    post {
        success {
            echo 'Pipeline execution successful!'
        }
        failure {
            echo 'Pipeline execution failed.'
        }
    }
}
