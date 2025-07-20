cd /var/lib/jenkins/workspace/terraform-infra-builder
terraform apply
cd
ls 
ls lambda_zips/
sudo cp -r /home/ubuntu/lambda_zips /var/lib/jenkins/workspace/terraform-infra-builder/
cd /var/lib/jenkins/workspace/terraform-infra-builder
terraform apply
terraform destroy
cd
nano main.tf
