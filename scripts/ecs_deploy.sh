#!/usr/bin/env bash
#
# Script that sends a docker image to AWS ECR
#

set -e
set -x

if [ "$#" -lt 2 ]; then
    echo "usage $0 parameter_file (aws-credentials-file)"
    exit 1
fi

if [ "$#" -eq 2 ]; then
    AWS_SHARED_CREDENTIALS_FILE=$2
    export AWS_SHARED_CREDENTIALS_FILE
fi

parameter_file=$1

AWS_REPO=`cat "$parameter_file" | grep "aws_repository" | cut -d'|' -f 2`
AWS_PROFILE=`cat "$parameter_file" | grep "aws_profile" | cut -d'|' -f 2`
CLUSTER=`cat "$parameter_file" | grep "cluster" | cut -d'|' -f 2`
TARGET_GRP_NAME=`cat "$parameter_file" | grep "target_group_name" | cut -d'|' -f 2`
PROTOCOL=`cat "$parameter_file" | grep "target-protocol" | cut -d'|' -f 2`
PORT=`cat "$parameter_file" | grep "target-port" | cut -d'|' -f 2`
VPC_ID=`cat "$parameter_file" | grep "vpc_id" | cut -d'|' -f 2`
TARGET_ID1=`cat "$parameter_file" | grep "target_id1" | cut -d'|' -f 2`
TARGET_ID2=`cat "$parameter_file" | grep "target_id2" | cut -d'|' -f 2`
LISTENER_ARN=`cat "$parameter_file" | grep "listener_arn" | cut -d'|' -f 2`
PRIORITY=`cat "$parameter_file" | grep "priority" | cut -d'|' -f 2`
PATH_PATTERN=`cat "$parameter_file" | grep "path-pattern" | cut -d'|' -f 2`
SERVICE_NAME=`cat "$parameter_file" | grep "service-name" | cut -d'|' -f 2`
TASK_DEFINITION=`cat "$parameter_file" | grep "task-definition" | cut -d'|' -f 2`
LAUNCH_TYPE=`cat "$parameter_file" | grep "launch-type" | cut -d'|' -f 2`
SCHD_STRATEGY=`cat "$parameter_file" | grep "scheduling-strategy" | cut -d'|' -f 2`
DEPLOY_CONTROL=`cat "$parameter_file" | grep "deployment-controller" | cut -d'|' -f 2`
GRACE_PERIOD=`cat "$parameter_file" | grep "health-check-grace-period-seconds" | cut -d'|' -f 2`
LOAD_BALANCER_NAME=`cat "$parameter_file" | grep "load-balancer-name" | cut -d'|' -f 2`
CONTAINER_NAME=`cat "$parameter_file" | grep "container-name" | cut -d'|' -f 2`
CONTAINER_PORT=`cat "$parameter_file" | grep "container-port" | cut -d'|' -f 2`
IMAGE_URI=`cat "$parameter_file" | grep "image" | cut -d'|' -f 2`
MEMORY_RESERVATION=`cat "$parameter_file" | grep "memory-reservation" | cut -d'|' -f 2`
CONTAINER_PROTOCOL=`cat "$parameter_file" | grep "container-protocol" | cut -d'|' -f 2`
LOG_DRIVER=`cat "$parameter_file" | grep "log-driver" | cut -d'|' -f 2`
AWSLOGS_GROUP=`cat "$parameter_file" | grep "awslogs-group" | cut -d'|' -f 2`
AWSLOGS_REGION=`cat "$parameter_file" | grep "awslogs-region" | cut -d'|' -f 2`
AWSLOGS_STREAM_PRE=`cat "$parameter_file" | grep "awslogs-stream-prefix" | cut -d'|' -f 2`
DESIRED_COUNT=`cat "$parameter_file" | grep "desired-count" | cut -d'|' -f 2`
PROFILE_ENV=`cat "$parameter_file" | grep "profile-env" | cut -d'|' -f 2`

if [ -z "$AWS_REPO" ]; then
    echo "*** No AWS ECR respository supplied in ENV aws_repository, exiting... ****"
    exit 1
fi

if [ -z "$AWS_PROFILE" ]; then
    echo "No AWS profile supplied using default"
    aws_profile=default
fi

AWS="/usr/bin/aws --profile $AWS_PROFILE"
DOCKER_LOGIN=$($AWS ecr get-login --no-include-email)
set -x

eval $DOCKER_LOGIN

            CONTAINER_DEFINITION_FILE=$(cat ./scripts/ecs-container-definition.json)
            echo '$CONTAINER_DEFINITION_FILE'
            echo $(eval echo ${CONTAINER_DEFINITION_FILE}) | sed 's/%/"/g' > CONTAINER_DEFINITION.json
            CONTAINER_DEFINITION=$(cat CONTAINER_DEFINITION.json)

export TASK_VERSION=$($AWS ecs register-task-definition --family ${TASK_DEFINITION} --container-definitions "$CONTAINER_DEFINITION" | jq --raw-output '.taskDefinition.revision') 
echo "Registered ECS Task Definition: " $TASK_VERSION 

$AWS ecs list-services --cluster "${CLUSTER}" | sed 's/ //g' > output.dat
service_exist=`cat output.dat | grep "$SERVICE_NAME" | grep e || true`

echo "Value of service_exist ::$service_exist::"



if [ -n "$TASK_VERSION" ]; then 
   if [ -z "$service_exist" ]; then
      export TARGET_GROUP_ARN=$($AWS elbv2 create-target-group --name ${TARGET_GRP_NAME} --protocol ${PROTOCOL} --port ${PORT} --vpc-id ${VPC_ID} | jq --raw-output '.TargetGroups[0].TargetGroupArn')
	    echo "TARGET GROUP ARN - ${TARGET_GROUP_ARN}"
		if [ -n "$TARGET_GROUP_ARN" ]; then
			$AWS elbv2 register-targets --target-group-arn ${TARGET_GROUP_ARN}  --targets Id=${TARGET_ID1} Id=${TARGET_ID2}
			$AWS elbv2 create-rule --listener-arn ${LISTENER_ARN} --priority ${PRIORITY} --conditions Field=path-pattern,Values=${PATH_PATTERN} --actions Type=forward,TargetGroupArn=${TARGET_GROUP_ARN}


            SERVICE_CONTAINER=$(cat ./scripts/create_service.json)
            echo '$SERVICE_CONTAINER'
            echo $(eval echo ${SERVICE_CONTAINER}) | sed 's/%/"/g' > service_container.json
            cat service_container.json
            
            $AWS ecs create-service --service-name ${SERVICE_NAME} --cli-input-json file://service_container.json
		else
			echo "exit: TARGET GROUP NOT Created"
			exit;
		fi	
   else
		echo "Update ECS Cluster: " $CLUSTER 
		echo "Service: " $SERVICE_NAME 
		echo "Task Definition: " $TASK_DEFINITION:$TASK_VERSION 
    
		DEPLOYED_SERVICE=$($AWS ecs update-service --cluster $CLUSTER --service $SERVICE_NAME --task-definition $TASK_DEFINITION:$TASK_VERSION | jq --raw-output '.service.serviceName') 
		echo "Deployment of $DEPLOYED_SERVICE complete" 
  fi
else 
    echo "exit: No task definition" 
    exit; 
fi