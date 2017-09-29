#!/usr/bin/env groovy

pipeline {
  agent { label 'executor-v2' }

  options {
    timestamps()
  }

  stages {
    stage('Lint and unit test module') {
      steps {
        sh './test.sh'
        junit 'spec/output/rspec.xml'
        archiveArtifacts artifacts: 'spec/output/rspec.xml', fingerprint: true
      }
    }

    stage('Run smoke tests') {
      steps {
        parallel: (
          "Conjur v5": {
            dir('examples') {
              sh './smoketest.sh'
            }
          },

          "Conjur Enterprise v4": {
            dir('examples/ee') {
              sh './smoketest.sh'
            }
          }
        }
      }
    }
  }

  post {
    failure {
      slackSend(color: 'danger', message: "${env.JOB_NAME} #${env.BUILD_NUMBER} FAILURE (<${env.BUILD_URL}|Open>)")
    }
    unstable {
      slackSend(color: 'warning', message: "${env.JOB_NAME} #${env.BUILD_NUMBER} UNSTABLE (<${env.BUILD_URL}|Open>)")
    }
  }
}
