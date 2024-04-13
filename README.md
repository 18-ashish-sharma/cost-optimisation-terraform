# Cost Optimization Terraform Repository

This repository contains Terraform configurations and code for implementing cost optimization measures in AWS infrastructure, specifically focusing on automating the starting and stopping of EC2 and RDS instances.

## Directory Structure

```
📁 start-stop-ec2/
    📁 provisioning/
        📁 common/
            - iam.tf
            - lambda.tf
            - locals.tf
            - rule.tf
            - variables.tf
        📁 dev/
            [Additional environment-specific configurations]
    - requirements.txt
📁 start-stop-rds/
    [Similar directory structure for RDS configurations]
📄 .gitignore
📄 README.md
```

### `start-stop-ec2/`
This directory contains Terraform configurations for managing EC2 instances, including the provisioning of resources and setting up automation using AWS Lambda and EventBridge.

#### `provisioning/`
- **common/**: Contains common Terraform modules and configurations for managing EC2 instances.
- **dev/**: Environment-specific configurations, such as variables or overrides, for development environments.

### `start-stop-rds/`
Similar to `start-stop-ec2/`, this directory contains Terraform configurations for managing RDS instances.

### `.gitignore`
Specifies intentionally untracked files to ignore, such as local development environment settings or sensitive files.

### `README.md`
You're currently reading it! This file provides an overview of the repository, its contents, and instructions on how to use the provided Terraform configurations.

## Usage

1. Clone this repository to your local machine.
2. Navigate to the desired directory (`start-stop-ec2/` or `start-stop-rds/`) containing the Terraform configurations.
3. Customize the configurations as needed, including variables, IAM roles, and event rules.
4. Run `terraform init` to initialize Terraform.
5. Run `terraform plan` to preview the changes Terraform will make.
6. Run `terraform apply` to apply the changes and provision resources in your AWS account.
7. Monitor the AWS Management Console or logs to verify the automation and ensure instances are started and stopped according to the defined schedules.

## Notes
- Ensure you have the necessary permissions and IAM roles configured to execute Terraform operations and manage resources in AWS.
- Review and adjust the event schedules (`cron` expressions) in `rule.tf` to align with your desired start and stop times for instances.
- Update the `variables.tf` file with any additional configuration variables or settings required for your environment.

## Contributing
Contributions to this repository are welcome! If you have improvements, suggestions, or feature requests, feel free to open an issue or submit a pull request.

## License
This repository is licensed under the [MIT License](LICENSE). Feel free to use and modify the code for your projects.