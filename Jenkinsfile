pipeline {
  agent { label 'maven-agent-01' }


  environment {
    REGISTRY = "ghcr.io"

    GITHUB_USERNAME = "needleback"
    GITHUB_CRED = 'ghcr-credentials'

    APP_NAME = "time-tracker-devops"
    APP_DIR_MODULE1 = 'core'
    APP_DIR_MODULE2 = 'web'
    APP_BRANCH = 'dev'

    IMAGE_NAME = "${env.GITHUB_USERNAME}/${env.APP_NAME}"
    IMAGE_TAG = "${BUILD_NUMBER}"

    REGISTRY_IMAGE_NAME = "${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
    GITHUB_URL = "https://github.com/${env.IMAGE_NAME}.git"

    K8S_NAMESPACE = "diplom"
  }

  stages {

    stage('Checkout') {
      steps {
        git branch: env.APP_BRANCH, changelog: false, credentialsId: env.GITHUB_CRED, poll: false, url: env.GITHUB_URL
      }
    }  

    stage('Identify changes') {
      steps {
        script {

             // --> проверка: Последние изменения
                   //git diff --name-only HEAD~1 HEAD
             // -- либо: Только для проверки указанные коммиты
                   //git diff --name-only 739a468 c3e2372
             // <--
           def changedFiles = sh(
             script: """
               if git rev-parse HEAD~1 >/dev/null 2>&1; then
                   git diff --name-only 7f8aadf 28971d4
               else
                   git diff-tree --no-commit-id --name-only -r HEAD
               fi
             """,
             returnStdout: true
           ).trim()

           if (changedFiles) {
             echo "into if changedFiles"
             // --> проверка: Любое изменение в репозитории
             // env.APP_CHANGED = (changedFiles.size() > 0).toString()
             // -- либо: Только в указанных директориях/файлах
             env.APP_CHANGED = changedFiles
               .split('\n')
               .any {
                 it.startsWith(env.APP_DIR_MODULE1) ||
                 it.startsWith(env.APP_DIR_MODULE2) ||
                 it == 'pom.xml'
               }.toString()
             // <--

           } else {
             env.APP_CHANGED = 'false'
           }

           echo "Changed files:"
           echo changedFiles
           echo "env.APP_CHANGED: ${env.APP_CHANGED}"
        }
      }
    }


    stage('CI/CD') {

      when {
        expression { env.APP_CHANGED == 'true' }
      }

      stages {

        stage('Build') {
          steps {
            sh "mvn clean package -DskipTests"
          }
        }

        stage('Test') {
          steps {
            sh 'mvn test'
            junit(
              testResults: "**/target/surefire-reports/*.xml",
              allowEmptyResults: false
            )
          }
        }

        stage('SonarQube Analysis') {
          steps {
            withSonarQubeEnv(credentialsId: 'sonar', installationName: 'SonarServer') {
              sh """
                  mvn clean verify sonar:sonar \
                    -Dsonar.projectKey=${env.APP_NAME} \
                    -Dsonar.projectName='${env.APP_NAME}'
              """
            }
          }
        }

        stage('SonarQube Quality Gate') {
          steps {
            timeout(time: 2, unit: 'MINUTES') {
              waitForQualityGate abortPipeline: true
            }
          }
        }


        stage('Docker build') {
          steps {
            sh '''
              docker build -t ${REGISTRY_IMAGE_NAME} .
            '''
          }
        }

        stage('Login to registry GHCR') {
          steps {
            withCredentials([
              usernamePassword(
                credentialsId: env.GITHUB_CRED,
                usernameVariable: 'GHCR_USER',
                passwordVariable: 'GHCR_TOKEN'
              )
            ])
            {
              sh '''
                echo $GHCR_TOKEN | docker login ${REGISTRY} \
                    -u $GHCR_USER \
                    --password-stdin
              '''
            }
          }
        }

        stage('Push image to registry GHCR') {
          steps {
            sh '''
              docker push ${REGISTRY_IMAGE_NAME}
            '''
          }
        }

        stage('Deploy to Kubernetes') {
          steps {
            sh '''
              sed "s|IMAGE_PLACEHOLDER|${REGISTRY_IMAGE_NAME}|g" \
              k8s/deployment.yaml.template > k8s/deployment.yaml

              echo "===== generated yaml ====="
              cat k8s/deployment.yaml

              echo "===== ls -la k8s/ ====="
              ls -la k8s/

              echo "===== apply ====="
              kubectl apply -f k8s/

              echo "===== deployments ====="
              kubectl get deployments -A

              echo "===== pods ====="
              kubectl get pods -A
            '''
          }
        }

        stage('Verify Deployment') {
          steps {
            sh '''
              kubectl rollout status deployment/time-tracker \
                -n ${K8S_NAMESPACE} \
                --timeout=120s
            '''
          }
        }
      } // stages

    } // stage('CI/CD')

  } // stages

  post {
    always {
      sh 'docker logout ghcr.io || true'
    }

    success {
      echo 'Deployment completed successfully'
    }

    failure {
      echo 'Deployment failed'
    }
  }

} // pipeline

