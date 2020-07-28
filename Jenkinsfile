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

    stage('Build') {
      steps {
        sh './build.sh'
        archiveArtifacts 'pkg/'
      }
    }

    stage('Linting and unit tests') {
      parallel {
        stage('Unit tests - Puppet 6') {
          steps {
            sh './test.sh 6'
          }

          post {
            always {
              junit 'spec/output/rspec.xml'
              archiveArtifacts artifacts: 'spec/output/rspec.xml', fingerprint: true
            }
          }
        }

        stage('Unit tests - Puppet 5') {
          steps {
            sh './test.sh'
          }

          post {
            always {
              junit 'spec/output/rspec_puppet5.xml'
              archiveArtifacts artifacts: 'spec/output/rspec_puppet5.xml', fingerprint: true
            }
          }
        }
      }
    }

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
