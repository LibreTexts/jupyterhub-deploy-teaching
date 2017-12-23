===============================
Bicycle JupyterHub Provisioning
===============================

The goal of this repository is to provision a single bare-metal JupyterHub
server for teaching small courses at UC Davis. It is a fork of
`jupyterhub-deploy-teaching`_.


What This Does
==============

The provisioning process is broken down into a number of steps (called
"roles"). This deployment achieves the following:

- sets up JupyterHub
- installs a script to launch the JupyterHub
- sets up `supervisor`_ to manage the JupyterHub process
- enables `nbgrader`_ for as many classes as needed via JupyterHub groups and
  services
- installs desired system (apt) packages as well as Python packages (pip and
  conda)
- allows users in the whitelist to log in via Google OAuth
- spawns single-user notebook servers via `systemdspawner`_
- uses nginx as a proxy


Provisioning
============

Prerequisites
-------------

Server requirements:

- Ubuntu server
- SSH access via public key authentication
- python2 installed

Control machine requirements:

- Ansible 2.1+ installed. See `Ansible install docs`_

Configuration
-------------

Configurable options are found in the ``group_vars/jupyterhub_hosts`` file.
There are comments for each option. These options are picked up by Ansible and
used in config templates and tasks during the deployment. For the most part,
you'd want to check the following:

- add yourself and any TAs/graders to the ``jupyter_admin_users`` and
  ``jupyterhub_users`` lists
- set up the ``nbgrader_courses`` list for the courses you're administering
  (see the comments in the config file for instructions)
- update the miniconda version and checksum

Deployment
----------

1. Rename the config file ``group_vars/jupyterhub_hosts.example`` to just
   ``group_vars/jupyterhub_hosts``.

2. Run the following and paste the result into the config file under
   ``proxy_auth_token``::

   openssl rand -hex 32

3. Configure the ``oauth_client_id`` and ``oauth_client_secret`` variables (for
   bicycle, see the values in Google Drive).

4. Put SSL cert and key files in ``security/`` and name them ``ssl.crt`` and
   ``ssl.key`` respectively (for bicycle, see the files in Google Drive).

5. Run the following to generate a `cookie secret`_::

    openssl rand -hex 32 > security/cookie_secret

6. Edit the ``hosts`` file to give the correct IP address and SSH port for the
   server. There are currently two entries: one for testing with Vagrant
   (testing) and one for deploying to a remote server (bicycle).

7. Now you can run the playbook to provision the server. This specifies which
   of the two hosts to deploy to, your username on the host (in case your
   username on the control machine is different), the SSH key file to use, and
   prompts you for your sudo password in order to perform tasks as root::

   ansible-playbook -l bicycle -u <remote-username> --key-file ~/.ssh/<ssh-key>
   --ask-become-pass deploy.yml


Management
==========

While Ansible can be used to continuously update a deployment, the goal here is
to just get a server quickly up and running. It is expected that you'll make
changes (e.g. update the user whitelist) directly on the server, keep the
server up to date with distribution updates, etc. Here are the basics of
managing the JupyterHub once it is up and running.

Supervisor
----------

`supervisor`_ is used to control the JupyterHub process. It has commands like
``supervisorctl restart jupyterhub`` to manage the hub process. Supervisor
itself is configured in ``/etc/supervisor/supervisord.conf``. The processes it
manages (in this case, JupyterHub) are configured in
``/etc/supervisor/conf.d/``.

You can restart the JupyterHub process by running::

    supervisorctl restart jupyterhub

By default, the ``cleanup_on_shutdown`` option is disabled, so this will not
actually kill user notebook servers. If you change the JupyterHub configuration
file, you need to restart the process for changes to take effect (e.g. adding
a user to the whitelist).

The supervisor log is at ``/var/log/supervisor/supervisord.log`` by default.

JupyterHub
----------

The JupyterHub process is started via the
``/etc/jupyterhub/start-jupyterhub.sh`` script. You don't need to call this
script directly (it is called by supervisor).

JupyterHub's configuration file is at ``/etc/jupyterhub/jupyterhub_config.py``.
The template used in this repository is hand-written from scratch, so the
default options are not shown. You can generate a config file with::

    jupyterhub --generate-config

You can do this at any time. The generated file contains tons of options with
their default settings and comments. The main thing you may want to change is
the user whitelist (e.g. for giving students access to the server. This is
specified with ``c.Authentictor.whitelist``. Users can also be added through
the JupyterHub control panel.

nbgrader
--------

Currently, nbgrader doesn't fully support multiple courses. To achieve this,
this deployment creates JupyterHub services for each course. A directory for
all nbgrader courses is located at ``/home/nbgrader/courses`` and
a subdirectory is created for each course. Each course then has its own
nbgrader config file. Administration of each course is done by navigating to
the hub's URL with ``/services/<course-id>`` appended. For example:
``https://huburl.com/services/course1`` would administer ``course1``.


Other Considerations
====================

Backup
------

Not included in this deployment is a backup setup. Here's one way to back up
user home directories. Set up SSH between the JupyterHub server and the backup
server, then use a systemd timer unit to periodically ``rsync`` ``/home``.

Write a systemd timer file to specify when to run the unit.

.. code-block:: ini
   :caption: /etc/systemd/system/rsync-backup.timer

   [Unit]
   Description=rsync /home to a remote backup server daily

   [Timer]
   OnCalendar=daily
   Persistent=true

   [Install]
   WantedBy=timers.target

And a corresponding service that specifies the actual command to run (replace
``<backup-server>`` with the IP of the backup server and
``<remote-backup-path>`` with the location on the backup server you want the
backups to go to.

.. code-block:: ini
   :caption: /etc/systemd/system/rsync-backup.service

   [Unit]
   Description=rsync /home to a remote backup server

   [Service]
   Type=oneshot
   ExecStart=/usr/bin/rsync -a --delete --quiet -e ssh /home <backup-server>:<remote-backup-path>

SSL
---

For our bicycle deployment at UC Davis, SSL was set up by following the
instructions here: https://itcatalog.ucdavis.edu/service/ssl-certificates

OAuth
-----

For our bicycle deployment at UC Davis, Google OAuth was set up via the `Google
Developers Console`_. You create a project in the credentials tab and the setup
is pretty straightforward from there. The current values are stored in Google
Drive, but the project is also available to collaborators.

Testing with Vagrant
--------------------

A Vagrant environment is available for testing in case you would like to
experiment with the deployment. Everything above and in the documentation
holds, except for the following.

The command to run the test environment is ``vagrant up``. If you make changes
and the vagrant box is already initialized/running, you can use ``vagrant
provision``. Once the environment is running, you can determine the IP address
to access by connecting via SSH and running ``ifconfig``::

    vagrant ssh
    ifconfig

The output following ``inet addr:`` lists the IP address you can use to access
the JupyterHub server through your browser.

If the Ansible provisioning fails with an error like "Failed to connect to host
via ssh" you can check the port with ``vagrant ssh-config`` and make sure the
``ansible_ssh_port`` setting in the ``hosts`` flie matches.

OAuth is not enabled for the testing environment. Instead, PAM authentication
is used and the instructor accounts are all given the password ``pass``.



.. _jupyterhub-deploy-teaching: https://github.com/jupyterhub/jupyterhub-deploy-teaching 
.. _Ansible install docs: https://docs.ansible.com/ansible/latest/intro_installation.html
.. _cookie secret: https://jupyterhub.readthedocs.io/en/latest/getting-started/security-basics.html?highlight=cookie_secret#cookie-secret
.. _supervisor: http://supervisord.org/
.. _systemdspawner: https://github.com/jupyterhub/systemdspawner
.. _nbgrader: https://nbgrader.readthedocs.io/en/stable/
.. _Google Developers Console: https://console.developers.google.com
