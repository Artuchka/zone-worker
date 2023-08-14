#!/bin/bash

# --- CREDENTIALS ---
username=$ZONE_USERNAME
host=$ZONE_HOST

# --- PATHS ---
mcptt_local_path="/home/artuchka/UserFiles/proga/mcptt-ui"
mcptt_local_build_path="$mcptt_local_path/packages/app/mcptt/build/distribution/"
mcptt_remote_build_path="/opt/protei/Protei-MCPTT"

nginx_template_proxy="proxy_templates/mcptt_BRANCH_proxy.conf"
nginx_template_location="proxy_templates/locations_mcptt_BRANCH.conf"

nginx_remote_config_path="/etc/nginx"
nginx_remote_config_file_path="$nginx_remote_config_path/nginx.conf"
nginx_remote_mcptt_config_path="$nginx_remote_config_path/modules/mcptt"

# --- LOG FUNCTIONS ---
echo_with_color() {
  echo -e "\e[1;$1m$2\e[0m"
}

echo_red() {
  echo_with_color "31" "$1"
}

echo_green() {
  echo_with_color "32" "$1"
}

echo_cyan() {
  echo_with_color "36" "$1"
}

# --- COMMON FUNCTIONS ---
restart_nginx () {
  echo_green "Nginx restarting..."
  ssh $username@$host "sudo nginx -t && sudo systemctl restart nginx"
  echo_green "Nginx restarted successfully."
}


# --- WORKER OPTIONS ---
make_build() {
  read -p "Enter branch index: " branch_index

  {
    cd $mcptt_local_path && git checkout -q "MCPTT-$branch_index"
  } || {
    echo_red "No branch MCPTT-$branch_index"
    exit 1
  }

  echo_cyan "building from $mcptt_local_path on branch $(cd $mcptt_local_path && git branch --show-current)"
  sh $mcptt_local_path/scripts/build.sh
}

make_help() {
  echo "
  Hi! that's a shell script for automation of publishing build to remote server 
    
  'build'
     = just run \`./scripts/build.sh\` script

  'publish'
     = take packages/app/mcptt/build/distribution/
     and send it to opt/protei/Protei-MCPTT/WEB-TO-<branch_index> on remote server 

  'new'
     = create nginx config files for new port
    link these files to main nginx config
    does not publish builds to server 

  'delete'
     = removes nginx config files for old port
    unlinks these files from main nginx config
    removes published builds from /WEB-TO-<branch_index>

  'help'
     show help
  "
}

make_publish() {
  read -p "Enter branch index: " branch_index

  { 
    cd $mcptt_local_path && git checkout -q "MCPTT-$branch_index"
  } || {
    echo_red "No branch MCPTT-$branch_index"
    exit 1
  }
  echo_cyan "On branch $(cd $mcptt_local_path && git branch --show-current)"

  version=$(cat "$mcptt_local_build_path/version.json" | grep "version")
  echo_cyan "$(echo $version | sed 's/, *$//g')"

  read -p "Continue? [y/n] " should_continue
  if [ "$should_continue" != y ]; then
    echo_red "Exiting script"
    exit 1
  fi

  {
    scp -r\
      ${mcptt_local_build_path}\
      ${username}@${host}:${mcptt_remote_build_path}/WEB-TO-${branch_index}
  } || {
    echo_red "Could not establish connection"
    exit 1
  }
  
  {
    ssh $username@$host "cp -f\
      $mcptt_remote_build_path/WEB-TO/configuration.json\
      $mcptt_remote_build_path/WEB-TO-${branch_index}/configuration.json"
  } || {
    echo_red "Could not establish connection"
    exit 1
  }
  echo_green "Using server-oriented configuration.json"
  
  restart_nginx;
}

make_new_port() {
  read -p "Enter port: " port
  read -p "Enter branch index: " branch_index

  echo_cyan "Port is ${port}"
  echo_cyan "Branch index is ${branch_index}"

  port_pid=$(ssh $username@$host "fuser -v -n tcp $port")
  if [ "$port_pid" != "" ]; then
    echo_red "Port $port is already taken by other process"
    echo_red $port_pid
    exit 1
  fi

  read -p "Continue? [y/n] " should_continue

  if [ "$should_continue" != y ]; then
    echo_red "Exiting script"
    exit 1
  fi

  mcptt_BRANCH_proxy=$(sed 's,''<port_here>,'"$port"',' $nginx_template_proxy | sed 's,''<branch_here>,'"$branch_index"',')
  locations_mcptt_BRANCH=$(sed 's,''<branch_here>,'"$branch_index"',' "$nginx_template_location")

  > mcptt_${branch_index}_proxy.conf
  > locations_mcptt_${branch_index}.conf

  echo -e "$mcptt_BRANCH_proxy" >> mcptt_${branch_index}_proxy.conf
  echo -e "$locations_mcptt_BRANCH" >> locations_mcptt_${branch_index}.conf

  anchor_to_line="include modules/mcptt/mcptt_proxy.conf;"
  new_line="include modules/mcptt/mcptt_${branch_index}_proxy.conf;"
  replace_with_line=`echo -e "$anchor_to_line\n$new_line"`
  
  scp -r\
    mcptt_${branch_index}_proxy.conf\
    ${username}@${host}:${nginx_remote_mcptt_config_path}

  scp -r\
    locations_mcptt_${branch_index}.conf\
    ${username}@${host}:${nginx_remote_mcptt_config_path}

  ssh $username@$host\
    "sed -i 's|$(echo $anchor_to_line)|$(echo -e $replace_with_line)|g' $nginx_remote_config_file_path"
  echo_green "Nginx config updated for port=$port"

  restart_nginx
}

delete_published() {
  read -p "Enter port: " port
  read -p "Enter branch index: " branch_index

  echo_red "Port is ${port}"
  echo_red "Branch index is ${branch_index}"

  read -p "Continue? [y/n] " should_continue

  if [ "$should_continue" != y ]; then
    echo_red "Exiting script"
    exit 1
  fi

  rm mcptt_${branch_index}_proxy.conf
  rm locations_mcptt_${branch_index}.conf

  anchor_to_line="include modules/mcptt/mcptt_${branch_index}_proxy.conf;"
  replace_with_line=""

  ssh $username@$host\
    "rm $nginx_remote_mcptt_config_path/mcptt_${branch_index}_proxy.conf"

  ssh $username@$host\
    "rm $nginx_remote_mcptt_config_path/locations_mcptt_${branch_index}.conf"

  ssh $username@$host\
    "sed -i 's|$(echo $anchor_to_line)|$(echo -e $replace_with_line)|g' $nginx_remote_config_file_path"
  echo_green "Nginx config updated by removing configs for port=$port"

  {
    ssh $username@$host "rm -r $mcptt_remote_build_path/WEB-TO-${branch_index}"
  } || {
    echo_red "Could not establish connection"
    exit 1
  }
  echo_green "Build folder removed for branch=$branch_index"

  restart_nginx
}

for args in "$@"; do
shift
	case "$args" in
		"build") make_build ;;
		"publish") make_publish ;;
		"new") make_new_port ;;
		"delete") delete_published ;;
		"help") make_help ;;
	esac
done

