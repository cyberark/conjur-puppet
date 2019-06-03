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
    stage('Lint and unit test module') {
      parallel {
        stage('Test on Linux') {
          steps {
            sh './test.sh'
            junit 'spec/output/rspec.xml'
            archiveArtifacts artifacts: 'spec/output/rspec.xml', fingerprint: true
          }
        }
        stage('Test on Windows') {
          agent {
            label "windows && 2016 && ephemeral"
          }
          steps {
            powershell 'echo "test from Windows"'
          }
        }
      }
    }

    // stage('Run smoke tests') {
    //   parallel {
    //     stage('Test with Conjur v5') {
    //       steps {
    //         dir('examples') {
    //           sh './smoketest.sh'
    //         }
    //       }
    //     }

    //     stage('Test with Conjur Enterprise v4') {
    //       steps {
    //         dir('examples/ee') {
    //           sh './smoketest.sh'
    //         }
    //       }
    //     }
    //   }
    // }
  }

  post {
    always {
      cleanupAndNotify(currentBuild.currentResult)
    }
  }
}
