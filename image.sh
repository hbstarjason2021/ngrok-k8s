#!/usr/bin/env bash
#
# kubectl-images / image.sh
#
# A kubectl plugin that lists every container image used in the cluster,
# shows its size in human readable form (pulled from node status), and
# reports which workload - Deployment, StatefulSet, DaemonSet, Job,
# CronJob or a bare Pod - references it, along with its namespace.
#
# Usage:
#   ./image.sh                    Interactive menu
#   ./image.sh -n <namespace>     Report for a single namespace (non-interactive)
#   ./image.sh -A                 Report for all namespaces (non-interactive)
#   ./image.sh --no-color         Disable colored output
#   ./image.sh -h                 Show help
#
# Install as a kubectl plugin:
#   cp image.sh /usr/local/bin/kubectl-images
#   chmod +x /usr/local/bin/kubectl-images
#   kubectl images
#
# Requirements: kubectl, jq (>=1.6), bash 4+
set -uo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
NAMESPACE=""
ALL_NAMESPACES=1
USE_COLOR=1
INTERACTIVE=1

declare -A IMG_SIZE      # image name    -> size in bytes
declare -A RS_OWNER      # ns/replicaset -> "Kind/Name"
declare -A JOB_OWNER     # ns/job        -> "Kind/Name"
declare -a ROWS          # "bytes\timage\ttype\tname\tnamespace"

TMP_DIR="$(mktemp -d 2>/dev/null || echo /tmp/kubectl-images.$$)"
mkdir -p "$TMP_DIR" 2>/dev/null || true
cleanup_tmp() { rm -rf "$TMP_DIR" 2>/dev/null || true; }
trap cleanup_tmp EXIT INT TERM

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
setup_colors() {
  if [[ "$USE_COLOR" -eq 1 ]] && [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[0;31m'
    C_GREEN=$'\033[0;32m'
    C_YELLOW=$'\033[0;33m'
    C_BLUE=$'\033[0;34m'
    C_MAGENTA=$'\033[0;35m'
    C_CYAN=$'\033[0;36m'
    C_WHITE=$'\033[1;37m'
    C_GRAY=$'\033[0;90m'
    C_BG_NS=$'\033[1;97;44m'   # highlighted banner: specific namespace
    C_BG_ALL=$'\033[1;97;42m'  # highlighted banner: all namespaces
  else
    C_RESET="" C_BOLD="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW=""
    C_BLUE="" C_MAGENTA="" C_CYAN="" C_WHITE="" C_GRAY=""
    C_BG_NS="" C_BG_ALL=""
  fi
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
die() { echo "${C_RED:-}Error:${C_RESET:-} $*" >&2; exit 1; }

need_bin() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but was not found in PATH."
}

check_requirements() {
  need_bin kubectl
  need_bin jq
  kubectl version --client >/dev/null 2>&1 || die "kubectl could not run."
}

# Current terminal width, falling back to 80 if it can't be detected
term_width() {
  local w
  w=$(tput cols 2>/dev/null) || w=""
  [[ -z "$w" ]] && w="${COLUMNS:-80}"
  [[ "$w" =~ ^[0-9]+$ ]] || w=80
  (( w < 40 )) && w=40
  echo "$w"
}

spinner() {
  local pid=$1 msg=$2
  local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  [[ -t 1 ]] || { wait "$pid"; return; }
  while kill -0 "$pid" 2>/dev/null; do
    i=$(((i + 1) % ${#frames}))
    printf "\r%s %s%s%s " "${frames:$i:1}" "$C_CYAN" "$msg" "$C_RESET"
    sleep 0.08
  done
  printf "\r\033[K"
  wait "$pid"
}

# bytes -> human readable string (KiB/MiB/GiB...)
human_size() {
  local bytes="${1:-}"
  if [[ -z "$bytes" || "$bytes" == "null" || "$bytes" == "-1" ]]; then
    echo "N/A"
    return
  fi
  awk -v b="$bytes" 'BEGIN {
    units[0]="B"; units[1]="KiB"; units[2]="MiB"; units[3]="GiB"; units[4]="TiB"; units[5]="PiB"
    val = b + 0
    u = 0
    while (val >= 1024 && u < 5) { val /= 1024; u++ }
    printf "%.2f %s", val, units[u]
  }'
}

# Color a size string based on magnitude (bytes passed in)
color_for_size() {
  local bytes="${1:-0}"
  if [[ -z "$bytes" || "$bytes" == "null" || "$bytes" == "-1" ]]; then
    echo "$C_GRAY"
    return
  fi
  local mb=$((bytes / 1048576))
  if (( mb >= 1024 )); then
    echo "$C_RED"
  elif (( mb >= 300 )); then
    echo "$C_YELLOW"
  else
    echo "$C_GREEN"
  fi
}

color_for_type() {
  case "$1" in
    Deployment)  echo "$C_BLUE" ;;
    StatefulSet) echo "$C_MAGENTA" ;;
    DaemonSet)   echo "$C_CYAN" ;;
    CronJob)     echo "$C_YELLOW" ;;
    Job)         echo "$C_GREEN" ;;
    Pod)         echo "$C_GRAY" ;;
    *)           echo "$C_WHITE" ;;
  esac
}

# Shorten a string to at most $2 characters, adding an ellipsis if cut
truncate_str() {
  local s="$1" max="$2"
  if (( max > 1 && ${#s} > max )); then
    printf '%s…' "${s:0:$((max - 1))}"
  else
    printf '%s' "$s"
  fi
}

# ---------------------------------------------------------------------------
# Data collection
# ---------------------------------------------------------------------------

# Each fetch_*_bg function runs kubectl+jq once and writes plain TSV to a
# temp file. It runs in the background (so a spinner can be shown) while the
# corresponding fetch_* function later reads that file back in the
# foreground -- this avoids ever hitting the API server twice for one report.

fetch_image_sizes_bg() {
  kubectl get nodes -o json 2>/dev/null | jq -r '
    .items[]?.status.images[]? |
    select(.sizeBytes != null) |
    .sizeBytes as $s |
    .names[]? |
    [., $s] | @tsv
  ' > "$TMP_DIR/images.tsv" 2>"$TMP_DIR/images.err"
}

fetch_image_sizes() {
  while IFS=$'\t' read -r name size; do
    [[ -z "$name" ]] && continue
    IMG_SIZE["$name"]="$size"
  done < "$TMP_DIR/images.tsv"
}

fetch_owner_maps_bg() {
  kubectl get replicasets --all-namespaces -o json 2>/dev/null | jq -r '
    .items[]? |
    .metadata.namespace as $ns |
    .metadata.name as $name |
    ((.metadata.ownerReferences // [])[0].kind // "") as $ok |
    ((.metadata.ownerReferences // [])[0].name // "") as $on |
    [$ns, $name, $ok, $on] | @tsv
  ' > "$TMP_DIR/replicasets.tsv" 2>"$TMP_DIR/replicasets.err"

  kubectl get jobs --all-namespaces -o json 2>/dev/null | jq -r '
    .items[]? |
    .metadata.namespace as $ns |
    .metadata.name as $name |
    ((.metadata.ownerReferences // [])[0].kind // "") as $ok |
    ((.metadata.ownerReferences // [])[0].name // "") as $on |
    [$ns, $name, $ok, $on] | @tsv
  ' > "$TMP_DIR/jobs.tsv" 2>"$TMP_DIR/jobs.err"
}

fetch_owner_maps() {
  while IFS=$'\t' read -r ns name ownerKind ownerName; do
    [[ -z "$ns$name" ]] && continue
    if [[ -n "$ownerKind" ]]; then
      RS_OWNER["$ns/$name"]="$ownerKind/$ownerName"
    else
      RS_OWNER["$ns/$name"]="ReplicaSet/$name"
    fi
  done < "$TMP_DIR/replicasets.tsv"

  while IFS=$'\t' read -r ns name ownerKind ownerName; do
    [[ -z "$ns$name" ]] && continue
    if [[ -n "$ownerKind" ]]; then
      JOB_OWNER["$ns/$name"]="$ownerKind/$ownerName"
    else
      JOB_OWNER["$ns/$name"]="Job/$name"
    fi
  done < "$TMP_DIR/jobs.tsv"
}

resolve_owner() {
  local ns="$1" ownerKind="$2" ownerName="$3" podName="$4"
  local resType="" resName="" val=""

  case "$ownerKind" in
    ReplicaSet)
      val="${RS_OWNER["$ns/$ownerName"]:-Deployment/$ownerName}"
      resType="${val%%/*}"
      resName="${val#*/}"
      ;;
    StatefulSet)
      resType="StatefulSet"; resName="$ownerName" ;;
    DaemonSet)
      resType="DaemonSet"; resName="$ownerName" ;;
    Job)
      val="${JOB_OWNER["$ns/$ownerName"]:-Job/$ownerName}"
      resType="${val%%/*}"
      resName="${val#*/}"
      ;;
    "")
      resType="Pod"; resName="$podName" ;;
    *)
      resType="$ownerKind"; resName="$ownerName" ;;
  esac

  printf '%s\t%s' "$resType" "$resName"
}

fetch_workload_images_bg() {
  local ns_filter_args=()
  if [[ "$ALL_NAMESPACES" -eq 1 ]]; then
    ns_filter_args=(--all-namespaces)
  else
    ns_filter_args=(-n "$NAMESPACE")
  fi

  kubectl get pods "${ns_filter_args[@]}" -o json 2>/dev/null | jq -r '
    .items[]? |
    .metadata.namespace as $ns |
    ((.metadata.ownerReferences // [])[0].kind // "") as $ok |
    ((.metadata.ownerReferences // [])[0].name // "") as $on |
    .metadata.name as $pn |
    (((.spec.containers // []) + (.spec.initContainers // []) + (.spec.ephemeralContainers // [])))[] |
    [$ns, $ok, $on, $pn, .image] | @tsv
  ' > "$TMP_DIR/pods.tsv" 2>"$TMP_DIR/pods.err"
}

fetch_workload_images() {
  declare -A seen
  while IFS=$'\t' read -r ns ownerKind ownerName podName image; do
    [[ -z "$image" ]] && continue

    local resolved resType resName
    resolved=$(resolve_owner "$ns" "$ownerKind" "$ownerName" "$podName")
    resType="${resolved%%$'\t'*}"
    resName="${resolved#*$'\t'}"

    local key="${image}|${resType}|${resName}|${ns}"
    if [[ -n "${seen[$key]:-}" ]]; then
      continue
    fi
    seen["$key"]=1

    local bytes="${IMG_SIZE[$image]:-}"
    ROWS+=("${bytes}"$'\t'"${image}"$'\t'"${resType}"$'\t'"${resName}"$'\t'"${ns}")
  done < "$TMP_DIR/pods.tsv"
}

collect_data() {
  IMG_SIZE=()
  RS_OWNER=()
  JOB_OWNER=()
  ROWS=()

  fetch_image_sizes_bg &
  local pid1=$!
  fetch_owner_maps_bg &
  local pid2=$!
  fetch_workload_images_bg &
  local pid3=$!

  spinner "$pid1" "Reading node image inventory..."
  spinner "$pid2" "Resolving Deployment / CronJob ownership..."
  spinner "$pid3" "Scanning pods for container images..."

  fetch_image_sizes
  fetch_owner_maps
  fetch_workload_images
}

# Namespace scoping happens at fetch time (via kubectl -n), so all rows in
# ROWS already belong to the selected namespace. This just sorts by size.
sort_rows_by_size() {
  local -a normalized=()
  local row bytes image resType resName ns

  for row in "${ROWS[@]}"; do
    IFS=$'\t' read -r bytes image resType resName ns <<< "$row"
    [[ -z "$bytes" ]] && bytes=-1
    normalized+=("${bytes}"$'\t'"${image}"$'\t'"${resType}"$'\t'"${resName}"$'\t'"${ns}")
  done

  [[ ${#normalized[@]} -eq 0 ]] && return

  printf '%s\n' "${normalized[@]}" | sort -t $'\t' -k1,1 -nr
}

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

render_table() {
  draw_namespace_banner
  echo

  local -a data=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && data+=("$line")
  done < <(sort_rows_by_size)

  if [[ ${#data[@]} -eq 0 ]]; then
    echo "${C_YELLOW}No images found.${C_RESET}"
    return
  fi

  local w_image=5 w_size=4 w_name=13 w_type=4 w_ns=9
  local row bytes image resType resName ns human

  for row in "${data[@]}"; do
    IFS=$'\t' read -r bytes image resType resName ns <<< "$row"
    (( ${#image} > w_image )) && w_image=${#image}
    human=$(human_size "$bytes")
    (( ${#human} > w_size )) && w_size=${#human}
    (( ${#resName} > w_name )) && w_name=${#resName}
    (( ${#resType} > w_type )) && w_type=${#resType}
    (( ${#ns} > w_ns )) && w_ns=${#ns}
  done

  # Keep the table inside the current terminal width: the IMAGE column is
  # the one most likely to be long, so it flexes/truncates as needed.
  local cols fixed_width max_image
  cols=$(term_width)
  fixed_width=$(( w_size + w_name + w_type + w_ns + 8 ))
  max_image=$(( cols - fixed_width ))
  if (( max_image < 15 )); then
    max_image=15
  fi
  if (( w_image > max_image )); then
    w_image=$max_image
  fi

  local total=$(( w_image + w_size + w_name + w_type + w_ns + 8 ))
  local sep
  sep=$(printf '─%.0s' $(seq 1 "$total"))

  echo "${C_BOLD}${C_WHITE}${sep}${C_RESET}"
  printf "${C_BOLD}${C_WHITE}%-*s  %-*s  %-*s  %-*s  %-*s${C_RESET}\n" \
    "$w_image" "IMAGE" "$w_size" "SIZE" "$w_name" "RESOURCE NAME" "$w_type" "TYPE" "$w_ns" "NAMESPACE"
  echo "$sep"

  for row in "${data[@]}"; do
    IFS=$'\t' read -r bytes image resType resName ns <<< "$row"
    human=$(human_size "$bytes")
    local disp_image sc tc
    disp_image=$(truncate_str "$image" "$w_image")
    sc=$(color_for_size "$bytes")
    tc=$(color_for_type "$resType")
    printf "%-*s  ${sc}%-*s${C_RESET}  %-*s  ${tc}%-*s${C_RESET}  ${C_DIM}%-*s${C_RESET}\n" \
      "$w_image" "$disp_image" "$w_size" "$human" "$w_name" "$resName" "$w_type" "$resType" "$w_ns" "$ns"
  done

  echo
  echo "${C_GRAY}Total: ${#data[@]} image reference(s)${C_RESET}"
}

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------

pause() {
  echo
  read -r -p "${C_GRAY}Press Enter to continue...${C_RESET}" _
}

# Draws a title bar that always matches the current terminal width
draw_header() {
  local cols box_w title title_len pad_total pad_left pad_right border inner
  cols=$(term_width)
  box_w=$(( cols - 2 ))
  title=" kubectl images "
  title_len=${#title}
  (( title_len > box_w )) && title_len=$box_w

  border=$(printf '═%.0s' $(seq 1 "$box_w"))
  pad_total=$(( box_w - title_len ))
  pad_left=$(( pad_total / 2 ))
  pad_right=$(( pad_total - pad_left ))
  inner=$(printf '%*s%s%*s' "$pad_left" "" "$title" "$pad_right" "")

  echo "${C_BOLD}${C_CYAN}╔${border}╗${C_RESET}"
  echo "${C_BOLD}${C_CYAN}║${inner}║${C_RESET}"
  echo "${C_BOLD}${C_CYAN}╚${border}╝${C_RESET}"
}

# Full-width highlighted bar showing which namespace is currently active,
# so it's always obvious at a glance what scope the report/menu is in.
draw_namespace_banner() {
  local cols text color text_len pad_total pad_left pad_right line
  cols=$(term_width)

  if [[ "$ALL_NAMESPACES" -eq 1 ]]; then
    text="ALL NAMESPACES"
    color="$C_BG_ALL"
  else
    text="NAMESPACE: ${NAMESPACE}"
    color="$C_BG_NS"
  fi

  text_len=${#text}
  (( text_len > cols )) && text_len=$cols
  pad_total=$(( cols - text_len ))
  pad_left=$(( pad_total / 2 ))
  pad_right=$(( pad_total - pad_left ))
  line=$(printf '%*s%s%*s' "$pad_left" "" "$text" "$pad_right" "")

  echo "${color}${line}${C_RESET}"
}

interactive_menu() {
  local choice
  while true; do
    clear 2>/dev/null || true
    draw_header
    draw_namespace_banner
    echo
    echo "  ${C_GREEN}1)${C_RESET} Show report"
    echo "  ${C_GREEN}2)${C_RESET} Set namespace filter"
    echo "  ${C_RED}0)${C_RESET} Quit"
    echo
    read -r -p "Select an option: " choice

    case "$choice" in
      1)
        clear 2>/dev/null || true
        render_table
        pause
        ;;
      2)
        read -r -p "Namespace (blank = all namespaces): " NAMESPACE
        if [[ -z "$NAMESPACE" ]]; then
          ALL_NAMESPACES=1
        else
          ALL_NAMESPACES=0
        fi
        collect_data
        echo
        draw_namespace_banner
        sleep 1
        ;;
      0)
        echo "Bye.ツ🙂"
        exit 0
        ;;
      *)
        echo "${C_RED}Invalid option.${C_RESET}"
        sleep 1
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

usage() {
  cat <<EOF
kubectl images - list container images, sizes and the workloads using them

Usage: $(basename "$0") [options]

  -n, --namespace <ns>   Show report for a single namespace (non-interactive)
  -A, --all-namespaces   Show report for all namespaces (non-interactive)
      --no-color         Disable colored output
      --no-interactive   Skip the menu, print the report once and exit
  -h, --help             Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--namespace)
        NAMESPACE="${2:-}"; ALL_NAMESPACES=0; INTERACTIVE=0; shift 2 ;;
      -A|--all-namespaces)
        ALL_NAMESPACES=1; INTERACTIVE=0; shift ;;
      --no-color)
        USE_COLOR=0; shift ;;
      --no-interactive)
        INTERACTIVE=0; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        die "Unknown option: $1" ;;
    esac
  done
}

main() {
  parse_args "$@"
  setup_colors
  check_requirements
  collect_data

  if [[ "$INTERACTIVE" -eq 1 ]]; then
    interactive_menu
  else
    render_table
  fi
}

main "$@"
