# Managed entry points; native binaries remain accessible with `command` for
# host-side login/maintenance. The Python launcher resolves binaries, not these
# functions, so managed launches cannot recursively invoke themselves.
export NVM_DIR="${NVM_DIR:-${HOME}/.nvm}"
if ! typeset -f nvm >/dev/null && [[ -s "${NVM_DIR}/nvm.sh" ]]; then
  source "${NVM_DIR}/nvm.sh"
fi
typeset -U path PATH
path=("${HOME}/.local/bin" "${HOME}/.kimi-code/bin" "${path[@]}")
export PATH

if [[ -f "${HOME}/.config/ai-stack/repo/scripts/setup-ai.sh" ]]; then
  unalias jail jail-here jail-spec jail-code codex kimi opencode opencode2 with-docker 2>/dev/null

  jail() {
    bash "${HOME}/.config/ai-stack/repo/scripts/setup-ai.sh" launch "$@"
  }
  jail-here() {
    bash "${HOME}/.config/ai-stack/repo/scripts/setup-ai.sh" launch-here "$@"
  }
  codex() { jail codex "$@"; }
  kimi() { jail kimi "$@"; }
  opencode() { jail opencode "$@"; }
  opencode2() { jail opencode "$@"; }
  jail-spec() { (cd "${HOME}/Dev/sympla" && jail "$@"); }
  jail-code() { (cd "${HOME}/Documents/gcrm/Linear" && jail "$@"); }
  # Opt in to the host Docker socket (root-equivalent) for one launch only.
  with-docker() {
    (( $# )) || { print -u2 'usage: with-docker <codex|kimi|opencode|opencode2|jail|jail-here|...> [args]'; return 2; }
    (export AI_DOCKER=1; "$@")
  }
  alias jails='cd "${HOME}/Dev/sympla"'
  alias jaill='cd "${HOME}/Documents/gcrm/Linear"'
  ai-check() { bash "${HOME}/.config/ai-stack/repo/scripts/setup-ai.sh" check "$@"; }
  git-update-all() { python3 "${HOME}/.config/ai-stack/repo/scripts/git-update-all.py" "$@"; }
fi
