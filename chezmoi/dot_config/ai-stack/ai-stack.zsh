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
  unalias jail jail-spec jail-code codex kimi opencode opencode2 2>/dev/null

  jail() {
    bash "${HOME}/.config/ai-stack/repo/scripts/setup-ai.sh" launch "$@"
  }
  codex() { jail codex "$@"; }
  kimi() { jail kimi "$@"; }
  opencode() { jail opencode "$@"; }
  opencode2() { jail opencode "$@"; }
  jail-spec() { (cd "${HOME}/Dev/sympla" && jail "$@"); }
  jail-code() { (cd "${HOME}/Documents/gcrm/Linear" && jail "$@"); }
  alias jails='cd "${HOME}/Dev/sympla"'
  alias jaill='cd "${HOME}/Documents/gcrm/Linear"'
  ai-check() { bash "${HOME}/.config/ai-stack/repo/scripts/setup-ai.sh" check "$@"; }
fi
