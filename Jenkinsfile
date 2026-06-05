pipeline {

    agent {
        kubernetes {
            label 'banking-agent'
            defaultContainer 'maven'

            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:

  - name: maven
    image: maven:3.9.6-eclipse-temurin-17
    command: ['cat']
    tty: true

  - name: docker
    image: docker:24-dind
    command: ['cat']
    tty: true

  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['cat']
    tty: true
"""
        }
    }

    environment {

        SONAR_HOST_URL = 'http://192.168.0.8:30474'
        SONAR_TOKEN = credentials('sonar-token')

        NEXUS_URL = 'http://192.168.0.8:30081'
        HARBOR_REGISTRY = 'harbor.local/banking'
        IMAGE_NAME = 'banking-app'
        TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Pre-Check') {
            steps {
                container('maven') {
                    sh '''
                        pwd
                        ls -la
                        java -version
                        mvn -version
                    '''
                }
            }
        }

        stage('Build Maven') {
            steps {
                container('maven') {
                    sh 'mvn clean package -DskipTests'
                }
            }
        }

        stage('Verify Artifact') {
            steps {
                container('maven') {
                    sh '''
                        ls -lh target/
                        find target -name "*.jar"
                    '''
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                container('maven') {
                    sh """
                        mvn sonar:sonar \
                        -Dsonar.host.url=${SONAR_HOST_URL} \
                        -Dsonar.login=${SONAR_TOKEN}
                    """
                }
            }
        }

        stage('Deploy to Nexus') {
            steps {
                container('maven') {
                    withCredentials([usernamePassword(
                        credentialsId: 'nexus-creds',
                        usernameVariable: 'NEXUS_USER',
                        passwordVariable: 'NEXUS_PASS'
                    )]) {

                        sh """
                            mvn deploy -DskipTests \
                            -DaltDeploymentRepository=nexus::default::${NEXUS_URL}/repository/maven-releases \
                            -Dnexus.username=${NEXUS_USER} \
                            -Dnexus.password=${NEXUS_PASS}
                        """
                    }
                }
            }
        }

        stage('Docker Build') {
            steps {
                container('docker') {
                    sh """
                        docker build -t $HARBOR_REGISTRY/$IMAGE_NAME:$TAG .
                        docker tag $HARBOR_REGISTRY/$IMAGE_NAME:$TAG $HARBOR_REGISTRY/$IMAGE_NAME:latest
                    """
                }
            }
        }

        stage('Harbor Push') {
            steps {
                container('docker') {
                    withCredentials([usernamePassword(
                        credentialsId: 'harbor-creds',
                        usernameVariable: 'H_USER',
                        passwordVariable: 'H_PASS'
                    )]) {

                        sh """
                            echo $H_PASS | docker login harbor.local -u $H_USER --password-stdin

                            docker push $HARBOR_REGISTRY/$IMAGE_NAME:$TAG
                            docker push $HARBOR_REGISTRY/$IMAGE_NAME:latest
                        """
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    sh """
                        kubectl set image deployment/banking-app \
                        banking-app=$HARBOR_REGISTRY/$IMAGE_NAME:$TAG -n banking

                        kubectl rollout status deployment/banking-app -n banking
                        kubectl get pods -n banking -o wide
                    """
                }
            }
        }
    }

    post {

        success {
            echo "========== PIPELINE SUCCESS =========="
        }

        failure {
            echo "========== PIPELINE FAILED =========="
        }

        always {
            sh '''
                echo "Build: ${BUILD_NUMBER}"
                echo "Job: ${JOB_NAME}"
                echo "Workspace: ${WORKSPACE}"
            '''
        }
    }
}
