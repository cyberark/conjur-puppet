#!/usr/bin/env groovy

pipeline {
  agent { label 'executor-v2' }

  options {
    timestamps()
    parallelsAlwaysFailFast()
  }

  triggers {
    cron(getDailyCronString())
  }

  environment {
    PDK_DISABLE_ANALYTICS = 'true'
  }

  stages {
    stage('Validate') {
      parallel {
        stage('Changelog') {
          steps { sh './parse-changelog.sh' }
        }

        stage('Docs') {
          steps { sh './gen-docs.sh' }
        }
      }
    }

    // Workaround for Jenkins not fetching tags
    stage('Fetch tags') {
      steps {
        withCredentials(
          [usernameColonPassword(credentialsId: 'conjur-jenkins-api', variable: 'GITCREDS')]
        ) {
          sh '''
            git fetch --tags `git remote get-url origin | sed -e "s|https://|https://$GITCREDS@|"`
            git tag # just print them out to make sure, can remove when this is robust
          '''
        }
      }
    }

    stage('Build') {
      steps {
        sh './build.sh'
        archiveArtifacts 'pkg/'
      }
    }

    stage('Tests') {
      parallel {
        stage('Setup Win2016') {
          agent { label 'executor-windows-2016-containers' }
          stages {
            stage('Configure Windows Node'){
              steps {
                powershell '.\\expose-daemon.ps1'
                script {
                  env.WINDOWS_IP = powershell(returnStdout: true, script:  '(curl http://169.254.169.254/latest/meta-data/local-ipv4).Content').trim()
                  env.WINDOWS_DOCKER_CERT_CA = powershell(returnStdout: true, script:  'cat $env:USERPROFILE\\.docker\\ca.pem')
                  env.WINDOWS_DOCKER_CERT_CERT = powershell(returnStdout: true, script:  'cat $env:USERPROFILE\\.docker\\cert.pem')
                  env.WINDOWS_DOCKER_CERT_KEY = powershell(returnStdout: true, script:  'cat $env:USERPROFILE\\.docker\\key.pem')
                  env.WINDOWS_READY = true
                }
              }
            }
            stage('Wait for Main Node') {
              steps {
                waitUntil {
                  script {
                    return (env.MAIN_NODE_DONE == "true");
                  }
                }
              }
            }
          }
        }

        stage('Test Win2016') {
          stages {
            stage("Wait for Windows node") {
              steps {
                waitUntil {
                  script {
                    return (env.WINDOWS_READY == "true");
                  }
                }
                script {
                  env.WINDOWS_DOCKER_CERT_DIR = "${pwd()}/tmp-docker"
                }

                sh "mkdir ${env.WINDOWS_DOCKER_CERT_DIR}"
                writeFile file: "${env.WINDOWS_DOCKER_CERT_DIR}/ca.pem", text: env.WINDOWS_DOCKER_CERT_CA
                writeFile file: "${env.WINDOWS_DOCKER_CERT_DIR}/cert.pem", text: env.WINDOWS_DOCKER_CERT_CERT
                writeFile file: "${env.WINDOWS_DOCKER_CERT_DIR}/key.pem", text: env.WINDOWS_DOCKER_CERT_KEY
              }
            }

            stage('Puppet 6 & Conjur 5 Integration Tests') {
              steps {
                dir('examples/puppetmaster') {
                  sh '''
                    MAIN_HOST_IP="$(curl http://169.254.169.254/latest/meta-data/local-ipv4)" \
                    WINDOWS_DOCKER_HOST="tcp://${WINDOWS_IP}:2376" \
                    WINDOWS_DOCKER_CERT_PATH="${WINDOWS_DOCKER_CERT_DIR}" \
                    WINDOWS_DOCKER_TLS_VERIFY=1 \
                    ./test.sh
                  '''
                }
              }
            }
          }

          post {
            always {
              script {
                env.MAIN_NODE_DONE = true
              }
            }
          }
        }

        stage('Linting & Unit Tests') {
          steps {
            sh './test.sh'
          }

          post {
            always {
              junit 'spec/output/rspec.xml'
              archiveArtifacts artifacts: 'spec/output/rspec.xml', fingerprint: true

              cobertura autoUpdateHealth: false, autoUpdateStability: false, coberturaReportFile: 'coverage/coverage.xml', conditionalCoverageTargets: '100, 0, 0', failNoReports: true, failUnhealthy: true, failUnstable: false, lineCoverageTargets: '99, 0, 0', maxNumberOfBuilds: 0, methodCoverageTargets: '100, 0, 0', onlyStable: false, sourceEncoding: 'ASCII', zoomCoverageChart: false

              sh 'cp coverage/coverage.xml cobertura.xml'
              ccCoverage("cobertura", "github.com/cyberark/conjur-puppet")
            }
          }
        }
      }
    }

    stage('Release Puppet module') {
      // Only run this stage when triggered by a tag
      when {
        tag "v*"
      }
      steps {
        sh './release.sh'
      }
    }
  }

  post {
    always {
      cleanupAndNotify(currentBuild.currentResult)
    }
  }
}
