#!/bin/bash

# This script configures and deploys JupyterHub automatically
# To use, run the command "bash setup.sh" in the jupyterhub-deploy-teaching folder.
# Prerequisites: Ansible 2.1+ should be installed.

# Sets the variable USERNAME to the current user
USERNAME=$USER

# this pulls the ansible-conda submodule down at the commit specified in
# the repo
git submodule init
git submodule update

# generate ssl keys for nginx
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

# cookie secret
openssl rand -hex 32 > security/cookie_secret

# generates ssh keys create the private key at ~/.ssh/id_rsa and
# public key at ~/.ssh/id_rsa.pub
ssh-keygen >> /dev/null 2>&1 << EOF



EOF
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# create hosts files
HOSTS_LINE="local ansible_ssh_host=127.0.0.1 ansible_ssh_port=22 ansible_ssh_user='$USERNAME'"
cp hosts.example hosts
echo $HOSTS_LINE >> hosts

# this one creates the host file but with the username added to the admin and regular users
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
