#!/usr/bin/env bash
set -e
set -u

show_usage_and_exit() {
  echo "Usage: `basename $0` ENVIRONMENT"
  echo "ENVIRONMENT should be 'development' or 'production' and correspond to the AWS account to which you want to deploy."
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

if [ $# -lt 1 ]; then
  show_usage_and_exit 1
else
  environment="$1"
fi

source "config/config_$environment.sh"

tempfile=$(mktemp /tmp/persistent_resources_packaged_template.XXXXXX) || exit 1
trap "rm $tempfile" EXIT

MASTER_TEMPLATE=cloudformation/master-persistent-resources.yaml

set -x

aws --profile $AWS_PROFILE cloudformation package \
    --template-file $MASTER_TEMPLATE \
    --s3-bucket $S3_BUCKET \
    --s3-prefix $S3_PERSISTENT_PREFIX \
    --output-template-file $tempfile

aws --profile $AWS_PROFILE cloudformation create-stack --region us-east-1 \
    --disable-rollback --capabilities CAPABILITY_NAMED_IAM --stack-name "$PERSISTENT_STACK_NAME" \
    --template-body "file://$tempfile" --parameters ParameterKey=BaseStackName,ParameterValue="$BASE_STACK_NAME" \
    ParameterKey=WhitelistCIDR1,ParameterValue="$WHITELIST_CIDR1" ParameterKey=WhitelistCIDR2,ParameterValue="$WHITELIST_CIDR2"
