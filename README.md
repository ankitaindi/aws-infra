Assignment 3

Prerequisites:

An AWS account
1) AWS CLI installed on your system
2) Terraform installed on your system
3) Create an AWS access key:

Login to your AWS console
1) Go to the "IAM" service
2) Click on "Users" and then click on your username
3) Click on the "Security credentials" tab
4) Under "Access keys", click on "Create access key"
5) Save the access key ID and secret access key somewhere safe


Configure AWS CLI:
1) Open a terminal window
2) Type "aws configure --profile dev" and hit enter
3) Enter the access key ID and secret access key when prompted
4) Enter "us-east-1" (or your preferred region) as the default region

Initialize Terraform:
1) In the terminal window, navigate to the project folder if you haven't already
2) Type "terraform init" and hit enter
3) This will download the necessary plugins and modules for your configuration

Plan the deployment:
1) Type "terraform plan" and hit enter
2) This will show you a preview of what Terraform will do when you apply your configuration
3) Review the plan and make sure it looks correct

Apply the configuration:
1) Type "terraform apply" and hit enter
2) This will create the infrastructure defined in your configuration
3) Review the output to ensure that everything was created correctly






