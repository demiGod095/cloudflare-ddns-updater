#!/bin/bash

auth_key=""                                        # Top right corner, "My profile" > "API Tokens" > "Create Token" > "Edit zone DNS" > "Use template"
zone_identifier=""                                 # Can be found in the "Overview" tab of your domain
record_name=""                                     # Which record you want to be synced
proxy=true                                         # Set the proxy to true or false

###########################################
## Check if we have an public IP
###########################################
ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com/)
if [ "${ip}" == "" ]; then
  message="No public IP found."
  >&2 echo -e "${message}" >> ~/log
  exit 1
fi

###########################################
## Seek for the A record
###########################################
echo " Check Initiated" >> ~/log
record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" \
        -H "Authorization: Bearer $auth_key" \
        -H "Content-Type: application/json")

###########################################
## Check if the domaine has an A record
###########################################
if [[ $record == *"\"count\":0"* ]]; then
  message=" Record does not exist, perhaps create one first? (${ip} for ${record_name})"
  >&2 echo -e "${message}" >> ~/log
  exit 1
fi

###########################################
## Get the existing IP
###########################################
old_ip=$(echo "$record" | grep -Po '(?<="content":")[^"]*' | head -1)
# Compare if they're the same
if [[ $ip == $old_ip ]]; then
  message=" IP ($ip) for ${record_name} has not changed."
  echo "${message}" >> ~/log
  exit 0
fi

###########################################
## Set the record identifier from result
###########################################
record_identifier=$(echo "$record" | grep -Po '(?<="id":")[^"]*' | head -1)

###########################################
## Change the IP@Cloudflare using the API
###########################################
update=$(curl -s -L -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
                     -H "Authorization: Bearer $auth_key" \
                     -H "Content-Type: application/json" \
              --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"proxied\":${proxy},\"name\":\"$record_name\",\"content\":\"$ip\"}")

###########################################
## Report the status
###########################################
case "$update" in
*"\"success\":false"*)
  message="$ip $record_name DDNS failed for $record_identifier ($ip). DUMPING RESULTS:\n$update"
  >&2 echo -e "${message}" >> ~/log
  exit 1;;
*)
  message="$ip $record_name DDNS updated."
  echo "${message}" >> ~/log
  exit 0;;
esac
