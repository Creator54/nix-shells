{ pkgs }:

pkgs.mkShell rec {
  name = "selenium";
  venvDir = "./.venv";
  buildInputs = [ pkgs.python310 ];
  EDITOR = builtins.getEnv "EDITOR";
  PWD = builtins.getEnv "PWD";

  NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.stdenv.cc.cc
    pkgs.glib
    pkgs.openssl
    pkgs.nss
    pkgs.nspr
    pkgs.xorg.libxcb
  ];

  NIX_LD = pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";

  shellHook = ''
    set -h # Remove "bash: hash: hashing disabled" warning
    SOURCE_DATE_EPOCH=$(date +%s)

    if ! [ -d "${venvDir}" ]; then
      python -m venv "${venvDir}"
    fi
    source "${venvDir}/bin/activate"

    # Function to check and install Python packages
    ensure_python_packages() {
      for package in "$@"; do
        if ! python -m pip list | grep -F "$package" > /dev/null; then
          python -m pip install --upgrade "$package"
        fi
      done
    }

    # Install required Python packages
    ensure_python_packages pip selenium webdriver-manager

    # Display example usage instructions
    cat <<EOF
Example Usage:

Firefox:
------
from selenium import webdriver
from selenium.webdriver.firefox.service import Service as FirefoxService
from webdriver_manager.firefox import GeckoDriverManager

driver = webdriver.Firefox(service=FirefoxService(GeckoDriverManager().install()))
driver.get("https://google.com")
driver.quit()

Chrome:
------
from selenium import webdriver
from selenium.webdriver.chrome.service import Service as ChromeService
from webdriver_manager.chrome import ChromeDriverManager

driver = webdriver.Chrome(service=ChromeService(ChromeDriverManager().install()))
driver.get("https://google.com")
driver.quit()
EOF
  '';
}

