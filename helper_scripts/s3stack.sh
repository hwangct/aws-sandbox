#!/bin/bash

#################
# Prerequisites 
# 1. AWS CLI is installed
# 2. AWS CLI is configured
# 3. Git SSH key is configured
#################

REPO_ARRAY=( "angular-login" "feh" )
GIT_URL="https://github.com/hwangct"
CENTRAL_BUCKET="central-bucket-1234"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ./buildstack.sh <stack-name> <bootstrapping-stack-name> <fullbuild|update|delete>"
else
  STACK_NAME=$1
  BS_STACK_NAME=$2
  echo "Building stack $STACK_NAME with bootstrapping from $BS_STACK_NAME..."


  ## S3 CLEANUP
  # check for existing s3 artifactory and splunk buckets and delete them
  echo "S3 bucket cleanup..."
  if aws s3api head-bucket --bucket "dean-bucket" 2>/dev/null; then
    echo "deleting bucket"
    aws s3 rb s3://dean-bucket --force
  fi

  ## Clone repositories
  # Clone repos if they do not already exist.  
  # We are assuming that the script is run at the root of the local repos.
  if [ ! -d "AWS-INF" ]; then
    mkdir AWS-INF
  fi
   
  cd AWS-INF
  for i in "${REPO_ARRAY[@]}"
  do
    # if directory does not exist, clone repo
    if [ -d $i ]; then
      echo "$i exists, skipping..."
    else
      git clone $GIT_URL/$i.git
    fi
  done
  cd ..

  ## Create S3 bucket and folder structure
  # if bucket does not exist, create it
  if ! aws s3api head-bucket --bucket $CENTRAL_BUCKET 2>/dev/null; then
    echo "$CENTRAL_BUCKET does not exist, creating..."
    aws s3api create-bucket --bucket $CENTRAL_BUCKET
  fi

  # copy repos 
  #if ! aws s3 ls s3://$CENTRAL_BUCKET/devops-$STACK_NAME-stack 2>/dev/null; then
  aws s3 sync AWS-INF s3://$CENTRAL_BUCKET/devops-$STACK_NAME-stack/AWS-INF/
  aws s3 sync s3://$CENTRAL_BUCKET/devops-$STACK_NAME-stack/AWS-INF/ s3://$CENTRAL_BUCKET/management-$STACK_NAME-stack/AWS-INF/
  
  # copy bootstrapping
  aws s3 sync s3://$CENTRAL_BUCKET/management-$BS_STACK_NAME-stack/bootstrapping/ s3://$CENTRAL_BUCKET/management-$STACK_NAME-stack/bootstrapping/
  aws s3 sync s3://$CENTRAL_BUCKET/devops-$BS_STACK_NAME-stack/bootstrapping/ s3://$CENTRAL_BUCKET/devops-$STACK_NAME-stack/bootstrapping/
fi

