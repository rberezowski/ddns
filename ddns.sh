#!/bin/bash

### ===========================================================
### Auto-Update DDNS (Cloudflare) - Colorized + Modular Script
### ===========================================================

# === SECTION: GLOBAL FLAGS ===
VERBOSE=false
RUN_MODE=false
ENV_PATH="/root/.env.ddns"

# === SECTION: COLOR DEFINITIONS ===
declare -A COLORS=(
  ["{RESET}"]="\033[0m"
  ["{RED}"]="\033[0;31m"
  ["{GREEN}"]="\033[0;32m"
  ["{YELLOW}"]="\033[1;33m"
  ["{BLUE}"]="\033[0;34m"
  ["{CYAN}"]="\033[0;36m"
  ["{MAGENTA}"]="\033[0;35m"
  ["{WHITE}"]="\033[1;37m"
)

print_color() {
  local text="$*"
  for tag in "${!COLORS[@]}"; do
    text="${text//${tag}/${COLORS[$tag]}}"
  done
  echo -e "${text}${COLORS["{RESET}"]}"
}

# === SECTION: REQUIREMENTS CHECK ===
for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    print_color "{RED}âŒ Required command not found: $cmd{RESET}"
    read -rp "$(print_color "{YELLOW}Would you like to attempt to install $cmd now? (y/n): {RESET}")" answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y "$cmd"
      elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "$cmd"
      elif command -v yum >/dev/null 2>&1; then
        yum install -y "$cmd"
      elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm "$cmd"
      else
        print_color "{RED}âŒ Unsupported package manager. Please install $cmd manually.{RESET}"
        exit 1
      fi

      if ! command -v "$cmd" >/dev/null 2>&1; then
        print_color "{RED}âŒ Installation failed. Please install $cmd manually.{RESET}"
        exit 1
      else
        print_color "{GREEN}âœ… Successfully installed $cmd.{RESET}"
      fi
    else
      print_color "{RED}âŒ Cannot continue without $cmd. Exiting.{RESET}"
      exit 1
    fi
  fi
done

# === SECTION: PARSE ARGUMENTS ===
for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
    --run) RUN_MODE=true ;;
    --version)
  source "$ENV_PATH" 2>/dev/null
  : "${SCRIPT_VERSION:=Unknown}"
  : "${SCRIPT_AUTHOR:=Unknown}"
  print_color "{MAGENTA}DDNS Script Version: {YELLOW}$SCRIPT_VERSION{RESET}"
  print_color "{MAGENTA}Author: {YELLOW}$SCRIPT_AUTHOR{RESET}"
  exit 0
  ;;

    --help)
  source "$ENV_PATH" 2>/dev/null
  : "${SCRIPT_VERSION:=Unknown}"
  : "${SCRIPT_AUTHOR:=Unknown}"

  print_color "
{CYAN}Auto-Update DDNS Script (Cloudflare){RESET}
{CYAN}------------------------------------{RESET}
{MAGENTA}DDNS Script Version:{RESET} {YELLOW}$SCRIPT_VERSION   {MAGENTA}Author:{RESET} {YELLOW}$SCRIPT_AUTHOR{RESET}

{WHITE}This script updates A records for multiple subdomains on Cloudflare
if your public IP or proxied setting has changed.{RESET}

{MAGENTA}Requirements:{RESET}
  {WHITE}curl and jq must be installed on the system.{RESET}

{MAGENTA}Usage:{RESET}
  {WHITE}./ddns.sh --run [--verbose]{RESET}
  {WHITE}./ddns.sh --help{RESET}

{MAGENTA}Options:{RESET}
  {CYAN}--run{RESET}         {WHITE}Execute DNS updates (required for action){RESET}
  {CYAN}--verbose{RESET}     {WHITE}Show output to terminal (use with --run only){RESET}
  {CYAN}--help{RESET}        {WHITE}Show this help message{RESET}
  {CYAN}--version{RESET}     {WHITE}Display version and author information{RESET}

{MAGENTA}Required .env.ddns Settings:{RESET}
  {WHITE}CF_API_TOKEN           Your Cloudflare API token
  DISCORD_WEBHOOK_URL    Webhook URL for alerts
  SUBDOMAIN_COUNT        Number of subdomains to process{RESET}

{MAGENTA}Optional .env.ddns Settings:{RESET}
  {WHITE}DEFAULT_TTL            Default TTL (e.g., 120)
  DEFAULT_PROXIED        Default proxied setting (true or false)
  LOG_FILE               Default: /var/log/ddns/ddns_update.log{RESET}

{MAGENTA}Per-subdomain Entries:{RESET}
  {WHITE}SUBDOMAIN_1=test.domain.com
  SUBDOMAIN_1_TTL=300
  SUBDOMAIN_1_PROXIED=true{RESET}

{MAGENTA}Example Cron Job:{RESET}
  {WHITE}*/15 * * * * /path/to/ddns.sh --run >> /var/log/ddns/cron.log 2>&1{RESET}
"
  exit 0
  ;;

    *) ;;
  esac
done

# === SECTION: VALIDATE RUN MODE ===
if [[ "$RUN_MODE" != true ]]; then
  print_color "{YELLOW}âš ï¸  No action specified. Use {CYAN}--run{YELLOW} to update DDNS or {CYAN}--help{YELLOW} for usage.{RESET}"
  exit 1
fi

if [[ "$VERBOSE" == true && "$RUN_MODE" != true ]]; then
  print_color "{RED}âŒ --verbose can only be used with --run{RESET}"
  exit 1
fi

# === SECTION: GENERATE DEFAULT ENV IF MISSING ===
generate_env_template() {
  cat <<EOF > "$ENV_PATH"
# === Cloudflare API Token ===
CF_API_TOKEN=your_cloudflare_api_token_here

# === Discord Webhook ===
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...

# === Default Settings ===
DEFAULT_TTL=120
DEFAULT_PROXIED=false
SUBDOMAIN_COUNT=1

# === Subdomain Entries ===
SUBDOMAIN_1=test.example.com
SUBDOMAIN_1_TTL=300
SUBDOMAIN_1_PROXIED=true
EOF

  chmod 600 "$ENV_PATH"
  chown root:root "$ENV_PATH"
  echo "âœ… Created default .env.ddns at $ENV_PATH"
}

# === SECTION: LOGGING FUNCTION ===
log_msg() {
  local level="$1"
  local message="$2"
  local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"

  # Always log plain version to log file
  echo "$timestamp [$level] $message" >> "$LOG_FILE"

  # Exit early if not in verbose mode
  if [[ "$VERBOSE" != true ]]; then return; fi

  # Determine level color
  local level_color=""
  case "$level" in
    INFO) level_color="{YELLOW}[INFO]{RESET}" ;;
    ERROR) level_color="{RED}[ERROR]{RESET}" ;;
    SUCCESS) level_color="{GREEN}[SUCCESS]{RESET}" ;;
    *) level_color="[$level]" ;;
  esac

  # Print formatted and colorized line
  if [[ "$message" == "********** DDNS UPDATE START **********" || "$message" == "********** DDNS UPDATE COMPLETED **********" ]]; then
    print_color "{CYAN}$timestamp{RESET} $level_color {CYAN}$message{RESET}"
  else
    print_color "{CYAN}$timestamp{RESET} $level_color $message"
  fi
}


# === SECTION: LOAD CONFIG ===
load_env_config() {
  if [[ ! -f "$ENV_PATH" ]]; then
    generate_env_template
    exit 0
  fi
  source "$ENV_PATH"

  : "${CF_API_TOKEN:?Missing CF_API_TOKEN in .env.ddns}"
  : "${DISCORD_WEBHOOK_URL:?Missing DISCORD_WEBHOOK_URL in .env.ddns}"
  : "${SUBDOMAIN_COUNT:?Missing SUBDOMAIN_COUNT in .env.ddns}"

  DEFAULT_TTL=${DEFAULT_TTL:-120}
  DEFAULT_PROXIED=${DEFAULT_PROXIED:-false}
  LOG_FILE=${LOG_FILE:-/var/log/ddns/ddns_update.log}
  IP_FILE="/var/tmp/ddns_last_ip.txt"
  mkdir -p "$(dirname "$LOG_FILE")"
}

# === SECTION: DETECT PUBLIC IP ===
detect_public_ip() {
  CURRENT_IP=$(curl -s https://api.ipify.org)
  if [[ -z "$CURRENT_IP" ]]; then
    CURRENT_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
  fi
  if [[ -z "$CURRENT_IP" ]]; then
    log_msg "ERROR" "{RED}âŒ Could not determine public IP.{RESET}"
    exit 1
  fi
  log_msg "INFO" "ðŸŒ Current Public IP: $CURRENT_IP"
}

# === SECTION: ROOT DOMAIN ===
extract_root_domain() {
  local fqdn="$1"
  echo "$fqdn" | awk -F. '{print $(NF-1)"."$NF}'
}

# === SECTION: CF LOOKUPS ===
get_zone_id_for_domain() {
  local domain="$1"
  curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$domain" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" | jq -r '.result[0].id'
}

create_record() {
  local zone_id="$1" subdomain="$2" ttl="$3" proxied="$4"
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
      \"type\": \"A\",
      \"name\": \"$subdomain\",
      \"content\": \"$CURRENT_IP\",
      \"ttl\": $ttl,
      \"proxied\": $proxied
    }"
}

update_record() {
  local zone_id="$1" record_id="$2" subdomain="$3" ttl="$4" proxied="$5"
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
      \"type\": \"A\",
      \"name\": \"$subdomain\",
      \"content\": \"$CURRENT_IP\",
      \"ttl\": $ttl,
      \"proxied\": $proxied
    }"
}

send_discord_summary() {
  local content="ðŸ“£ DDNS Update Summary:\n\n"
  for change in "${SUMMARY_CHANGES[@]}"; do
    content+="$change\n\n"
  done
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"username\": \"DDNS Monitor\", \"content\": \"$content\"}" \
    "$DISCORD_WEBHOOK_URL" >/dev/null
  log_msg "INFO" "ðŸ“¤ Discord alert sent."
}

# === SECTION: UPDATE LOGIC ===
process_all_subdomains() {
  SUMMARY_CHANGES=()

  for i in $(seq 1 "$SUBDOMAIN_COUNT"); do
    eval fqdn="\${SUBDOMAIN_${i}}"
    eval ttl="\${SUBDOMAIN_${i}_TTL}"
    eval proxied="\${SUBDOMAIN_${i}_PROXIED}"

    fqdn=${fqdn,,}
    ttl=${ttl:-$DEFAULT_TTL}
    proxied=${proxied:-$DEFAULT_PROXIED}

    log_msg "INFO" "ðŸ” Checking $fqdn (TTL=$ttl, Proxied=$proxied)"
    domain=$(extract_root_domain "$fqdn")
    zone_id=$(get_zone_id_for_domain "$domain")

    if [[ -z "$zone_id" || "$zone_id" == "null" ]]; then
      log_msg "ERROR" "{RED}âŒ Failed to get zone ID for $fqdn{RESET}"
      continue
    fi

    record_resp=$(curl -s -X GET \
      "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$fqdn" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json")

    record_id=$(echo "$record_resp" | jq -r '.result[0].id')
    old_ip=$(echo "$record_resp" | jq -r '.result[0].content')
    old_proxied=$(echo "$record_resp" | jq -r '.result[0].proxied')

    if [[ -z "$record_id" || "$record_id" == "null" ]]; then
      log_msg "SUCCESS" "ðŸ†• Created DNS record for $fqdn â†’ $CURRENT_IP (proxied=$proxied)"
      create_record "$zone_id" "$fqdn" "$ttl" "$proxied" >/dev/null
      SUMMARY_CHANGES+=("ðŸ†• Created $fqdn â†’ $CURRENT_IP (proxied=$proxied)")
    elif [[ "$CURRENT_IP" != "$old_ip" || "$proxied" != "$old_proxied" ]]; then
      log_msg "SUCCESS" "ðŸ”„ Updated DNS record for $fqdn â†’ $CURRENT_IP (proxied=$proxied)"
      update_record "$zone_id" "$record_id" "$fqdn" "$ttl" "$proxied" >/dev/null
      SUMMARY_CHANGES+=("âœ… Updated $fqdn:\nOld IP: $old_ip\nNew IP: $CURRENT_IP\nProxied: $proxied")
    else
      log_msg "INFO" "âœ… No change for $fqdn (IP=$CURRENT_IP)"
    fi
  done

  if [[ ${#SUMMARY_CHANGES[@]} -gt 0 ]]; then
    send_discord_summary
    echo "$CURRENT_IP" > "$IP_FILE"
  fi
}

# === SECTION: MAIN EXECUTION ===
load_env_config
log_msg "INFO" "********** DDNS UPDATE START **********"
detect_public_ip
process_all_subdomains
log_msg "INFO" "********** DDNS UPDATE COMPLETED **********"
exit 0
