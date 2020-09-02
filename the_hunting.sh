#!/bin/bash
#===============================================================================
#
#          FILE: the_hunting.sh
#
#         USAGE: ./the_hunting.sh
#
#   DESCRIPTION:
#          borrowed some stuff and idea of automated platform from
#          lazyrecon https://github.com/nahamsec/lazyrecon. Got idea to automate
#          my workflow from countless bb folk, most notibly and recently from
#          @hakluke on his "how to crush bug bounties in your first 12 months"
#          which you can find here https://youtu.be/u_4FUs2vlKg?t=20009
#          thanks everyone
#
#       OPTIONS: ---
#  REQUIREMENTS: amass, gobuster, subjack, aquatone, httprobe, dirb, nmap,
#                nuclei, and parallel on ubuntu 20.04 or axiom droplet
#
#          BUGS:
#         NOTES: v0.2.1
#        AUTHOR: @incredincomp
#  ORGANIZATION:
#       CREATED: 08/27/2020 16:55:54
#      REVISION: 08/31/2020 00:29:00
#     LICENSING: the_hunting Copyright (C) 2020  @incredincomp
#                This program comes with ABSOLUTELY NO WARRANTY;
#                for details, type `./the_hunting.sh -l'.
#                This is free software, and you are welcome to redistribute
#                it under certain conditions;
#                for details, type `./the_hunting.sh -l'.
#===============================================================================
clear
set -o nounset                 # Treat unset variables as an error
set -e
#set -xv                       # Uncomment to print script in console for debug

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
reset=$(tput sgr0)

alias httprobe="~/go/bin/httprobe"
# borrowed some stuff and general idea of automated platform from lazyrecon
# https://github.com/nahamsec/lazyrecon
auquatoneThreads=8
subdomainThreads=15
subjackThreads=15
httprobeThreads=50
chromiumPath=/snap/bin/chromium

if [ -s ./slack_url.txt ]
then
  slack_url=$(<slack_url.txt)
else
  slack_url=""
fi

target=""
subreport=""
usage() { logo; echo -e "Usage: ./the_hunting.sh -d <target domain> [-e] [excluded.domain.com,other.domain.com]\nOptions:\n  -e\t-\tspecify excluded subdomains\n " 1>&2; exit 1; }

while getopts ":d:e:l" o; do
    case "${o}" in
        d)
            target="$OPTARG"
            ;;
        e)
            set -f
            IFS=","
            excluded+=($OPTARG)
            unset IFS
            ;;
        l)
            less ./LICENSE
            exit 1
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND - 1))

if [ -z "$target" ] && [ -z ${subreport[*]} ]; then
   usage; exit 1;
fi

excludedomains(){
  if [ -z "$excluded" ]; then
    echo "No domains have been excluded."
  else
    echo "Excluding domains (if you set them with -e)..."
    IFS=$'\n'
    # prints the $excluded array to excluded.txt with newlines
    printf "%s\n" "${excluded[*]}" > ./"$target"/excluded.txt
    # this form of grep takes two files, reads the input from the first file, finds in the second file and removes
    grep -vFf ./"$target"/excluded.txt ./"$target"/alldomains.txt > ./"$target"/alldomains2.txt
    mv ./"$target"/alldomains2.txt ./"$target"/alldomains.txt
    #rm ./$domain/$foldername/excluded.txt # uncomment to remove excluded.txt, I left for testing purposes
    echo "${green}Subdomains that have been excluded from discovery:${reset}"
    printf "%s\n" "${excluded[@]}"
    unset IFS
  fi
}
# parents
run_amass(){
  echo "${yellow}Running Amass enum...${reset}"
  amass enum -norecursive --passive -dir ./targets/"$target"/"$foldername"/subdomain_enum/amass/ -oA ./targets/"$target"/"$foldername"/subdomain_enum/amass/amass-"$todate" -d https://"$target"
  cat ./targets/"$target"/"$foldername"/subdomain_enum/amass/amass-"$todate".txt >> ./targets/"$target"/"$foldername"/alldomains.txt
  echo "${green}Amass enum finished.${reset}"
}

#gobuster vhost broken
run_gobuster_vhost(){
  echo "${yellow}Running Gobuster vhost...${reset}"
  gobuster vhost -u "$target" -w ./wordlists/subdomains-top-110000.txt -a "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:80.0) Gecko/20100101 Firefox/80.0" -k -o ./targets/"$target"/"$foldername"/subdomain_enum/gobuster/gobuster_vhost-"$todate".txt
  cat ./targets/"$target"/"$foldername"/subdomain_enum/gobuster/gobuster_vhost-"$todate".txt >> ./targets/"$target"/"$foldername"/alldomains.txt
  echo "${green}Gobuster vhost finished.${reset}"
}

run_gobuster_dns(){
  echo "${yellow}Running Gobuster dns...${reset}"
  gobuster dns -d "$target" -w ./wordlists/subdomains-top-110000.txt -z -q -t "$subdomainThreads" -o ./targets/"$target"/"$foldername"/subdomain_enum/gobuster/gobuster_dns-"$todate".txt
  cat ./targets/"$target"/"$foldername"/subdomain_enum/gobuster/gobuster_dns-"$todate".txt | awk -F ' ' '{print $2}' >> ./targets/"$target"/"$foldername"/alldomains.txt
  echo "${green}Gobuster dns finished.${reset}"
}

run_subjack(){
  echo "${yellow}Running subjack...${reset}"
  $HOME/go/bin/subjack -a -w ./targets/"$target"/"$foldername"/alldomains.txt -ssl -t "$subjackThreads" -m -timeout 15 -c "$HOME/go/src/github.com/haccer/subjack/fingerprints.json" -o ./targets/"$target"/"$foldername"/subdomain-takeover-results.json -v
  echo "${green}subjack finished.${reset}"
}

run_httprobe(){
  echo "${yellow}Running httprobe...${reset}"
  cat ./targets/"$target"/"$foldername"/uniq-subdomains.txt | httprobe -c "$httprobeThreads" >> ./targets/"$target"/"$foldername"/responsive-domains-80-443.txt
  echo "${green}httprobe finished.${reset}"
}

run_aqua(){
  echo "${yellow}Running Aquatone...${reset}"
  cat ./targets/"$target"/"$foldername"/responsive-domains-80-443.txt | aquatone -chrome-path $chromiumPath -out ./targets/"$target"/"$foldername"/aqua/aqua_out -threads $auquatoneThreads -silent -http-timeout 6000
  echo "${green}Aquatone finished...${reset}"
}

run_gobuster_dir(){
  echo "${yellow}Running Gobuster dir...${reset}"
  read_direct_wordlist | parallel --results ./targets/"$target"/"$foldername"/directory_fuzzing/gobuster/ gobuster dir -z -q -u {} -w ./wordlists/directory-list.txt -f -k -e -r -a "Mozilla/5.0 \(X11\; Ubuntu\; Linux x86_64\; rv\:80.0\) Gecko/20100101 Firefox/80.0"
  cat ./targets/"$target"/"$foldername"/directory_fuzzing/gobuster/1/"$target"/stdout | awk -F ' ' '{print $1}' >> ./targets/"$target"/"$foldername"/live_paths.txt
  echo "${green}Gobuster dir finished...${reset}"
}

run_dirb(){
  true
}

run_nuclei(){
  echo "${yellow}Running Nuclei stock cve templates scan...${reset}"
  nuclei -v -pbar -json -l ./targets/"$target"/"$foldername"/responsive-domains-80-443.txt -t ./nuclei-templates/cves/ -o ./targets/"$target"/"$foldername"/scanning/nuclei/nuclei-cve-results.json
  nuclei -v -pbar -json -l ./targets/"$target"/"$foldername"/responsive-domains-80-443.txt -t ./nuclei-templates/vulnerabilties/ -o ./targets/"$target"/"$foldername"/scanning/nuclei/nuclei-vulnerabilties-results.json
  nuclei -v -pbar -json -l ./targets/"$target"/"$foldername"/responsive-domains-80-443.txt -t ./nuclei-templates/security-misconfigurations/ -o ./targets/"$target"/"$foldername"/scanning/nuclei/nuclei-security-misconfigurations-results.json
  echo "${green}Nuclei stock cve templates scan finished...${reset}"
}

run_zap(){
  echo "${yellow}Running zap scan...${reset}"
  echo "${red} Just kidding! Working on it though.${reset}"
  echo "${green}zap scan finished...${reset}"
}

run_nmap(){
  true
}

notify(){
  if [ -z "$slack_url" ]; then
    echo "${red}Notifications not set up. Add your slack url to ./slack_url.txt${reset}"
  else
    echo "${yellow}Notification being generated and sent...${reset}"
    num_of_subd=$(< ./targets/"$target"/"$foldername"/responsive-domains-80-443.txt wc -l)
    data1=''{\"text\":\"Your\ scan\ of\ "'"$target"'"\ is\ complete!\ \`the\_hunting.sh\`\ found\ "'"$num_of_subd"'"\ responsive\ subdomains\ to\ scan.\"}''
    curl -X POST -H 'Content-type: application/json' --data "$data1" https://hooks.slack.com/services/"$slack_url"
    echo "${green}Notification sent!${reset}"
  fi
}

read_direct_wordlist(){
  cat ./targets/"$target"/"$foldername"/responsive-domains-80-443.txt
}

uniq_subdomains(){
  uniq -u ./targets/"$target"/"$foldername"/alldomains.txt > ./targets/"$target"/"$foldername"/uniq-subdomains.txt
}

# children
subdomain_enum(){
#Amass https://github.com/OWASP/Amass
  run_amass
#Gobuster trying to make them run at same time
  #run_gobuster_vhost
  run_gobuster_dns
  uniq_subdomains
}

sub_takeover(){
  run_subjack
}

target_valid(){
  run_httprobe
}

webapp_valid(){
  run_aqua
}
fuzz_em(){
  run_gobuster_dir
  run_dirb
}

webapp_scan(){
  run_nuclei
}

port_scan(){
  run_nmap
}

# main func's
recon(){
  subdomain_enum
  sub_takeover
#  excludedomains
  webapp_valid
  target_valid
}

scanning(){
  port_scan
  fuzz_em
  webapp_scan
}
# graphic opening stuff
logo(){
  base64 -d <<<"4paI4paI4paI4paI4paI4paI4paI4paI4pWX4paI4paI4pWXICDilojilojilZfilojilojilojilojilojilojilojilZcgICAgICAgIOKWiOKWiOKVlyAg4paI4paI4pWX4paI4paI4pWXICAg4paI4paI4pWX4paI4paI4paI4pWXICAg4paI4paI4pWX4paI4paI4paI4paI4paI4paI4paI4paI4pWX4paI4paI4pWX4paI4paI4paI4pWXICAg4paI4paI4pWXIOKWiOKWiOKWiOKWiOKWiOKWiOKVlyAgICDilojilojilojilojilojilojilojilZfilojilojilZcgIOKWiOKWiOKVlwrilZrilZDilZDilojilojilZTilZDilZDilZ3ilojilojilZEgIOKWiOKWiOKVkeKWiOKWiOKVlOKVkOKVkOKVkOKVkOKVnSAgICAgICAg4paI4paI4pWRICDilojilojilZHilojilojilZEgICDilojilojilZHilojilojilojilojilZcgIOKWiOKWiOKVkeKVmuKVkOKVkOKWiOKWiOKVlOKVkOKVkOKVneKWiOKWiOKVkeKWiOKWiOKWiOKWiOKVlyAg4paI4paI4pWR4paI4paI4pWU4pWQ4pWQ4pWQ4pWQ4pWdICAgIOKWiOKWiOKVlOKVkOKVkOKVkOKVkOKVneKWiOKWiOKVkSAg4paI4paI4pWRCiAgIOKWiOKWiOKVkSAgIOKWiOKWiOKWiOKWiOKWiOKWiOKWiOKVkeKWiOKWiOKWiOKWiOKWiOKVlyAgICAgICAgICDilojilojilojilojilojilojilojilZHilojilojilZEgICDilojilojilZHilojilojilZTilojilojilZcg4paI4paI4pWRICAg4paI4paI4pWRICAg4paI4paI4pWR4paI4paI4pWU4paI4paI4pWXIOKWiOKWiOKVkeKWiOKWiOKVkSAg4paI4paI4paI4pWXICAg4paI4paI4paI4paI4paI4paI4paI4pWX4paI4paI4paI4paI4paI4paI4paI4pWRCiAgIOKWiOKWiOKVkSAgIOKWiOKWiOKVlOKVkOKVkOKWiOKWiOKVkeKWiOKWiOKVlOKVkOKVkOKVnSAgICAgICAgICDilojilojilZTilZDilZDilojilojilZHilojilojilZEgICDilojilojilZHilojilojilZHilZrilojilojilZfilojilojilZEgICDilojilojilZEgICDilojilojilZHilojilojilZHilZrilojilojilZfilojilojilZHilojilojilZEgICDilojilojilZEgICDilZrilZDilZDilZDilZDilojilojilZHilojilojilZTilZDilZDilojilojilZEKICAg4paI4paI4pWRICAg4paI4paI4pWRICDilojilojilZHilojilojilojilojilojilojilojilZfilojilojilojilojilojilojilojilZfilojilojilZEgIOKWiOKWiOKVkeKVmuKWiOKWiOKWiOKWiOKWiOKWiOKVlOKVneKWiOKWiOKVkSDilZrilojilojilojilojilZEgICDilojilojilZEgICDilojilojilZHilojilojilZEg4pWa4paI4paI4paI4paI4pWR4pWa4paI4paI4paI4paI4paI4paI4pWU4pWd4paI4paI4pWX4paI4paI4paI4paI4paI4paI4paI4pWR4paI4paI4pWRICDilojilojilZEKICAg4pWa4pWQ4pWdICAg4pWa4pWQ4pWdICDilZrilZDilZ3ilZrilZDilZDilZDilZDilZDilZDilZ3ilZrilZDilZDilZDilZDilZDilZDilZ3ilZrilZDilZ0gIOKVmuKVkOKVnSDilZrilZDilZDilZDilZDilZDilZ0g4pWa4pWQ4pWdICDilZrilZDilZDilZDilZ0gICDilZrilZDilZ0gICDilZrilZDilZ3ilZrilZDilZ0gIOKVmuKVkOKVkOKVkOKVnSDilZrilZDilZDilZDilZDilZDilZ0g4pWa4pWQ4pWd4pWa4pWQ4pWQ4pWQ4pWQ4pWQ4pWQ4pWd4pWa4pWQ4pWdICDilZrilZDilZ0="
}

credits(){
  print_line
  base64 -d <<<"ICAgQ3JlZGl0czogVGhhbmtzIHRvIGh0dHBzOi8vZ2l0aHViLmNvbS9PSiBodHRwczovL2dpdGh1Yi5jb20vT1dBU1AgaHR0cHM6Ly9naXRodWIuY29tL2hhY2NlcgogICBodHRwczovL2dpdGh1Yi5jb20vdG9tbm9tbm9tIGh0dHBzOi8vZ2l0aHViLmNvbS9taWNoZW5yaWtzZW4gJiBUaGUgRGFyayBSYXZlciBmb3IgdGhlaXIKICAgd29yayBvbiB0aGUgcHJvZ3JhbXMgdGhhdCB3ZW50IGludG8gdGhlIG1ha2luZyBvZiB0aGVfaHVudGluZy5zaC4="
  echo " "
  print_line
}

licensing_info(){
  base64 -d <<<"CXRoZV9odW50aW5nIENvcHlyaWdodCAoQykgMjAyMCAgQGluY3JlZGluY29tcAoJVGhpcyBwcm9ncmFtIGNvbWVzIHdpdGggQUJTT0xVVEVMWSBOTyBXQVJSQU5UWTsgZm9yIGRldGFpbHMgY2FsbCBgLi90aGVfaHVudGluZy5zaCAtbGljZW5zZScuCglUaGlzIGlzIGZyZWUgc29mdHdhcmUsIGFuZCB5b3UgYXJlIHdlbGNvbWUgdG8gcmVkaXN0cmlidXRlIGl0LgoJdW5kZXIgY2VydGFpbiBjb25kaXRpb25zOyB0eXBlIGAuL3RoZV9odW50aW5nLnNoIC1saWNlbnNlJyBmb3IgZGV0YWlscy4="
  echo " "
}

print_line () {
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  echo " "
}

open_program(){
  logo
  echo " "
  credits
  licensing_info
  print_line
}

# main
main(){
  clear
  open_program
  if [ -d "./targets/"$target"" ]
  then
    echo "$target is a known target. Making a new directory inside ./targets/$target/ with todays date."
  fi
  if [ -z "$slack_url" ]; then
    echo "${red}Notifications not set up. Add your slack url to ./slack_url.txt${reset}"
  fi

  mkdir ./targets/"$target"/
  mkdir ./targets/"$target"/"$foldername"
  mkdir ./targets/"$target"/"$foldername"/aqua_out/
  mkdir ./targets/"$target"/"$foldername"/aqua_out/parsedjson/
  mkdir ./targets/"$target"/"$foldername"/subdomain_enum/
  mkdir ./targets/"$target"/"$foldername"/subdomain_enum/amass/
  mkdir ./targets/"$target"/"$foldername"/subdomain_enum/gobuster/
  mkdir ./targets/"$target"/"$foldername"/screenshots/
  mkdir ./targets/"$target"/"$foldername"/directory_fuzzing/
  mkdir ./targets/"$target"/"$foldername"/directory_fuzzing/gobuster/
  mkdir ./targets/"$target"/"$foldername"/scanning/
  mkdir ./targets/"$target"/"$foldername"/scanning/nmap/
  mkdir ./targets/"$target"/"$foldername"/scanning/nuclei/
  touch ./targets/"$target"/"$foldername"/responsive-domains-80-443.txt
  touch ./targets/"$target"/"$foldername"/subdomain-takeover-results.json
  touch ./targets/"$target"/"$foldername"/live_paths.txt
  touch ./targets/"$target"/"$foldername"/alldomains.txt
  touch ./targets/"$target"/"$foldername"/ipaddress.txt
  touch ./targets/"$target"/"$foldername"/temp-clean.txt

  recon "$target"
  scanning "$target"
  notify
  echo "${green}Scan for "$target" finished successfully${reset}"
  duration=$SECONDS
  echo "Completed in : $((duration / 60)) minutes and $((duration % 60)) seconds."
  rm -rf ./targets/incredincomp.com
  stty sane
  tput sgr0
}
todate=$(date +"%Y-%m-%d")
totime=$(date +"%I")
path=$(pwd)
foldername=$todate"-"$totime
main "$target"
