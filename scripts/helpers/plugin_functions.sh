# using @tpm_plugins is now deprecated in favor of using @plugin syntax
tpm_plugins_variable_name="@tpm_plugins"

# manually expanding tilde char or `$HOME` variable.
_manual_expansion() {
  local path="$1"
  local expanded_tilde="${path/#\~/$HOME}"
  echo "${expanded_tilde/#\$HOME/$HOME}"
}

_tpm_path() {
  local string_path="$(tmux start-server\; show-environment -g TMUX_PLUGIN_MANAGER_PATH | cut -f2 -d=)/"
  _manual_expansion "$string_path"
}

_CACHED_TPM_PATH="$(_tpm_path)"

# Get the absolute path to the users configuration file of TMux.
# This includes a prioritized search on different locations.
#
_get_user_tmux_conf() {
  # Define the different possible locations.
  xdg_location="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
  default_location="$HOME/.tmux.conf"

  # Search for the correct configuration file by priority.
  if [ -f "$xdg_location" ]; then
    echo "$xdg_location"

  else
    echo "$default_location"
  fi
}

_tmux_conf_contents() {
  user_config=$(_get_user_tmux_conf)
  cat /etc/tmux.conf "$user_config" 2>/dev/null
  if [ "$1" == "full" ]; then # also output content from sourced files
    local file
    for file in $(_sourced_files); do
      cat $(_manual_expansion "$file") 2>/dev/null
    done
  fi
}

# return files sourced from tmux config files
_sourced_files() {
  _tmux_conf_contents |
    sed -E -n -e "s/^[[:space:]]*source(-file)?[[:space:]]+(-q+[[:space:]]+)?['\"]?([^'\"]+)['\"]?/\3/p"
}

# Want to be able to abort in certain cases
trap "exit 1" TERM
export TOP_PID=$$

_fatal_error_abort() {
  echo >&2 "Aborting."
  kill -s TERM $TOP_PID
}

# PUBLIC FUNCTIONS BELOW

tpm_path() {
  if [ "$_CACHED_TPM_PATH" == "/" ]; then
    echo >&2 "FATAL: Tmux Plugin Manager not configured in tmux.conf"
    _fatal_error_abort
  fi
  echo "$_CACHED_TPM_PATH"
}

tpm_plugins_list_helper() {
  # lists plugins from @tpm_plugins option
  echo "$(tmux start-server\; show-option -gqv "$tpm_plugins_variable_name")"

  # read set -g @plugin "tmux-plugins/tmux-example-plugin" entries
  _tmux_conf_contents "full" |
    awk '/^[ \t]*set(-option)? +-g +@plugin/ { gsub(/'\''/,""); gsub(/'\"'/,""); print $4 }'
}

# Allowed plugin name formats:
# 1. "git://github.com/org/name.git"
# 2. "org/name"
# 3. "./org/name"
#
# returns "name"
plugin_name_helper() {
  local plugin="$1"
  local plugin_name="$(basename -s .git "$plugin")"
  echo "$plugin_name"
}

# Allowed plugin name formats:
# 1. "git://github.com/org/name.git"
# 2. "org/name"
# 3. "./org/name"
#
# returns "org"
plugin_org_helper() {
  local plugin="$1"
  local plugin_dirname="$(dirname "$plugin")"
  local plugin_org="$(basename "$plugin_dirname")"
  echo "$plugin_org"
}

# Allowed plugin name formats:
# 1. "git://github.com/org/name.git"
# 2. "org/name"
# 3. "./org/name"
#
# returns "org/name"
plugin_id_helper() {
  local plugin="$1"
  local plugin_name="$(plugin_name_helper "$plugin")"
  local plugin_org="$(plugin_org_helper "$plugin")"
  echo "$plugin_org/$plugin_name"
}

plugin_path_helper() {
  local plugin="$1"
  local plugin_id="$(plugin_id_helper "$plugin")"
  echo "$(tpm_path)${plugin_id}/"
}

plugin_already_installed() {
  local plugin="$1"
  local plugin_path="$(plugin_path_helper "$plugin")"
  [ -d "$plugin_path" ] &&
    cd "$plugin_path" &&
    git remote >/dev/null 2>&1
}
