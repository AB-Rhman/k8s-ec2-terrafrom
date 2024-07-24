terraform init
terraform apply -auto-approve
export ANSIBLE_VAULT_PASSWORD_FILE=./pass-vault.txt
ansible-playbook -i inventory.yml playbook.yml