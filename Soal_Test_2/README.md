# Section 2. CI/CD Test

## Goals

User will create CI/CD flow about web application, we will use nginx as webserver and simply add hello.txt into the image.

Then, push the image into registry then deploy the apps to our instance.

## Prerequisites
- Instance for CI/CD Tools, e.g Jenkins
- Dependencies like Git, Docker, Java 8 SE
- Container Registry
- SCM, e.g GitHub

## Proof of Concept
### Repo's side
We will need to add config to change root of our webserver. Let's name it default.conf
```
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;

    location / {
        root   /var/www/;
        index  index.html index.htm;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
```

Then, we will need to add index.html (optional) and hello.txt. Just use simple text.  

index.html
```
under construction!
```
hello.txt
```
Hi, I'm Boy.
Nice to meet you!
```

After that, we can setup the Dockerfile.
```
FROM nginx:latest
COPY ./default.conf /etc/nginx/conf.d/default.conf
COPY ./index.html /var/www/index.html
COPY ./hello.txt /var/www/hello.txt
```

Our application is ready to integrate.

We assume that you're repo is in this link https://github.com/dragz17/test02_nginxcustom

### CI/CD Tool's side
1. Create New Item (Job)
I use pipeline type and set name as cicd_custom_nginx
![image](https://user-images.githubusercontent.com/20719811/129024867-dcbd21d2-dbd6-44da-9e14-c2a79fcd06f3.png)

2. Let other config as default, if you want to set Webhook, add like this. (this is optional)
![image](https://user-images.githubusercontent.com/20719811/129025102-65d2286c-5520-497b-b0c7-37e4ed985e02.png)

3. Add pipeline script
```
pipeline {
    agent{
        label 'mastering-agent'
    }
    environment {
        repoURL = 'git@github.com:dragz17/test02_nginxcustom.git'
        myImage = 'nginx-custom'
        myRepoTarget  = "registry-intl-vpc.ap-southeast-5.aliyuncs.com/boy-cr"
    }
    stages {
        stage ('Checkout') {
            steps {
                checkout([$class: 'GitSCM', branches: [[name: '*/main']], userRemoteConfigs: [[credentialsId: 'github-dragz17', url: env.repoURL]]])
            }
        }
        
        stage ('Build & Test'){
            parallel {
                stage('Build'){
                    steps{
                        
                        script {
                            try {
                                dockerImage = docker.build("$env.myRepoTarget/$env.myImage")
                                buildStatus = true
                            }
                            catch (Exception err) {
                                        buildStatus = false
                            }
                        }
                    }
                }
                
                stage('Test'){
                    steps {
                        script {
                            try {
                                sh "docker --version"
                                testStatus = true
                            } catch(Exception err) {
                                testStatus = false
                            }
                        }
                    }
                }
            }
        }
        
        stage('Push Image'){
            when {
                expression {
                    buildStatus && testStatus
                }
            }
            steps {
                script {
                    dockerImage.push()
                }
            }
        }
        
        stage('Run Image'){
            steps{
                script{
                    deployImage= "${dockerImage.imageName()}"
                    
                        try {
                            timeout(time: 1, unit: 'DAYS') {
                                env.userChoice = input message: 'Do you want to Release?',
                                parameters: [choice(name: 'Versioning Service', choices: 'no\nyes', description: 'Choose "yes" if you want to release this build')]
                            }
                            if (userChoice == 'no') {
                                echo "User refuse to release this build, stopping...."
                            } 
                            else {
                                try{
                                    docker.image(deployImage).run('--name ${myImage} -p 80:80') 
                                    deployStatus = true
                                }
                                catch(Exception err) {
                                    sh 'docker stop ${myImage}'
                                    sh 'docker rm ${myImage}'
                                    docker.image(deployImage).run('--name ${myImage} -p 80:80')
                                }
                            }
                        }
                        catch(Exception err) {
                            echo "the operation has been aborted"
                            deployStatus = false
                        }
                        
                    }
                    
                }
            }
        
    }
    
}
```

Then you can see your application running successfully.

## Screenshots
1. Webhook
![image](https://user-images.githubusercontent.com/20719811/129025522-eedab6cb-b4ac-49dc-adbb-aec90ce2902d.png)

2. Pipeline running successfully
![image](https://user-images.githubusercontent.com/20719811/129025573-66520669-6007-4362-b8e2-ba4b50097be9.png)

3. Our image on container registry
![image](https://user-images.githubusercontent.com/20719811/129025626-71bfeab3-de60-4dbc-afc0-51a59c4916b9.png)

4. Masked Credential on jenkins
![image](https://user-images.githubusercontent.com/20719811/129025695-71791a48-88c2-43c0-b136-3d392d84ddde.png)

5. Confirmation to deploy apps
![image](https://user-images.githubusercontent.com/20719811/129025766-b9253a88-d1cb-4cbb-9001-467031ba8b7b.png)

6. Hello txt now online
![image](https://user-images.githubusercontent.com/20719811/129025883-d04a26e2-c0a6-49b2-825d-85592d7f966c.png)

