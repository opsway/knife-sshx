module MyKnifePlugins
      class Sshx < Chef::Knife
		banner "Usage: knife sshx nodename \n knife -b sshx nodename <command>\n"

        option :multinode,
          :short => "-m",
          :long => "--no-multinode",
          :description => "Supresses multinode functionality, no AWS connections.",
          :boolean => true,
          :default => true

        option :update_cache,
          :short => "-u",
          :long => "--update-cache",
          :description => "Install bash autocompletion and update node list cache.",
          :boolean => true,
          :default => false

        option :batch_mode,
          :short => "-b",
          :long => "--batch-mode",
          :description => "Executes command on all nodes with given name",
          :boolean => true,
          :default => false

        $cache_file = "#{ENV['HOME']}/.chef/knife-sshx.json"
        $nodelist_cache = "#{ENV['HOME']}/.chef/knife-nodelist-"
        $nc = $nodelist_cache
        $autocompletion_script = "#{ENV['HOME']}/.chef/knife-autocomplete.sh"
        $plugin_path = "#{ENV['HOME']}/.chef/plugins/knife/knifessh.rb"

        $bashrc = "#{ENV['HOME']}/.bashrc"

        $aws_secret = { :region => 'us-east-1'}

        $default_account = nil
        $account = nil
        $ipaddresses = []

		deps do
  			require 'chef/search/query'
  			require 'chef/knife/configure'
            require 'json'
            require 'openssl'
            begin
              $aws_gem = true
              require 'aws-sdk'
            rescue LoadError
              $aws_gem = false
            end
	   	end



        def get_repo_name rep
          chef_name = nil
          if File.exists? "#{rep}/.chef/knife.rb"
            line = `grep chef_server_url #{rep}/.chef/knife.rb`.chomp.chop
          else
            line = `grep chef_server_url ~/.chef/knife.rb`.chomp.chop
          end
            chef_name = line.split("/").last
          chef_name
        end

        def try_all_repos nodename
          return 1 unless ENV['CHEF_REPOS']
          ENV['CHEF_REPOS'].split(":").each do | rep |
            chef_name = get_repo_name rep
            found = system "grep -q #{nodename} #{$nc + chef_name}"
            if found
              if config[:batch_mode]
                ok = system "cd #{rep} && knife sshx -b #{nodename} #{name_args[1]}"
              else
                ok = system "cd #{rep} && knife sshx #{nodename}"
              end
              exit ok
            end
          end
        end

        def autocompletion_cache_update nodename
          cache_file = File.open($nodelist_cache, "w") do |f|
            Chef::Node.list.each do |node|
               f.write node.first + "\n"
            end
          end
          ui.info "Node list cache has been updated."
          unless nodename
            exit 0
          end
        end

        def need_to_copy? a, b
          return false unless File.exist? a
          return true unless File.exist? b
          if File.mtime(a) > File.mtime(b)
            return true
          else
            return false
          end
        end

        def copy_from_repo
          if need_to_copy? ".chef/knife-autocomplete.sh", $autocompletion_script
            system "mkdir -p #{ENV['HOME']}/.chef/"
            ok = system "cp -f .chef/knife-autocomplete.sh #{$autocompletion_script}"
            unless ok
              ui.error "Can't update #{$autocompletion_script}"
            else
              ui.warn "Updated #{$autocompletion_script}"
            end
          end
          if need_to_copy? ".chef/plugins/knife/knifessh.rb", $plugin_path
            system "mkdir -p #{ENV['HOME']}/.chef/plugins/knife/"
            ok = system "cp -f .chef/plugins/knife/knifessh.rb #{$plugin_path}"
            unless ok
              ui.error "Can't update #{$plugin_path}/knifessh.rb"
            else
              ui.warn "Updated #{$plugin_path}/knifessh.rb"
            end
          end
          if need_to_copy? ".chef/knife-sshx.json", "#{ENV['HOME']}/.chef/knife-sshx.json"
            system "mkdir -p #{ENV['HOME']}/.chef/"
            ok = system "cp -f .chef/knife-sshx.json #{ENV['HOME']}/.chef/knife-sshx.json"
            unless ok
              ui.error "Can't update #{ENV['HOME']}/.chef/knife-sshx.json"
            else
              ui.warn "Updated #{ENV['HOME']}/.chef/knife-sshx.json"
            end
          end
        end

        def set_bash_autocompletion nodename
          unless File.exist? $autocompletion_script
            ui.error "#{$autocompletion_script} not found."
            ui.error "Can not enable autocompletion."
            ui.error "Try to run knife sshx -u from root of chef_repo"
            exit 1
          end
          chef_name = Chef::Knife.new.server_url.split("/").last
          $nodelist_cache += chef_name
          warning1 = "Sshx node autocompletion added to your .bashrc\n"
          warning2 = "Run source ~/.bashrc or reload your shell\n"
          if File.exist? $bashrc
            file = IO.read $bashrc
            unless file =~ /#{$autocompletion_script}/
              File.open $bashrc, "a" do |f|
                f.write "\n# Added by knife sshx plugin\n"
                f.write "source #{$autocompletion_script}\n\n"
              end
              ui.warn warning1
              ui.warn warning2
            end
          else
            File.open $bashrc, "w" do |f|
              f.write "\n# Added by knife sshx plugin\n"
              f.write "source #{$autocompletion_script}\n\n"
            end
            ui.warn warning1
            ui.warn warning2
          end
        end

        def do_autocompletion nodename
          if config[:update_cache]
            copy_from_repo
            set_bash_autocompletion nodename
            autocompletion_cache_update nodename
          end
        end

        def chef_get_awskeys nodename
          AWS.memoize do
            item = Chef::DataBagItem.load "aws_keys", "all_in_one"
            item.raw_data['data'].each do | i |
              if i['default']
                $default_account = i
              end
              i['nodes'].each do | node |
                $account = i if nodename.match node
              end
            end
            unless $default_account
              $default_account = item.raw_data['data'].first
            end
            $account = $default_account unless $account

            unless $account
              ui.warn "No AWS credentials found! Multinode mode disabled."
              return false
            end

            $aws_secret[:access_key_id] =$account['access_key']
            $aws_secret[:secret_access_key] = $account['secret_key']
            return true
          end
        end

        def aws_get_instances nodename
            name = cache_get_weird_name nodename
            name = nodename unless name
            $ec2 = AWS::EC2.new($aws_secret)
            list = $ec2.instances.tagged('Name').tagged_values(name)
                                 .filter('instance-state-name', 'running').to_a
        end

        def cache_get_region nodename
          if File.exists?($cache_file)
            cache = JSON.parse( IO.read($cache_file) )
            return cache['regions'][nodename] if cache['regions'][nodename]
          end
          return nil
        end

        def cache_get_weird_name nodename
          if File.exists?($cache_file)
            cache = JSON.parse( IO.read($cache_file) )
            return cache['names'][nodename] if cache['names'][nodename]
          end
          return nil
        end

        def cache_place_region nodename, region
          if File.exists?($cache_file)
            cache = JSON.parse( IO.read($cache_file) )
          else
            cache = Hash.new
            cache['regions'] = Hash.new
            cache['names'] = Hash.new
          end
          cache['regions'][nodename] = region
          File.open($cache_file,"w") do |f|
            f.write(JSON.pretty_generate(cache))
            ui.msg "Region #{region} cached for node #{nodename}"
          end
        end

        def find_region nodename
          name = cache_get_weird_name nodename
          return nil if name == "DO NOT CHECK AWS"
          ui.msg "Trying to find region for #{nodename}"
          regions = AWS::EC2.regions
          regions.each do | region |
            reg = region.name
            ui.msg "Searching in #{reg}"
            $aws_secret[:region] = reg
            instances = aws_get_instances nodename
            if instances.length > 0
              cache_place_region nodename, reg
              return reg
            end
          end
          ui.msg "Region not found!"
          return nil
        end

        def multi_nodes nodename
          unless config[:multinode]
            return nil
          end
          unless $aws_gem
            ui.warn "To enable multinode functionality install aws-sdk gem to chef's ruby"
            ui.warn "On ubuntu : sudo /opt/chef/embedded/bin/gem install aws-sdk"
            return nil
          end

          unless chef_get_awskeys nodename
            return nil
          end

          AWS.memoize do
            region = cache_get_region nodename
            if region
              $aws_secret[:region] = region
              from_cache = true
            else
              region = find_region nodename
              if region
                $aws_secret[:region] = region
                from_cache = false
              else
                return nil
              end
            end
            instances = aws_get_instances nodename
            if instances.length < 1 and from_cache
              region = find_region nodename
              return nil unless region
              instances = aws_get_instances nodename
            end
            if instances.length > 1
              ui.msg "Multiple instances found!"
              n = 0
              instances.each do | i |
                n += 1
                if config[:batch_mode]
                  $ipaddresses << i.ip_address
                else
                  spot = i.spot_instance? ? "spot" : ""
                  ui.msg sprintf("%2d. %s   since %s  ip %-15s  %s", n, i.id.to_s, i.launch_time, i.ip_address, spot)
                end
              end
              if config[:batch_mode]
                return $ipaddresses.first
              end
              answer = ui.ask_question "Choose <1-#{n}>: " , :default => "1"
              if (1..n).include? answer.to_i
                s = instances[answer.to_i-1]
              else
                ui.error "What do you mean by #{answer}?"
                exit 1
              end
              ui.msg "Instance #{s.id} ip #{s.ip_address}"
              return s.ip_address
            else
              if config[:batch_mode]
                $ipaddresses << instances.first.ip_address
                return $ipaddresses.first
              else
                return nil
              end
            end
          end
        end #mulri_nodes

        def do_single_connect ipaddress, nodename, hosting_user, ssh_port
		  ui.msg("Connecting to #{ipaddress} as user #{hosting_user} on port #{ssh_port}")
		  exec("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p#{ssh_port} #{hosting_user}@#{ipaddress}")
        end

        def do_batch_connect nodename, hosting_user, ssh_port, command
            if config[:batch_mode] && name_args.length < 2
              ui.fatal "Batch mode: command argument missing!"
              exit 1
            end
          $ipaddresses.each do |ipaddress|
		    system("ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p#{ssh_port} #{hosting_user}@#{ipaddress} '#{command}'")
          end
        end

        def run
        	nodename = name_args[0]
                do_autocompletion nodename

				if nodename == nil
					ui.fatal("Usage: knife sshx nodename")
				end

				nodeFound = false
				node_query = Chef::Search::Query.new
				node_query.search('node', "name:#{nodename}") do |node|
				    if node.has_key?("hosting_user")
                      hosting_user = node['hosting_user']
                    else
                      hosting_user = "ubuntu"
                    end
					if node.has_key?("openssh")
				      ssh_port = node[:openssh][:server][:port]
                    elsif node.has_key?("ssh")
				      ssh_port = node[:ssh][:port]
                    else
                      ssh_port = 22
                    end
					ipaddress = node['ipaddress']
					if node.has_key?("cloud")
                      if node['cloud']['public_ipv4'] =~ /\d+\.\d+\.\d+\.\d+/
						ipaddress = node['cloud']['public_ipv4']
                        if node['cloud'].has_key?("ssh_port")
                          ssh_port = node['cloud']['ssh_port']
                        end
                      end
					end
                    multi = nil
                    if node.has_key?("at_amazon")
                      if node['at_amazon']
                        multi = multi_nodes nodename
                      end
                    else
                      multi = multi_nodes nodename
                    end
                    if multi
                      ipaddress = multi
                    end
					if hosting_user.length == 0
							ui.error("Unknown hosting user for node #{nodename}")
					else
                      unless config[:batch_mode]
                        do_single_connect ipaddress, nodename, hosting_user, ssh_port
                      else
                        command = name_args[1]
                        if command
                          do_batch_connect nodename, hosting_user, ssh_port, command
                        end
                      end
					end
					nodeFound = true
					break
				end

				if !nodeFound
                    try_all_repos nodename
					ui.error("Node #{nodename} is not found")
				end
        end
      end
end

