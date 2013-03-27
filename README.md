Opscode Chef knife sshx plugin 
==========

Login in to node with ssh using the following information:

* login -> node["current_user"]

You can customize SSH port, if you install on client SSH cookbook: https://github.com/gchef/ssh-cookbook

* ssh_port -> node[:ssh][:port]

Installation
---------------

Copy knifesshx.rb to ${YOUR_CHEF_REPO}/.chef/plugins/knife

Usage
---------------

knife sshx node_name
