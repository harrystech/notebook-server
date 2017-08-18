# Remote Notebook Server

This repo houses the necessary Docker and AWS CloudFormation resources to build a containerized Jupyter notebook server
that runs on AWS infrastructure loaded with the content of a team-shared Github repository of notebook code.

## Building and running the image locally

Build the Docker image:

```
docker build -t notebook-server .
```

Run the Docker image locally (without password protection):

```
docker run -it --rm -p 8888:8888 -e GH_TOKEN=[GITHUB TOKEN] -e DB_PASSWORD=[PASSWORD FOR HARRYS_ANALYTICS USER] notebook-server start-notebook.sh --NotebookApp.token=''
```

and navigate to `http://localhost:8888`.


## Bringing it up on AWS

The resources necessary for the notebook server are organized into three stacks:
* A "base" stack of resources shared by other applications, assumed to already exist
* A stack of "persistent" resources that are specific to the notebook server that is created once and left up
* A stack of "instance" resources that are brought up and torn down for each working session

### Prerequisites

The following are assumed to already be in place:

* Base cloudformation stack consisting of a VPC, public/private subnets, and a NAT Gateway with an Elastic IP
* Redshift cluster housing the data warehouse that can be accessed via the Elastic IP of the NAT Gateay
* An ECS repository to host the Docker image remotely

### Persistent resources (bring up once):

1. Make sure that your AWS profile is set to a role that has permissions to upload to S3, push to the ECS repository, and create a CloudFormation stack.
2. Follow commands in the ECS repository on AWS to push the image.
3. Deploy the CloudFormation templates to their appropriate S3 bucket locations:

```
aws s3 cp --recursive cloudformation/infrastructure s3://[BUCKET NAME]/cloudformation/infrastructure
aws s3 cp --recursive cloudformation/services s3://[BUCKET NAME]/cloudformation/services
```

4. Bring up the CloudFormation stack of persistent resources, which include Security Groups and an ECS Cluster with no instances inside the base stack's VPC:

```
aws cloudformation create-stack --role-arn [ROLE ARN] --region us-east-1 \
--profile [AWS PROFILE] --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name notebook-server-dev \
--template-body file://`pwd`/cloudformation/master-persistent-resources.yaml --parameters ParameterKey=BaseStackName,ParameterValue=[BASE STACK NAME] \
ParameterKey=WhitelistCIDR1,ParameterValue=[WHITELIST IP 1] ParameterKey=WhitelistCIDR2,ParameterValue=[WHITELIST IP 2]
```

### Instance resources (on demand):

Prior to a working session, bring up the CloudFormation stack of instance resources, which includes an EC2 instance inside the cluster,
an Application Load Balancer, and a service in the ECS cluster that runs the latest `notebook-server` Docker image.

```
aws cloudformation create-stack --role-arn [ROLE ARN] --region us-east-1 \
--profile [AWS PROFILE] --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --stack-name notebook-server-dev-[PREFIX] \
--template-body file://`pwd`/cloudformation/master-instance-resources.yaml --parameters ParameterKey=Prefix,ParameterValue=[PREFIX] \
ParameterKey=PersistentStackName,ParameterValue=notebook-server-dev ParameterKey=Image,ParameterValue=[ECR IMAGE LOCATION] \
ParameterKey=BaseStackName,ParameterValue=[BASE STACK NAME] ParameterKey=GithubToken,ParameterValue=[GITHUB TOKEN] \
ParameterKey=DBPassword,ParameterValue=[DB PASSWORD] ParameterKey=NotebookPassword,ParameterValue=[NOTEBOOK PASSWORD] \
ParameterKey=InstanceType,ParameterValue=[INSTANCE TYPE]
```

to the `create-stack` command. The default instance type is `t2.2xlarge`.

Locate the DNS of the load balancer and navigate to port 8888 to see the notebook server. From the browser, open
a new Terminal to run your git commands.

Use the `delete-stack` command or the AWS UI to destroy the stack when you're done.
