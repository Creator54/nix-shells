{ pkgs }:

pkgs.mkShell rec {
  buildInputs = [ pkgs.git ];
  GIT_USERNAME = builtins.getEnv "GIT_USERNAME";
  GIT_USEREMAIL = builtins.getEnv "GIT_USEREMAIL";

  shellHook = ''
    # Set new git config for the current repository if environment variables are provided
    git config user.name "${GIT_USERNAME}"
    git config user.email "${GIT_USEREMAIL}"

    # Function to unset git config for the current repository
    function unset_git_config {
      git config --unset user.name
      git config --unset user.email
    }

    # Trap to unset git config on shell exit
    trap unset_git_config EXIT
  '';
}

