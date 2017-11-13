#!/usr/bin/env bash
set -e
set -u

show_usage_and_exit() {
  echo "Usage: `basename $0` ENVIRONMENT [USER]"
  echo "ENVIRONMENT should be 'development' or 'production' and correspond to the AWS account to which you want to deploy."
  echo "USER is the suffix used in naming stack resources and defaults to $USER"
  exit ${1-0}
}

while getopts ":h" opt; do
  case $opt in
    h)
      show_usage_and_exit
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Shift past any options present
shift $((OPTIND-1))

if [ $# -lt 1 ] ; then
  show_usage_and_exit 1
else
  environment="$1"
fi

# Set user if passed in
user="${2-$USER}"

source "config/config_$environment.sh"

tempfile=$(mktemp /tmp/instance_resources_packaged_template.XXXXXX) || exit 1
trap "rm $tempfile" EXIT

MASTER_TEMPLATE=cloudformation/master-instance-resources.yaml

set -x

aws --profile $AWS_PROFILE cloudformation package \
    --template-file $MASTER_TEMPLATE \
    --s3-bucket $S3_BUCKET \
    --s3-prefix $S3_INSTANCE_PREFIX \
    --output-template-file $tempfile

aws --profile $AWS_PROFILE cloudformation create-stack --region us-east-1 --disable-rollback --capabilities CAPABILITY_NAMED_IAM \
    --stack-name "$INSTANCE_STACK_NAME_PREFIX-$user" --template-body "file://$tempfile" \
    --parameters ParameterKey=Prefix,ParameterValue="$user" ParameterKey=PersistentStackName,ParameterValue="$PERSISTENT_STACK_NAME" \
    ParameterKey=Image,ParameterValue="$IMAGE_LOCATION" ParameterKey=BaseStackName,ParameterValue="$BASE_STACK_NAME" \
    ParameterKey=GithubToken,ParameterValue="$GITHUB_TOKEN" ParameterKey=DBPassword,ParameterValue="$DB_PASSWORD" \
    ParameterKey=NotebookPassword,ParameterValue="$NOTEBOOK_PASSWORD"
