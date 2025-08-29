# Introduction
This is a modified version of the [spring-petclinic-microservices](https://github.com/spring-petclinic/spring-petclinic-microservices) Spring Boot sample application. 
Our modifications focus on showcasing the capabilities of Application Signals within a Spring Boot environment.
If your interest lies in exploring the broader aspects of the Spring Boot stack, we recommend visiting the original repository at [spring-petclinic-microservices](https://github.com/spring-petclinic/spring-petclinic-microservices).

In the following, we will focus on how customers can set up the current sample application to explore the features of Application Signals.

# Disclaimer

This code for sample application is intended for demonstration purposes only. It should not be used in a production environment or in any setting where reliability/security is a concern.

# Prerequisite
* A Linux machine with x86-64 (AMD64) architecture is required for building Docker images for the sample application.
* Docker is installed and running on the machine.
* AWS CLI 2.x is installed. For more information about installing the AWS CLI, see [Install or update the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
* kubectl is installed - https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
* eksctl is installed - https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html
* jq is installed - https://jqlang.github.io/jq/download/
* AWS CDK >= v2.186.0 is installed - https://docs.aws.amazon.com/cdk/v2/guide/getting_started.html#getting_started_install
* Node.js >= v18.0.0 is installed.
* [Optional] If you plan to install the infrastructure resources using Terraform, terraform cli is required. https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
* [Optional] If you want to try out AWS Bedrock/GenAI support with Application Signals, enable Amazon Titian, Anthropic Claude, Meta Llama foundation models by following the instructions in https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html

# EKS demo

## Deploy via Shell Scripts
[AWS Cloud9](https://docs.aws.amazon.com/cloud9/latest/user-guide/welcome.html) is no longer available for use with new accounts.
そのため、EC2上に作成した Visual Studio Code を利用します。

### Creating Visual Studio Code on EC2

1. Cloudformationの画面を開きます。[Create stack]を選択します。[Upload a template file]を選択し、ファイル「ec2-ssm.yml」を選択します。「Next」をクリックします。[Stack name] に `ec2-ssm` を入力します。[Next]をクリックします。[I acknowledge that AWS CloudFormation might create IAM resources with custom names.]をチェックします。[Next]をクリックします。[Submit]をクリックし、Slackを作成します。

3. Wait until the stack status changes to **CREATE_COMPLETE**. This usually takes about 7-8 minutes.

4. 作成されたEC2インスタンスのインスタンスロールに `AdministratorAccess` ポリシーをアタッチします。

7. Open the **Outputs** tab. VSCodeWebUrl の URL を開きます。Passwordを求められるため、Password を入力します。

8. Visual Studio Code will be displayed.

9. Select ≡ > Terminal > New Terminal in the top left to display the terminal.

10. Run the following commands in the terminal to install Docker:

``` shell
   # Add Docker's official GPG key:
   sudo apt-get update
   sudo apt-get install ca-certificates curl
   sudo install -m 0755 -d /etc/apt/keyrings
   sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
   sudo chmod a+r /etc/apt/keyrings/docker.asc

   # Add the repository to Apt sources:
   echo \
     "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
     $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   sudo apt-get update

   sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

   sudo usermod -aG docker $USER
   newgrp docker

   docker run hello-world
```

11. Run the following commands in the terminal to install JDK:

   ``` shell
   sudo apt install -y openjdk-17-jdk
   java -version
   ```

11. Run the following commands in the terminal to install go-lang:
   ``` shell
   sudo apt install golang-1.22
   GOPATH=~/go
   GOROOT=/usr/lib/go-1.22
   PATH=$GOROOT/bin:$PATH
   go version
   ```

12. Run the following command in the terminal to download the demo code:

``` shell
git clone https://github.com/hibira/application-signals-demo.git
cd application-signals-demo
git checkout remove-cloud9
```

### Build the sample application images and push to ECR

1. Build container images for each micro-service application

``` shell
set MAVEN_OPTS=-Dmaven.test.skip=true
./mvnw clean install -P buildDocker
```

2. Create an ECR repo for each micro service and push the images to the relevant repos. Replace the aws account id and the AWS Region.

``` shell
   export ACCOUNT=`aws sts get-caller-identity | jq .Account -r`
   echo ACCOUNT=$ACCOUNT
   export REGION=$(TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` \
&& curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
   echo REGION=$REGION
   ./push-ecr.sh
```

### Try Application Signals with the sample application
1. Set up a EKS cluster and deploy sample app.

``` shell
   export REGION=$(TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` \
&& curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
   echo REGION=$REGION
   cd scripts/eks/appsignals && ./setup-eks-demo.sh --region=$REGION
``` 

2. Clean up after you are done with the sample app.
```
   export REGION=$(TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` \
&& curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
   echo REGION=$REGION
   cd scripts/eks/appsignals/ && ./setup-eks-demo.sh --operation=delete --region=$REGION
```

Please be aware that this sample application includes a publicly accessible Application Load Balancer (ALB), enabling easy interaction with the application. If you perceive this public ALB as a security risk, consider restricting access by employing [security groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-update-security-groups.html).


# EC2 Demo
The following instructions describe how to set up the pet clinic sample application on EC2 instances. You can run these steps in your personal AWS account to follow along (Not recommended for production usage).

1. Create resources and deploy sample app. Replace `region-name` with the region you choose.
   ```
   cd scripts/ec2/appsignals/ && ./setup-ec2-demo.sh --region=region-name
   ```


2. Clean up after you are done with the sample app. Replace `region-name` with the same value that you use in previous step.
   ```
   cd scripts/ec2/appsignals/ && ./setup-ec2-demo.sh --operation=delete --region=region-name
   ```


# K8s Demo
The following instructions set up an kubernetes cluster on 2 EC2 instances (one master and one worker node) with kubeadmin and deploy the pet clinic sample application to the cluster. You can run these steps in your personal AWS account to follow along (Not recommended for production usage). 

1. Build container images and push them to public ECR repo

   ``` shell
   ./mvnw clean install -P buildDocker && ./push-public-ecr.sh
   ```

2. Set up a kubernetes cluster and deploy sample app. Replace `region-name` with the region you choose.

   ``` shell
   cd scripts/k8s/appsignals/ && ./setup-k8s-demo.sh --region=region-name
   ``` 

3. Clean up after you are done with the sample app. Replace `region-name` with the same value that you use in previous step.
   ```
   cd scripts/k8s/appsignals/ && ./setup-k8s-demo.sh --operation=delete --region=region-name


# ECS Demo
The following instructions set up an ECS cluster with all services running in Fargate. You can run these steps in your personal AWS account to follow along (Not recommended for production usage).

1. Build container images and push them to private ECR repo. Replace `region-name` with the region you choose.
   ```shell
   export ACCOUNT=`aws sts get-caller-identity | jq .Account -r`
   export REGION=region-name
   ```
   ``` shell
   ./mvnw clean install -P buildDocker && ./push-ecr.sh
   ```

2. Set up a ECS cluster and deploy sample app. Replace `region-name` with the region you choose.

   ``` shell
   cd scripts/ecs/appsignals && ./setup-ecs-demo.sh --region=region-name
   ``` 

3. Clean up after you are done with the sample app. Replace `region-name` with the same value that you use in previous step.
   ```
   cd scripts/ecs/appsignals/ && ./setup-ecs-demo.sh --operation=delete --region=region-name
   ```
