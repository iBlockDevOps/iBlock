print("I'm going to tear down your Infra with Terraform")
import os
os.system('terraform destroy -var-file="varP1.tfvars" -force')