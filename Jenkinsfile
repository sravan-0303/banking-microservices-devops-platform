pipeline {
    agent {
        docker {
            image 'maven:3.9.6-eclipse-temurin-17'
            args '-v /root/.m2:/root/.m2'
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

        stage('Pre-Check') {
            steps {
                echo "========== PRECHECK =========="

                sh '''
                    pwd
                    ls -la
                    java -version
                    mvn -version
                '''
            }
        }

       
        stage('Build Maven') {
            steps {
                echo "========== MAVEN BUILD =========="

                sh '''
                    mvn clean package -DskipTests
                '''
            }
        }

        stage('Verify Artifact') {
            steps {
                sh '''
                    ls -lh target/
                    find target -name "*.jar"
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                echo "========== SONARQUBE =========="

                sh '''
                    mvn sonar:sonar \
                    -Dsonar.host.url=${SONAR_HOST_URL} \
                    -Dsonar.login=${SONAR_TOKEN}
                '''
            }
        }

        stage('Deploy to Nexus') {
            steps {
                echo "========== NEXUS DEPLOY =========="

                withCredentials([usernamePassword(
                    credentialsId: 'nexus-creds',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {

                    sh '''
                        mvn deploy -DskipTests \
                        -DaltDeploymentRepository=nexus::default::${NEXUS_URL}/repository/maven-releases \
                        -Dnexus.username=${NEXUS_USER} \
                        -Dnexus.password=${NEXUS_PASS}
                    '''
                }
            }
        }

        stage('Docker Build') {
            steps {
                echo "========== DOCKER BUILD =========="

                sh '''
                    docker build -t $HARBOR_REGISTRY/$IMAGE_NAME:$TAG .
                    docker tag $HARBOR_REGISTRY/$IMAGE_NAME:$TAG $HARBOR_REGISTRY/$IMAGE_NAME:latest
                '''
            }
        }

        stage('Harbor Login & Push') {
            steps {
                echo "========== HARBOR PUSH =========="

                withCredentials([usernamePassword(
                    credentialsId: 'harbor-creds',
                    usernameVariable: 'H_USER',
                    passwordVariable: 'H_PASS'
                )]) {

                    sh '''
                        echo $H_PASS | docker login harbor.local -u $H_USER --password-stdin

                        docker push $HARBOR_REGISTRY/$IMAGE_NAME:$TAG
                        docker push $HARBOR_REGISTRY/$IMAGE_NAME:latest
                    '''
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                echo "========== K8S DEPLOY =========="

                sh '''
                    kubectl set image deployment/banking-app \
                    banking-app=$HARBOR_REGISTRY/$IMAGE_NAME:$TAG -n banking

                    kubectl rollout status deployment/banking-app -n banking
                    kubectl get pods -n banking -o wide
                '''
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
                echo "Build Number: ${BUILD_NUMBER}"
                echo "Job Name: ${JOB_NAME}"
                echo "Workspace: ${WORKSPACE}"
            '''
        }
    }
}
