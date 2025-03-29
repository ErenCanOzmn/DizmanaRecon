#!/bin/bash

figlet "DIZMANA"

run_subenum=false
run_ipcheck=false
run_dfuzz=false
run_nuclei=false
nightmode=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -l)
      domain_list=$2
      shift 2
      ;;
    -subenum)
      run_subenum=true
      shift
      ;;
    -ipcheck)
      run_ipcheck=true
      shift
      ;;
    -dfuzz)
      run_dfuzz=true
      shift
      ;;
    -nuclei)
      run_nuclei=true
      shift
      ;;
    -nightmode)
      nightmode=true
      shift
      ;;
    -all)
      run_subenum=true
      run_ipcheck=true
      run_dfuzz=true
      run_nuclei=true
      shift
      ;;
    *)
      echo "[!] Usage: $0 -l [domain-list-file] [-subenum] [-ipcheck] [-dfuzz] [-nuclei] [-nightmode] [-all]"
      exit 1
      ;;
  esac
done

if [[ -z "$domain_list" ]]; then
  echo "[!] Domain list file is missing! Use -l to specify the file."
  exit 1
fi

if [ ! -f "$domain_list" ]; then
  echo "[!] File '$domain_list' not found!"
  exit 1
fi

echo "[+] Creating 'subdomains', 'ip_list', 'active_results', 'dirs', and 'nuclei_results' directories..."
mkdir -p subdomains ip_list active_results dirs nuclei_results

ports=(66 80 81 443 445 457 1080 1100 1241 1352 1433 1434 1521 1944 2301 3000 3128 3306 4000 4001 4002 4100 5000 5432 5800 5801 5802 6346 6347 7001 7002 8000 8080 8443 8888 30821)

active_file="active_results/active.txt"
> "$active_file"

while read -r domain || [[ -n $domain ]]; do
  if [[ "$run_subenum" == true ]]; then
    echo "[+] Running subfinder for domain: $domain"
    subfinder -d "$domain" -all -o "subdomains/${domain}_subfinder.txt"

    echo "[+] Running Sublist3r for domain: $domain"
    sublist3r -d "$domain" -o "subdomains/${domain}_sublist3r.txt"

    if [[ "$nightmode" == true ]]; then
      echo "[+] Nightmode active! Running Gobuster with high-intensity settings for domain: $domain"
      gobuster dns -d "$domain" -w /usr/share/wordlists/amass/n0kovo_subdomains_medium.txt -o "subdomains/${domain}_gobuster_raw.txt" -t 20
    else
      echo "[+] Running Gobuster DNS for domain: $domain"
      gobuster dns -d "$domain" -w /usr/share/wordlists/amass/subdomains-top1mil-20000.txt -o "subdomains/${domain}_gobuster_raw.txt"
    fi

    echo "[+] Cleaning up Gobuster results for domain: $domain"
    awk -F: '{print $2}' "subdomains/${domain}_gobuster_raw.txt" | awk -F32m '{print $2}' | sort | uniq | tail -n +2 > "subdomains/${domain}_gobuster_cleaned.txt"

    combined_file="subdomains/${domain}_all_combined.txt"
    final_output="subdomains/${domain}_final.txt"

    echo "[+] Combining results for domain: $domain"
    cat "subdomains/${domain}_subfinder.txt" \
        "subdomains/${domain}_sublist3r.txt" \
        "subdomains/${domain}_gobuster_cleaned.txt" > "$combined_file"

    echo "[+] Removing duplicates for domain: $domain"
    sort "$combined_file" | uniq > "$final_output"
  fi

  if [[ "$run_ipcheck" == true ]]; then
    ip_output="ip_list/${domain}_ip.txt"
    echo "[+] Resolving subdomains to IPs for domain: $domain"
    while read -r subdomain || [[ -n $subdomain ]]; do
      ip=$(dig +short "$subdomain" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)
      if [ -n "$ip" ]; then
        echo "[+] '$subdomain' => $ip"
        echo "$subdomain => $ip" >> "$ip_output"
      else
        echo "[!] '$subdomain' => [RESOLVE ERROR]"
      fi
    done < "$final_output"

    sort "$ip_output" | uniq > "${ip_output}.new"
    mv "${ip_output}.new" "$ip_output"
    echo "[+] IP list saved in: $ip_output"
  fi

  if [[ "$run_ipcheck" == true ]]; then
    active_domain_file="active_results/${domain}_active.txt"
    > "$active_domain_file"

    echo "[+] Checking active subdomains for domain: $domain with HTTPX"
    cat "$final_output" | httpx -ports 66,80,81,443,445,457,1080,1100,1241,1352,1433,1434,1521,1944,2301,3000,3128,3306,4000,4001,4002,4100,5000,5432,5800,5801,5802,6346,6347,7001,7002,8000,8080,8443,8888,30821 -t 100 -timeout 5 -o "$active_domain_file"

    cat "$active_domain_file" >> "$active_file"
  fi
done < "$domain_list"

if [[ "$run_dfuzz" == true ]]; then
  echo "[+] Starting directory fuzzing with FFUF..."
  while read -r url || [[ -n $url ]]; do
    proto=$(echo "$url" | cut -d'/' -f1)
    domain=$(echo "$url" | cut -d'/' -f3)

    target_dir="dirs/${domain}_search"
    mkdir -p "$target_dir"

    ffuf -w /usr/share/wordlists/dirb/common.txt \
         -u "$url/FUZZ" \
         -rate 20 \
         -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 Firefox/130.0" \
         -o "${target_dir}/${domain}.${proto}.csv" \
         -of csv \
         -maxtime 900

    echo "$url" >> "completed.txt"
  done < "$active_file"
fi

if [[ "$run_nuclei" == true ]]; then
  echo "[+] Running Nuclei scans..."
  nuclei_output="nuclei_results/nuclei.txt"
  cat "$active_file" | nuclei -l - -rl 2 -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 Firefox/130.0" -ni -timeout 3 -retries 3 -stats -si 600 -o "$nuclei_output" -ss host-spray

  echo "[+] Nuclei scans completed. Results saved in: $nuclei_output"
fi

echo "[+] All processes completed successfully!"
