#!/usr/bin/env groovy

pipeline {
  agent { label 'executor-v2' }

  parameters { 
    booleanParam(name: 'AWS_INTEGRATION_TESTS', defaultValue: false, description: '') 
  }

  options {
    timestamps()
  }

  triggers {
    cron(getDailyCronString())
  }

  stages {
    stage('Lint and unit test module') {
      steps {
        sh './test.sh'
        junit 'spec/output/rspec.xml'
        archiveArtifacts artifacts: 'spec/output/rspec.xml', fingerprint: true
      }
    }

    stage('Run integration tests') {
      parallel {
        stage('Smoke test with Conjur v5') {
          steps {
            dir('examples') {
              sh './smoketest.sh'
            }
          }
        }

        stage('Smoke test with Conjur Enterprise v4') {
          steps {
            dir('examples/ee') {
              sh './smoketest.sh'
            }
          }
        }

        stage('Integration test on AWS') {
          when {
                expression { params.AWS_INTEGRATION_TESTS == true }
            }
          steps {
              sh 'summon -f secrets_integration.yml ./integration-test.sh'
          }
        }
      }
    }
  }

  post {
    always {
      sh 'summon -f secrets_integration.yml ./cleanup-terraform.sh'
      cleanupAndNotify(currentBuild.currentResult)
    }
  }
}
