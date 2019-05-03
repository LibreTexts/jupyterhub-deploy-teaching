#!/bin/bash

# This script configures and deploys JupyterHub automatically
# To use, run the command "bash setup.sh" in the jupyterhub-deploy-teaching folder.
# Prerequisites: Ansible 2.1+ should be installed.

# Sets the variable USERNAME to the current user
USERNAME=$USER

# get ansible-conda down if it is not already
git submodule init
git submodule update

# ssl stuff for nginx
openssl genrsa -out security/ssl.key 1024 > /dev/null 2>&1
openssl req -new -key security/ssl.key -out security/ssl.csr > /dev/null 2>&1 \
<< EOF
US
CA
Davis
Libretexts

${USERNAME}



EOF
openssl x509 -req -in security/ssl.csr -signkey security/ssl.key \
	-out security/ssl.crt

# Generates a cookie secret and saves it to a file under the security directory
openssl rand -hex 32 > security/cookie_secret

# Generate ssh keys
ssh-keygen >> /dev/null 2>&1 << EOF



EOF
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Create hosts files
# This specifies the IP address and SSH port of the server. The server name is set to local
# the username is set to the current user.
HOSTS_LINE="local ansible_ssh_host=127.0.0.1 ansible_ssh_port=22 ansible_ssh_user='$USERNAME'"
cp hosts.example hosts
echo $HOSTS_LINE >> hosts

# Adds the current user as an admin and regular user in the jupyter_hosts file
sed -e '/jupyterhub_users\:/a\' -e "  - $USERNAME" group_vars/jupyterhub_hosts.example\
        | sed -e '/jupyterhub_admin_users\:/a\' -e "  - $USERNAME"\
        > group_vars/jupyterhub_hosts

# install ansible
sudo apt install -y ansible

# install ssh
sudo apt install -y ssh

# finally run the playbook
ansible-playbook -l local -u $USERNAME --ask-become-pass deploy.yml

# adds /opt/conda/bin to PATH so the newly installed commands will work
echo "PATH=/opt/conda/bin:\$PATH" >> ~/.bashrc
source ~/.bashrc
