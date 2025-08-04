// Will hold discovered Dockerfile and build specifics per project
def PROJECTS = []

pipeline {
    agent any
    options {
        parallelsAlwaysFailFast()
    }
    environment {
        DOCKER_REGISTRY = '<AWS ECR/DOCKER/...>'  // Update with your registry
        CONFIG_FILE = 'docker-build.properties'  // Config file name next to Dockerfile that contains build specifics like Image name, context
        DISCORD_WEBHOOK = '<DISCORD WEBHOOK>' // Can be any webhook like Slack
        WEBSITE = 'http(s)://<WEBSITE OR CONTAINER>' // Url to the website we will execute the penetration test against
        AWS_REGION = '<REGION_NAME>' // ECR region
        REMOTE_SERVER = '<REMOTE SERVER IP>' // IP for the server we wants to deploy to
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "${NODE_NAME}" // Print what agent is used in this stage
                checkout scm
            }
        }
        
        // Execute .Net unit tests
        stage('Run unit tests') {
            steps {
                echo "${NODE_NAME}" // Print what agent is used in this stage
                sh 'dotnet test'
            }
        }

        // Instead of creating stages manually, we will automate this step by creating an array of objects "PROJECTS" that will be used in later stages
        stage('Discover Projects') {
            agent any
            steps {
                echo "${NODE_NAME}" // Print what agent is used in this stage
                script {

                    // Find all Dockerfiles and their config files
                    findFiles(glob: '**/Dockerfile').each { dockerFile ->
                        def projectDir = dockerFile.path.split('/Dockerfile')[0]
                        def configFile = "${projectDir}/${CONFIG_FILE}"
                      
                        if (fileExists(configFile)) {

                            // Read image name from config file
                            def config = readProperties file: configFile
                         
                            assert config.IMAGE_NAME != null

                            def context = '.'
                            if(config.BUILD_CONTEXT != null) {
                                context = config.BUILD_CONTEXT
                            }
                            
                            PROJECTS << [
                                dockerFile: dockerFile.path,
                                imageName: config.IMAGE_NAME,
                                context: context
                            ]

                        } else {
                            // Throw an error when config file is not found next the Dockerfile and stop the pipeline
                            error("${env.CONFIG_FILE} was not found in ${projectDir}")
                        }
                    }

                    echo "Discovered projects: ${PROJECTS}"
                }
            }
        }

        // Wait for administrator approval to build and push docker images to DOCKER_REGISTRY     
        stage('Approval for Build and Push Docker Images') {
            steps {
               input 'Wait for Administrator Approval'    
            }
        }

        // Using PROJECTS that was populated from previous stage "Discover Projects", build docker images on jenkins agents and push them to DOCKER_REGISTRY (AWS ECR)
        stage('Build and Push Docker Images') {                
            steps {
                script {
                    // Create a map for parallel stages
                    def parallelStages = [:]
                    PROJECTS.each {project ->                    
                        def stageName = "Build-${project.imageName}"
                        parallelStages[stageName] = {
                           stage(stageName) {           
                              node ('docker-agent') { 
                                echo "${NODE_NAME}" // Print what agent is used in this stage
                                checkout scm                                                      
                                def fullImageName = "${DOCKER_REGISTRY}<ANYTHING IN BETWEEN>${project.imageName}:latest"
                                sh "docker build  ${project.context} -t ${fullImageName} -f ${project.dockerFile}"
                                withCredentials([[
                                    $class: 'AmazonWebServicesCredentialsBinding',
                                    credentialsId: "ecr-user-credentials" // AWS credentials stored in Jenkins controller
                                ]]) {
                                    sh "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $DOCKER_REGISTRY"
                                    sh "docker push ${fullImageName}"
                                }
                              }
                           }
                        }
                    }

                    // Execute all stages in parallel
                    parallel parallelStages                    
                }
            }
        }

        // Wait for administrator approval to deploy pushed images
        stage('Deployment Approval') {
            steps {
               input 'Wait for Administrator Approval'    
            }
        }

        stage('Deploy Docker Images') {
            agent any
            steps { 
                script {
                    node ('docker-agent') {
                        checkout scm
                        def remote = [:]
                        remote.name = "<Remote Name>"
                        remote.host = REMOTE_SERVER
                        remote.allowAnyHosts = true
                        // remote-server-ssh-access is the SSH credentials stored in jenkins to the host
                        // Authenticate to remote server using SSH               
                        withCredentials([sshUserPrivateKey(credentialsId: 'remote-server-ssh-access', keyFileVariable: 'SSH_KEY_FOR_SERVER', passphraseVariable: '', usernameVariable: 'SSH_USER_NAME_FOR_SERVER')]) {
                            remote.user = SSH_USER_NAME_FOR_SERVER
                            remote.identityFile = SSH_KEY_FOR_SERVER
                            // Any pre-steps you want to execute on the remote server like copying deployment files/script
                            // Authenticate access to AWS ECR
                            withCredentials([[
                                $class: 'AmazonWebServicesCredentialsBinding',
                                credentialsId: "ecr-user-credentials" // AWS credentials stored in Jenkins controller
                            ]]) {
                                // Authenticate to AWS ERC to pull new pushed images                                
                                sshCommand remote: remote, command: "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $DOCKER_REGISTRY"
                                // ... Execute your scrips if they depend on AWS ECR like docker compose. 
                            }
                        }
                    }
                }
            }
        }
    
        // Execute penetration test using ZAP - Full Scan https://www.zaproxy.org on the remote server
        // It runs the ZAP spider against the specified target (by default with no time limit) followed by an optional ajax spider scan and then a full active scan before reporting the results.
        // IMPORTANT: This means that the script does perform actual ‘attacks’ and can potentially run for a long period of time.
        stage('Run penetration test') {
            agent any
            steps {
                script {
                    node ('zap-agent') {
                        checkout scm                       
                        def remote = [:]
                        remote.name = "<Remote Name>"
                        remote.host = REMOTE_SERVER
                        remote.allowAnyHosts = true
                        // remote-server-ssh-access is the SSH credentials stored in jenkins to the host
                        // Authenticate to remote server using SSH          
                        withCredentials([sshUserPrivateKey(credentialsId: 'remote-server-ssh-access', keyFileVariable: 'SSH_KEY_FOR_SERVER', passphraseVariable: '', usernameVariable: 'SSH_USER_NAME_FOR_SERVER')]) {
                            remote.user = SSH_USER_NAME_FOR_SERVER
                            remote.identityFile = SSH_KEY_FOR_SERVER
                            // Create zap folder if it does not exist
                            sshCommand remote: remote, command: 'mkdir -p zap'
                            // --net <Network name>: Run docker container on the same network as the Container you are testing, if you are testing a website then it is not needed                            
                            sshCommand remote: remote, command: 'docker run --net <Network name> --rm -v $(pwd)/zap:/zap/wrk/:rw --user root  -t ghcr.io/zaproxy/zaproxy:stable zap-full-scan.py -t <WEBSITE> -r pen-test-report.html'
                            // Copy the penetration report to the workspace to export it to the job artifacts                            
                            sshGet remote: remote, from: "/root/zap/pen-test-report.html", into: "artifact-zap-report.html", override: true                            
                            // Store the report in the job artifacts next the the logs file
                            archiveArtifacts artifacts: "artifact-zap-report.html", followSymlinks: false
                        }
                    }
                }                
            }
        }
    }
    
    
    post {
        always {
            script {
                // Print all built images
                PROJECTS.each { project ->
                    echo "${project}"
                }
            }
            cleanWs()
        }
        success {       
            // On success: Send a notification to Discord OR Slack, in my case it was discord.            
            discordSend description: "Jenkins Pipeline succeeded", footer: "", link: env.BUILD_URL, result: currentBuild.currentResult, title: env.JOB_NAME, webhookURL: env.DISCORD_WEBHOOK
        }
        failure {
            // On failure: Send a notification to Discord OR Slack, in my case it was discord.            
            discordSend description: "Jenkins Pipeline Failed", footer: "", link: env.BUILD_URL, result: currentBuild.currentResult, title: env.JOB_NAME, webhookURL: env.DISCORD_WEBHOOK
        }
    }
}