# My Personal Nix Shells Collection

A personal collection of development environments.

## Available Shells

- `python` - Python 3.11 with imperative pip environment
- `python39` - Python 3.9 with imperative pip environment
- `selenium` - Python 3.10 with Selenium testing setup
- `java` - OpenJDK 11 with Gradle
- `podman` - Rootless container runtime with Docker compatibility
- `signoz` - Monitoring platform using Podman
- `mysql` - MariaDB development environment
- `git` - Git with configurable user settings
- `builder` - MetaGPT wrapper

## Usage

```bash
nix develop --impure --refresh github:creator54/nix-shells#java
```

With direnv (.envrc):
```bash
use flake --impure --refresh github:creator54/nix-shells#java
```
