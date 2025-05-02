#!/usr/bin/env groovy
@Library('conjur-enterprise-sharedlib') _

pipeline {
  agent { label 'conjur-enterprise-common-agent' }

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
    stage('Get InfraPool ExecutorV2 Agent') {
      steps {
        script {
          // Request ExecutorV2 agents for 3 hour(s)
          INFRAPOOL_EXECUTORV2_AGENT_0 = getInfraPoolAgent.connected(type: "ExecutorV2", quantity: 1, duration: 5)[0]
          INFRAPOOL_EXECUTORV2_AGENT_1 = getInfraPoolAgent.connected(type: "ExecutorV2", quantity: 1, duration: 5)[0]
        }
      }
    }  
    stage('Validate') {
      parallel {
        stage('Changelog') {
          steps { 
            script {
              sh """
                if [ ! -f CHANGELOG.md ]; then
                  echo "CHANGELOG.md not found!"
                  exit 1
                fi
              """
              def changelogOutput = parseChangelog()
            }
          }
        }

        stage('Docs') {
          steps {
            script {
              INFRAPOOL_EXECUTORV2_AGENT_0.agentSh './ci/gen-docs.sh' 
            } 
          }  
        }
      }
    }

    stage('Build') {
      steps {
        script {
          def buildlog = INFRAPOOL_EXECUTORV2_AGENT_0.agentSh(script: './ci/build.sh', returnStdout: true).trim()
          INFRAPOOL_EXECUTORV2_AGENT_0.agentStash name: 'pkg', includes: 'pkg/**'
          unstash 'pkg'
          archiveArtifacts artifacts: 'pkg/cyberark-conjur.tar.gz', fingerprint: true
        }
      }
    }

    stage('Tests') {
      parallel {
        stage('Running Tests') {
          steps {
            script {
              def testlog = INFRAPOOL_EXECUTORV2_AGENT_1.agentSh(script: './ci/test.sh', returnStdout: true).trim()
              INFRAPOOL_EXECUTORV2_AGENT_1.agentStash name: 'spec', includes: 'spec/**'
              unstash 'spec'
            }
          }

          post {
            always {
              junit 'spec/output/rspec.xml'
              archiveArtifacts artifacts: 'spec/output/rspec.xml', fingerprint: true
            }
          }
        }
      }
    }

    stage('Check Tag') {
      steps {
        script {
          sh "git config --global --add safe.directory ${WORKSPACE}"
          env.TAG = sh(script: "git tag --points-at HEAD", returnStdout: true).trim()
        }
      }
    }

    stage('Release Puppet module') {
      // Only run this stage when triggered by a tag
      when {
        expression {
          return env.TAG ==~ /^v.*/
        }
      }
      steps {
        script {
          def releaseLog0 = INFRAPOOL_EXECUTORV2_AGENT_0.agentSh(script: './ci/release.sh', returnStdout: true).trim()
          def releaseLog1 = INFRAPOOL_EXECUTORV2_AGENT_1.agentSh(script: './ci/release.sh', returnStdout: true).trim()
        }
      }
    }
  }

  post {
    always {
      releaseInfraPoolAgent(".infrapool/release_agents")
      sh 'git config --global --add safe.directory ${PWD}'
      infraPostHook()
      // Remove this Jenkins Agent's IP from AWS security groups
      removeIPAccess(INFRAPOOL_EXECUTORV2_AGENT_0)
      removeIPAccess(INFRAPOOL_EXECUTORV2_AGENT_1)
    }
  }
}
