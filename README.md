# Migration Tool

This Terraform script is designed to facilitate the migration process of your application using AWS ECS (Elastic Container Service). It automates the setup of ECS clusters, task definitions, and execution of migration tasks.

## Prerequisites

Before running this script, make sure you have the following:

- AWS CLI configured with appropriate permissions.
- AWS IAM roles for ECS task and execution.
- AWS VPC and subnets configured.
- Necessary permissions to create resources in the specified AWS region.

## Setup

1. Clone this repository to your local machine.
2. Navigate to the directory containing the `README.md` file.
3. Ensure you have Terraform installed locally.
4. Modify the `terraform` block in the `main.tf` file to specify your organization name.
5. Set appropriate values for `task_role_arn` and `execution_role_arn` in the `aws_ecs_task_definition` resource block.
6. Replace the `container_definitions` file with your actual task definition JSON.
7. Execute `terraform init` to initialize the working directory.
8. Execute `terraform apply` to create the necessary resources in your AWS account.

## Usage

After the setup, you can execute the migration process using the following steps:

1. Run `terraform apply` to create the ECS cluster and task definition.
2. Once the resources are created, Terraform will automatically trigger the execution of the migration task.
3. Monitor the progress of the migration task in the AWS Management Console or CloudWatch logs.
4. After the migration completes successfully, Terraform will display the log URL where you can find detailed logs.

## Important Notes

- Ensure that your AWS CLI is properly configured with the necessary permissions.
- Review the generated log URL to access detailed logs during and after the migration process.
- Customize the script according to your specific requirements, such as adjusting resource configurations or adding additional logic for migration tasks.

## Explanation

For a detailed explanation of the code and how to use it, refer to the following Medium article: [Terraforming Your Migration: A Beginner's Guide to Infrastructural Magic](https://medium.com/@gold3nfish/terraforming-your-migration-a-beginners-guide-to-infrastructural-magic-892f620369d7).

## Contributors

- [Taweewat Phonksawai](https://github.com/gold3nfish)

## License

This project is licensed under the [MIT License](LICENSE).
