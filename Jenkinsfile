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
      parallel {
        stage('Test with Conjur v5') {
          steps {
            dir('examples') {
              sh './smoketest.sh'
            }
          }
        }

        stage('Test with Conjur Enterprise v4') {
          steps {
            dir('examples/ee') {
              sh './smoketest.sh'
            }
          }
        }
      }
    }
  }

  post {
    always {
      sh 'docker run -i --rm -v $PWD:/src -w /src alpine/git clean -fxd'
      deleteDir()
    }
    failure {
      slackSend(color: 'danger', message: "${env.JOB_NAME} #${env.BUILD_NUMBER} FAILURE (<${env.BUILD_URL}|Open>)")
    }
    unstable {
      slackSend(color: 'warning', message: "${env.JOB_NAME} #${env.BUILD_NUMBER} UNSTABLE (<${env.BUILD_URL}|Open>)")
    }
  }
}
