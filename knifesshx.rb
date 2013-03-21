module MyKnifePlugins
      class Sshx < Chef::Knife
		banner "Usage: knife sshx nodename" 

		deps do
	      require 'chef/shef/ext'
	    end

        def run
        	Shef::Extensions.extend_context_object(self)

        	nodename = name_args[0]
				if !nodename
					ui.fatal("Provide nodename to connect") 
				end

				nodeFound = false
				search(:node, "name:#{nodename}") do |node|
					ipaddress = node['ipaddress']
					if node.hasKey("cloud")
						ipaddress = node['cloud']['public_ipv4']
					end

					if !node['current_user'] || node['current_user'].strip.length == 0
							ui.error("Unknown current user for node #{nodename}")
					else
						ssh_port = 22
                                                ssh_port = node[:ssh][:port] if node[:ssh]
                                                ui.msg("Connecting to #{ipaddress} as user #{node['current_user']} on port #{ssh_port}")
                                                exec("ssh -p#{ssh_port} #{node['current_user']}@#{ipaddress}")
					end
					nodeFound = true
					break
				end

				if !nodeFound 
					ui.error("Node #{nodename} is not found")
				end
        end 
      end
end
