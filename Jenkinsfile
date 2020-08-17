pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                def RepositoryName  = params.MicroService
                currentBuild.displayName = RepositoryName + " # ${env.BUILD_ID}"
                sh 'mvn -Dskiptests clean install'
            }
        }
        stage('Test') {
            steps {
                sh 'mvn test'
            }
        }
    }
}
