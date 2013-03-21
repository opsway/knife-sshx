knife-sshx
==========

Opscode Chef knife sshx plugin 

Login in to node with ssh using the following information:

* login -> node["current_user"]
* ssh_port -> node[:ssh][:port]

Usage:

knife sshx node_name
