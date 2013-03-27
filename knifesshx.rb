module MyKnifePlugins
      class Sshx < Chef::Knife
		banner "Usage: knife sshx nodename" 

		deps do
  			require 'chef/search/query'
    	end

        def run
        	nodename = name_args[0]
				if nodename == nil 
					ui.fatal("Usage: knife sshx nodename") 
				end

				nodeFound = false
				node_query = Chef::Search::Query.new
				node_query.search('node', "name:#{nodename}") do |node|
					ipaddress = node['ipaddress']
					if node.hasKey("cloud")
						ipaddress = node['cloud']['public_ipv4']
					end

					if !node['current_user'] || node['current_user'].strip.length == 0
							ui.error("Unknown current user for node #{nodename}")
					else
						ui.msg("Connecting to #{ipaddress} as user #{node['current_user']} on port #{node[:ssh][:port]}")
						exec("ssh -p#{node[:ssh][:port]} #{node['current_user']}@#{ipaddress}")
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