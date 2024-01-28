#!/bin/bash
####################################################
#      Status: WIP - Script has been revised and not yet tested.
# Description: A shell script that is intended to be executed at a regular interval with the help of cron jobs. 
#            | Firstly, the script fetches a copy of the IPv4/IPv6 ranges that are utilized by Cloudflare. 
#            | Secondly, the script calculates and stores the hash of the published text ip range lists. 
#            | Lastly, inbound traffic from those IP ranges are allowed using UFW. 
#            | Additionally, if the script has ran previously, then the script will download the latest text list of IP ranges, 
#            | calculate the hashes, and then compare the checksums with the stored hash from the previous run.
#     Version: 0.1a
#      Author: EspressoKyle (kyle@cloudand.coffee)
#   Tested on: Untested, Previous version functional on Debian 12
####################################################

#---CONFIG-START---#
ipv4_local="<REPLACE_ME>" # example: "/opt/update-cf-ips/ipv4-list.txt"
ipv4_remote="https://www.cloudflare.com/ips-v4/"
ipv4_hash_file="<REPLACE_ME>" # example: "/opt/update-cf-ips/ipv4-hash.txt"
ipv6_local="<REPLACE_ME>" # example: "/opt/update-cf-ips/ipv6-list.txt"
ipv6_remote="https://www.cloudflare.com/ips-v6/"
ipv6_hash_file="<REPLACE_ME>" # example: "/opt/update-cf-ips/ipv6-hash.txt" 
health_ping_url="<REPLACE_ME>" # I use https://hc-ping.com/
ports="<REPLACE ME>" # example: "80,443"
enable_ipv6="<REPLACE_ME>" # 0 = No | 1 = Yes
#----CONFIG-END----#


update_ufw_ipv4 () {
	for ipv4_addr in $(cat $ipv4_local | sed 's/\/32//g' | tr '\n' ' '); do
    for port in $(echo $ports | tr ',' ' '); do
      ufw allow from $ipv4_addr proto tcp to any port $port
	  done
  done
}

update_ufw_ipv6 () {
	for ipv6_addr in $(cat $ipv6_local | sed 's/\/32//g' | tr '\n' ' '); do
    for port in $(echo $ports | tr ',' ' '); do
      ufw allow from $ipv4_addr proto tcp to any port $port
	  done
	done
}

is_configured () {
  cat $0 | grep "\<REPLACE_ME\>"
  if [ "$?" -ne 0 ]; then
    echo "'$0' has not been configured properly.\nexiting.."
    exit 1
}

is_configured

if ! [ -f "$ipv4_hash_file" ]; then
	curl -s "$ipv4_remote" | tee "$ipv4_local"
	if [ "$?" -eq 0 ]; then
		update_ufw_ipv4
  else
    echo "error: unable to fetch contents\nendpoint: $ipv4_remote\nexiting.."
    exit 1
  fi
	curl -s "$ipv4_remote" | sha1sum | tee "$ipv4_hash_file"
else
	curl -s "$ipv4_remote" | sha1sum -c "$ipv4_hash_file"
	if [ "$?" -ne 0 ]; then
		update_ufw_ipv4
		curl -s "$ipv4_remote" | tee "$ipv4_local"
		curl -s "$ipv4_remote" | sha1sum | tee "$ipv4_hash_file"
	fi
fi

if ! [ -f "$ipv6_hash_file" ] && [ "$enable_ipv6" -eq 1 ]; then
  curl -s "$ipv6_remote" | sha1sum -c "$ipv6_hash_file"
	if [ "$?" -eq 0 ]; then
	  update_ufw_ipv6
		curl -s "$ipv6_remote" | tee "$ipv6_local"
		curl -s "$ipv6_remote" | sha1sum | tee "$ipv6_hash_file"
	fi
elif [ -f "$ipv6_hash_file" ] && [ "$enable_ipv6" -eq 1 ]; then
  curl -s "$ipv6_remote" | tee "$ipv6_local"
  if [ "$?" -eq 0 ]; then
		update_ufw_ipv6
	else
    echo "error: unable to fetch contents\nendpoint: $ipv6_remote\nexiting.."
    exit 1
  fi
  curl -s "$ipv6_remote" | sha1sum | tee "$ipv6_hash_file"
fi

curl -s "$health_ping_url"
