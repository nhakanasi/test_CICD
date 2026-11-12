# Sourced by the other scripts. On Windows (Git Bash), winget installs kind/kubectl
# and Docker Desktop to folders that an already-open terminal may not have on PATH.
if [[ -n "${LOCALAPPDATA:-}" ]]; then
  WINGET_PKGS="$(cygpath -u "$LOCALAPPDATA")/Microsoft/WinGet/Packages"
  for dir in "$WINGET_PKGS"/Kubernetes.kind_* "$WINGET_PKGS"/Kubernetes.kubectl_* \
             "/c/Program Files/Docker/Docker/resources/bin"; do
    [[ -d "$dir" ]] && PATH="$PATH:$dir"
  done
  export PATH
fi

for cmd in docker kind kubectl; do
  command -v "$cmd" >/dev/null || { echo "Missing '$cmd'. Install: winget install Docker.DockerDesktop Kubernetes.kind Kubernetes.kubectl" >&2; exit 1; }
done
docker info >/dev/null 2>&1 || { echo "Docker is not running. Start Docker Desktop and wait until it says 'Engine running'." >&2; exit 1; }
