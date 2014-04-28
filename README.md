Opscode Chef knife sshx plugin 
==========

Login in to node with ssh using the following information:

* login -> node["current_user"]

You can customize SSH port, if you install on client SSH cookbook: https://github.com/gchef/ssh-cookbook

* ssh_port -> node[:ssh][:port]


INSTALLATION
------------
1) Install aws-sdk gem. <br>
If you  use omnibus chef installer use:
sudo /opt/chef/embedded/bin/gem install aws-sdk --no-rdoc –no-ri
If you installed chef as gem
gem install aws-sdk --no-rdoc –no-ri
<br>2) Change dir to chef repository and run
knife sshx -u
This command will setup bash autocompletion and update servers list for this repository. Also it will copy regions cache, this cache is autofilling, but it also contains list of exceptions for non amazon projects. 
<br>3) If you use multiple chef repositories add following variable to .bashrc or other startup sctipt:
<br>CHEF_REPOS=~/workspace/chef_repo1:~/workspace/chef_repo2 ; export CHEF_REPOS
This will allow to connect to servers from any repositiry without changing current directory.
<br> 4) Restart your shell.

BENEFITS

--------
1) You can choose to which instance to connect if they use the same aws name:

<br>Like that:

<br>knife sshx costumebox-live-node
<br>Multiple instances found!
<br>1. i-cca165f0   since 2013-08-06 10:11:16 UTC  ip 54.253.26.66
<br>2. i-6ca71550   since 2013-08-07 19:06:05 UTC  ip 54.253.66.83
<br>3. i-6ea71552   since 2013-08-07 19:06:05 UTC  ip 54.253.44.185
<br>4. i-6fa71553   since 2013-08-07 19:06:05 UTC  ip 54.252.44.245
<br>Choose <1-4>: [1] 2
<br>Instance i-6ca71550 ip 54.253.66.83
<br>Connecting to 54.253.66.83 as user ubuntu on port 22

<br>2) Fast autocompletion. Just do not forget to refresh servers list with -u key.

<br>3) No need to change directory to connect to server from other repository.

4) You can run command on all aws instances with the same node name.

USAGE
-----
knife sshx [options] [nodename]

<br>Available options:

<br> -m      completely disables aws lookups, needed in case of plugin's malfunction.
<br> -u      update node list for current chef repository, update plugin, node list and regions's cache if running from    <br>             repository root, with this options nodename is optional.
<br> -b      batche mode,  run command on all nodes with given name. 	
