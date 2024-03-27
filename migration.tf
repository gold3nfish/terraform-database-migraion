terraform {
  cloud {
    organization = "your_organization_here"
    workspaces {
      name = "migration"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_ecs_cluster" "migration" {
  name = "migration"
  tags = {}
}

resource "aws_ecs_cluster_capacity_providers" "migration" {
  cluster_name          = aws_ecs_cluster.migration.name
  capacity_providers    = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    base              = 1
    weight            = 1
  }
}

resource "aws_ecs_task_definition" "migration_task" {
  family                   = "migration"
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = "your_task_role_arn"
  execution_role_arn       = "your_execution_role_arn"
  container_definitions    = file("task_definition/migration.json")
  tags                     = {}

  lifecycle {
    create_before_destroy = true
  }
}

resource "null_resource" "run_migration" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      # Constants
      LOG_GROUP_NAME="migration"
      LOG_STREAM_NAME_PREFIX="migration/migration"
      AWS_REGION="ap-southeast-1"
      
      function run_ecs_task() {
        aws ecs run-task --cluster migration --task-definition ${aws_ecs_task_definition.migration_task.family}:${aws_ecs_task_definition.migration_task.revision} --launch-type FARGATE --region $AWS_REGION --network-configuration "awsvpcConfiguration={subnets=[${data.tfe_outputs.vpc.nonsensitive_values.id_subnet_1c},${data.tfe_outputs.vpc.nonsensitive_values.id_subnet_1a},${data.tfe_outputs.vpc.nonsensitive_values.id_subnet_1b}],securityGroups=[${data.tfe_outputs.vpc.nonsensitive_values.sg-container}],assignPublicIp=ENABLED}"
      }

      function get_task_status() {
        local task_id=$1
        aws ecs describe-tasks --cluster migration --tasks $task_id --region $AWS_REGION | jq -r '.tasks[0].lastStatus'
      }

      function ensure_log_stream_exists() {
        local log_group=$1
        local log_stream_name=$2
        local exists=$(aws logs describe-log-streams --log-group-name $log_group --log-stream-name-prefix $log_stream_name --query "logStreams[?logStreamName=='$log_stream_name']" --region $AWS_REGION | jq -e .[])
        if [[ -z "$exists" ]]; then
          aws logs create-log-stream --log-group-name $log_group --log-stream-name $log_stream_name --region $AWS_REGION
        fi
      }

      function put_log_message() {
        local log_group=$1
        local log_stream_name=$2
        local message=$3
        aws logs put-log-events --log-group-name $log_group --log-stream-name $log_stream_name --log-events timestamp=$(date +%s)000,message="$message" --region $AWS_REGION
      }

      function check_and_report_logs() {
        local log_group=$1
        local log_stream_name=$2
        local status=$3
        local logs=$(aws logs get-log-events --log-group-name $log_group --log-stream-name $log_stream_name --region $AWS_REGION)
        if [[ "$logs" =~ "Starting Migration" && ! "$logs" =~ "migrated" && "$status" == "DEPROVISIONING" ]]; then
          echo "No new migrations were applied."
          put_log_message $log_group $log_stream_name "No new migrations were applied."
        elif [[ "$logs" =~ "Starting Migration" ]]; then
          echo "Migration started successfully."
          if [[ "$logs" =~ "migrated" ]]; then
            echo "Migration completed successfully."
          fi
        else
          echo "Migration did not start. Check ECS task status or logs for more details."
          exit 1
        fi
      }

      function generate_log_url() {
        local log_group=$1
        local log_stream_name=$2
        echo "https://$AWS_REGION.console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#logEventViewer:group=$log_group;stream=$log_stream_name"
      }
      
      # Main execution starts here
      # Run the ECS task and extract task ID
      TASK_OUTPUT=$(run_ecs_task)
      TASK_ARN=$(echo $TASK_OUTPUT | jq -r '.tasks[0].taskArn')
      TASK_ID=$(echo $TASK_ARN | awk -F'/' '{print $NF}')
      LOG_STREAM_NAME="$LOG_STREAM_NAME_PREFIX/$TASK_ID"
      # Wait for the ECS task to start
      STATUS="RUNNING"
      while [[ "$STATUS" == "RUNNING" || "$STATUS" == "PENDING" ]]; do
        sleep 10
        STATUS=$(get_task_status $TASK_ID)
      done
      ensure_log_stream_exists $LOG_GROUP_NAME $LOG_STREAM_NAME
      echo "Migration started successfully."
      LOG_URL=$(generate_log_url $LOG_GROUP_NAME $LOG_STREAM_NAME)
      echo "Logs can be found at: $LOG_URL"
      put_log_message $LOG_GROUP_NAME $LOG_STREAM_NAME "Starting Migration"
      
      # Fetch logs and checking contents after a small delay
      sleep 10
      check_and_report_logs $LOG_GROUP_NAME $LOG_STREAM_NAME $STATUS
    EOT
  }

  triggers = {
    always_run    = "${timestamp()}"
    task_revision = aws_ecs_task_definition.migration_task.revision
  }
}