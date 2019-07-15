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
    // workaround for Jenkins not fetching tags
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

    stage('Release Puppet module') {
      when {
        allOf {
          // Current git HEAD is an annotated tag
          expression {
            sh(returnStatus: true, script: 'git describe --exact | grep -q \'^v[0-9.]\\+$\'') == 0
          }
          not { triggeredBy  'TimerTrigger' }
        }
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
