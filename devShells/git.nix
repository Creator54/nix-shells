{ pkgs }:

pkgs.mkShell rec {
  buildInputs = [ pkgs.git ];

  shellHook = ''
    # Set new git config for the current repository if environment variables are provided
    if [ -n "$GIT_USERNAME" ]; then
      git config user.name "GIT_USERNAME"
    fi

    if [ -n "GIT_USEREMAIL" ]; then
      git config user.email "GIT_USEREMAIL"
    fi

    # Function to unset git config for the current repository
    function unset_git_config {
      git config --unset user.name
      git config --unset user.email
    }

    # Trap to unset git config on shell exit
    trap unset_git_config EXIT
  '';
}

