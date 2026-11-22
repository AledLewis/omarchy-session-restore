# Shared by the omarchy-workspace-* commands. Sourced, not executed.
#
# A workspace preset is an omarchy-session-save manifest limited to one
# workspace, stored as $PRESET_DIR/<name>.json. Unlike the boot manifest it is
# never consumed, so it can be restored as often as you like.

PRESET_DIR="$HOME/.local/state/omarchy/workspaces"

# Names become file names, so keep them to a safe, readable set.
valid_preset_name() {
  [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9\ ._-]{0,63}$ ]]
}

preset_file() {
  printf '%s/%s.json' "$PRESET_DIR" "$1"
}

active_workspace() {
  hyprctl activeworkspace -j | jq -r '.id'
}

# Notify when there is no terminal to print to (e.g. run from the menu).
report() {
  local headline=$1 description=${2:-}
  if [[ -t 1 ]]; then
    echo "$headline${description:+: $description}"
  elif command -v omarchy-notification-send &>/dev/null; then
    omarchy-notification-send -g "󰕰" "$headline" "$description"
  else
    notify-send "$headline" "$description"
  fi
}

# One line per preset: "<name>\t<window count>\t<workspace>\t<saved date>"
list_presets() {
  local f name
  [[ -d $PRESET_DIR ]] || return 0
  for f in "$PRESET_DIR"/*.json; do
    [[ -e $f ]] || continue
    name=$(basename "$f" .json)
    printf '%s\t%s\t%s\t%s\n' "$name" \
      "$(jq 'length' "$f")" \
      "$(jq -r '.[0].workspace' "$f")" \
      "$(date -r "$f" '+%d %b %H:%M')"
  done
}

# Ask for a preset in the Omarchy menu; prints the chosen name.
pick_preset() {
  local prompt=$1 name count ws saved options=()
  while IFS=$'\t' read -r name count ws saved; do
    options+=("󰕰	$name	$count window(s) · workspace $ws · $saved")
  done < <(list_presets)
  if ((${#options[@]} == 0)); then
    report "No saved workspaces" "Save one first with Save Workspace"
    return 1
  fi
  # A row with subtext comes back as "<label>\t<subtext>"; keep the label.
  omarchy-menu-select "$prompt" "${options[@]}" | cut -f1
}
