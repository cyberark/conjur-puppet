#!/usr/bin/env groovy

pipeline {
  agent { label 'executor-v2' }

  options {
    timestamps()
  }

  triggers {
    cron(getDailyCronString())
  }

  stages {
    stage('Run smoke tests') {
      parallel {
        stage('E2E - Puppet 5 - Conjur 5') {
          steps {
            dir('examples/puppetmaster') {
              sh './test.sh 5'
            }
          }
        }

        stage('E2E - Puppet 6 - Conjur 5') {
          steps {
            dir('examples/puppetmaster') {
              sh './test.sh'
            }
          }
        }
      }
    }
  }

  post {
    always {
      cleanupAndNotify(currentBuild.currentResult)
    }
  }
}
