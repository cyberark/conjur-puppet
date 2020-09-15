#!/usr/bin/env groovy

pipeline {
  agent { label 'executor-v2' }

  options {
    timestamps()
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


    stage('Tests') {
      parallel {
        stage('Linting and unit tests') {
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

        stage('E2E - Puppet 6 - Conjur 5') {
          steps {
            dir('examples/puppetmaster') {
              sh './test.sh'
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
