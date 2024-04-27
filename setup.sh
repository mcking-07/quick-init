#!/bin/bash

set -e

# ? uncomment the line below to enable debug mode.
# set -x

exit_with() {
  local message="$1"
  local exit_code="${2:-1}"

  log "error" "$message"
  exit "$exit_code"
}

command_exists() {
  local application="$1"
  local CONFIG="$HOME/.config"

  command -v "$application" &>/dev/null || [[ -d "$HOME/$application" || -d "$HOME/.$application" || -d "$CONFIG/$application" || -d "$CONFIG/.$application" ]]
}

check_installed() {
  local application="$1"

  if ! command_exists "$application"; then
    exit_with "$application is not installed. please install $application and try again."
  fi
}

run_prerequisites_check() {
  local applications=("git" "nvm" "python")

  for application in "${applications[@]}"; do
    check_installed "$application"
  done
}

log() {
  local level="$1"
  local message="$2"

  printf "[%s]: %s\n" "$level" "$message"
}

is_empty() {
  local variable="$1"

  [[ -z "$variable" ]]
}

# ? might need this, not sure yet.
# try_again() {
#  read -p "do you want to try again? (Y/n): " try_again

#  if [[ "$try_again" == "n" ]]; then
#     exit_with "user aborted the operation." 0
#  fi
# }

create_project_directory() {
  read -p "enter repository name: " repository_name

  if is_empty "$repository_name"; then
    log "error" "repository name cannot be empty."
    create_project_directory
  fi

  mkdir -p "$repository_name" && cd "$repository_name" || exit_with "failed to create directory."
}

initialize_git_repository() {
  git init &>/dev/null

  read -p "do you want to update the branch name to main? (Y/n): " update_branch_name

  if [[ "$update_branch_name" != "n" ]]; then
    git branch -m main
  fi
}

load_nvm() {
  if [[ -s $NVM_DIR/nvm.sh ]]; then
    source $NVM_DIR/nvm.sh
  else
    exit_with "nvm is not installed. please install nvm and try again."
  fi
}

configure_node_version() {
  local node_version="$1"

  load_nvm

  nvm install "$node_version" &>/dev/null || exit_with "failed to install node version $node_version"
  nvm use "$node_version" &>/dev/null || exit_with "failed to use node version $node_version"

  echo "$node_version" >.nvmrc

  if [ $? -ne 0 ]; then
    exit_with "failed to set node version $node_version"
  fi
}

fetch_package_details() {
  echo -e "\nfollow the prompts to enter the package details. press enter to use defaults."

  read -p "package name: " package_name
  package_name="${package_name:-$repository_name}"

  read -p "entry point (e.g. src/index.js): " package_entry_point
  package_entry_point="${package_entry_point:-src/index.js}"

  read -p "description: " package_description
  read -p "author: " package_author

  read -p "license (e.g. MIT): " package_license
  package_license="${package_license:-MIT}"
  package_license="${package_license^^}"

  read -p "repository url: " package_repository_url
}

update_package_json() {
  local package_json_file="package.json"

  jq --arg package_name "$package_name" \
    --arg package_description "$package_description" \
    --arg package_entry_point "$package_entry_point" \
    --arg start_script "node $package_entry_point" \
    --arg package_author "$package_author" \
    --arg package_license "$package_license" \
    --arg package_repository_url "$package_repository_url" \
    '.name |= $package_name | .description |= $package_description | .main |= $package_entry_point | .scripts.start |= $start_script | .author |= $package_author | .license |= $package_license | .repository.type |= "git" | .repository.url |= $package_repository_url | del(.scripts.test)' "$package_json_file" | sponge "$package_json_file"

  if [ $? -ne 0 ]; then
    exit_with "failed to update $package_json_file"
  fi
}

add_code_to_index_file() {
  local file="$1"

  echo -e "\nconst main = () => console.log('this project was bootstrapped using template-factory 🚀.');\n\nmain();" >"$file"

  if [ $? -ne 0 ]; then
    exit_with "failed to add base code to $file"
  fi
}

configure_node_project_structure() {
  local directories=("src")
  local files=("src/index.js")

  for directory in "${directories[@]}"; do
    mkdir -p "$directory"
  done

  for file in "${files[@]}"; do
    touch "$file"
  done

  add_code_to_index_file "src/index.js"
}

configure_basic_project_structure() {
  case "$project_template" in
  "nodejs")
    configure_node_project_structure
    ;;
  "typescript")
    # TODO: configure_typescript_project_structure
    exit_with "typescript template is not supported yet."
    ;;
  "python")
    # TODO: configure_python_project_structure
    exit_with "python template is not supported yet."
    ;;
  esac
}

setup_node_project() {
  local node_version

  while true; do
    read -p "enter node version (eg: 18): " node_version

    if ! is_empty "$node_version"; then
      break
    fi

    log "error" "node version cannot be empty."
  done

  load_nvm

  if [[ $node_version =~ ^[0-9]+$ ]]; then
    node_version=$(nvm version-remote --lts $node_version)
  fi

  configure_node_version "$node_version"
  fetch_package_details

  npm init -y &>/dev/null
  update_package_json

  configure_basic_project_structure
}

setup_project() {
  case "$project_template" in
  "nodejs")
    setup_node_project
    ;;
  "typescript")
    # TODO: setup_typescript_project
    exit_with "typescript template is not supported yet."
    ;;
  "python")
    # TODO: setup_python_project
    exit_with "python template is not supported yet."
    ;;
  esac
}

clean_up() {
  local directory="$1"

  if [[ -d "$directory" ]]; then
    log "info" "cleaning up..."
    rm -rf "$directory"
  fi
}

get_project_template() {
  while true; do
    echo -e "\nproject templates:\n1. node.js\n2. typescript\n3. python\n4. cancel\n"
    read -p "select project template: " project_template

    if is_empty "$project_template"; then
      log "error" "project template cannot be empty."
    elif [[ ! $project_template =~ ^[1-4]$ ]]; then
      log "error" "invalid project template. please try again."
    else
      break
    fi
  done

  case $project_template in
  1) project_template="nodejs" ;;
  2) project_template="typescript" ;;
  3) project_template="python" ;;
  4) clean_up "../$repository_name" && exit_with "user cancelled the operation" 0 ;;
  esac
}

main() {
  run_prerequisites_check
  create_project_directory
  initialize_git_repository
  get_project_template
  setup_project
}

main
