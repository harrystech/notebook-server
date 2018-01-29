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
* One or more config files in the `/config` directory named `config_<ENVIRONMENT>.sh` that set the variables specified in `config/config_<environment>.sh.template`

### Persistent resources (bring up once):

1. Make sure that your AWS profile is set to a role that has permissions to upload to S3, push to the ECS repository, and create a CloudFormation stack.
2. Follow commands in the ECS repository on AWS to push the image.
3. Package and deploy the CloudFormation stack of persistent resources, which include Security Groups and an ECS Cluster with no instances inside the base stack's VPC:

```
bash deploy_persistent_stack.sh <ENVIRONMENT>
```

### Instance resources (on demand):

Prior to a working session, bring up the CloudFormation stack of instance resources, which includes an EC2 instance inside the cluster,
an Application Load Balancer, and a service in the ECS cluster that runs the latest `notebook-server` Docker image.

```
bash deploy_instance_stack.sh [-i INSTANCE_TYPE] <ENVIRONMENT> [<USER>]
```

Locate the DNS of the load balancer and navigate to port 8888 to see the notebook server. From the browser, open
a new Terminal to run your git commands.

Use the `delete-stack` command or the AWS UI to destroy the stack when you're done.
