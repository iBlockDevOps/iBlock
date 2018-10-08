print("I'm going to create Infra for you with Terraform")
print("Please type yes for confirming it....")
import os
os.system('terraform apply -var-file="varP1.tfvars"')