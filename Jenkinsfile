#!/usr/bin/env groovy
@Library("product-pipelines-shared-library") _

// Automated release, promotion and dependencies
properties([
  release.addParams(),
  dependencies([])
])

// Performs release promotion.  No other stages will be run
if (params.MODE == "PROMOTE") {
  release.promote(params.VERSION_TO_PROMOTE) { INFRAPOOL_EXECUTORV2_AGENT_0, sourceVersion, targetVersion, assetDirectory ->
    // Release to Puppet Forge
    INFRAPOOL_EXECUTORV2_AGENT_0.agentSh "./ci/release.sh"
  }
  // Copy Github Enterprise release to Github
  release.copyEnterpriseRelease(params.VERSION_TO_PROMOTE)
  return
}

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
    // Sets the MODE to the specified or autocalculated value as appropriate
    MODE = release.canonicalizeMode()
    PDK_DISABLE_ANALYTICS = 'true'
  }

  stages {
    stage('Scan for internal URLs') {
      steps {
        script {
          detectInternalUrls()
        }
      }
    }

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
        // Generates a VERSION file based on the current build number and latest version in CHANGELOG.md
        stage('Validate Changelog and set version') {
          steps {
            script {
              updateVersion(INFRAPOOL_EXECUTORV2_AGENT_0, "CHANGELOG.md", "${BUILD_NUMBER}")
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
        stage('Unit Tests') {
          steps {
            script {
              INFRAPOOL_EXECUTORV2_AGENT_0.agentSh './ci/test.sh'
              INFRAPOOL_EXECUTORV2_AGENT_0.agentStash name: 'spec', includes: 'spec/**'
              INFRAPOOL_EXECUTORV2_AGENT_0.agentStash name: 'coverage', includes: 'coverage/**'
            }
          }

          post {
            always {
              unstash 'spec'
              unstash 'coverage'

              junit 'spec/output/rspec.xml'
              archiveArtifacts artifacts: 'spec/output/rspec.xml', fingerprint: true

              cobertura autoUpdateHealth: false,
                autoUpdateStability: false,
                coberturaReportFile: 'coverage/coverage.xml',
                conditionalCoverageTargets: '70, 0, 0',
                failUnhealthy: false,
                failUnstable: false,
                maxNumberOfBuilds: 0,
                lineCoverageTargets: '70, 0, 0',
                methodCoverageTargets: '70, 0, 0',
                onlyStable: false,
                sourceEncoding: 'ASCII',
                zoomCoverageChart: false

              codacy action: 'reportCoverage', filePath: "coverage/coverage.xml"
              archiveArtifacts artifacts: 'coverage/coverage.xml', fingerprint: true
            }
          }
        }
        stage ('Integration Tests (Puppet 8)') {
          steps {
            script {
              INFRAPOOL_EXECUTORV2_AGENT_1.agentSh 'cd ./examples/puppetmaster/ && INSTALL_PACKAGED_MODULE=false ./test.sh'
            }
          }
        }
        stage ('Integration Tests (Puppet 7)') {
          steps {
            script {
              INFRAPOOL_EXECUTORV2_AGENT_0.agentSh 'cd ./examples/puppetmaster/ && INSTALL_PACKAGED_MODULE=false PUPPET_SERVER_TAG=7-latest ./test.sh'
            }
          }
        }
      }
    }

    stage('Release') {
      when {
        expression {
          MODE == "RELEASE"
        }
      }
      steps {
        script {
          release(INFRAPOOL_EXECUTORV2_AGENT_0) { billOfMaterialsDirectory, assetDirectory, toolsDirectory ->
            // Publish release artifacts to all the appropriate locations
            // Copy any artifacts to assetDirectory to attach them to the Github release
          }
        }
      }
    }
  }

  post {
    always {
      script {
        releaseInfraPoolAgent(".infrapool/release_agents")
      }
    }
  }
}
