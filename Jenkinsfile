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
    stage('Validate') {
      parallel {
        stage('Changelog') {
          steps { sh './parse-changelog.sh' }
        }
      }
    }

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
        stage('Local agent - Conjur v5') {
          steps {
            dir('examples') {
              sh './smoketest.sh'
            }
          }
        }

        stage('E2E - Puppet 5 - Conjur 5') {
          steps {
            dir('examples/puppetmaster') {
              sh './smoketest_e2e.sh 5'
            }
          }
        }

        stage('E2E - Puppet 6 - Conjur 5') {
          steps {
            dir('examples/puppetmaster') {
              sh './smoketest_e2e.sh'
            }
          }
        }

        stage('Local agent - Conjur v4 EE') {
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
