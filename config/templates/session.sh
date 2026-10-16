# Set a custom session root path. Default is `$HOME`.
# Must be called before `initialize_session`.
# TYPE="school"
TYPE="dev"
session_folder_root="$HOME/$TYPE/{{SESSION_NAME}}"
mkdir -p $session_folder_root

session_root "$session_folder_root"

# Create session with specified name if it does not already exist. If no
# argument is given, session name will be based on layout file name.
if initialize_session "{{SESSION_NAME}}"; then

  # Create a new window inline within session layout definition.
  new_window "nvim"
  new_window "term"

  # Load a defined window layout.
  #load_window "example"

  # Select the default active window on session creation.
  select_window 1

fi

# Finalize session creation and switch/attach to it.
finalize_and_go_to_session
