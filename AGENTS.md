# AGENTS.md - Dotfiles Development Guide

## Repository Overview

This is a **dotfiles repository** containing shell (bash) and Vim editor configurations. It is not a software project with build/test commands - it stores configuration files that get symlinked to the user's home directory.

## File Structure

| File | Purpose |
|------|---------|
| `.bashrc` | Main bash shell configuration |
| `.bashrc_custom` | User-specific bash customizations (sourced after .bashrc) |
| `.bash/prompt.sh` | Shell prompt customization with git status caching |
| `.zshrc` | Zsh shell configuration |
| `.zsh/prompt.zsh` | Zsh prompt with vcs_info |
| `.vimrc` | Vim editor configuration |
| `.git-completion.bash` | Git bash completion script |
| `.gitignore_global` | Global gitignore patterns |
| `iptables.rules` | Legacy iptables firewall rules |
| `nftables.rules` | Modern nftables firewall rules |
| `install.sh` | Installation script to symlink dotfiles to $HOME |

## Build/Lint/Test Commands

**Not applicable** - This is a configuration repository, not a software project.

- No build system
- No test suite
- No linters (though ALE is configured in `.vimrc` for linting code edited in Vim)

## Code Style Guidelines

### General Principles

1. **Keep changes minimal** - Only modify what's necessary
2. **Test locally before committing** - Source modified files to verify syntax
3. **Maintain compatibility** - Ensure changes work on macOS and Linux

### Shell/Bash Scripts (.bashrc, .bashrc_custom, .bash/*.sh)

#### Formatting
- Use 2-space indentation for shell scripts
- Use spaces around `=` in variable assignments: `VAR=value` (no spaces)
- Use spaces after keywords: `if [ ... ]`, `while [ ... ]`
- Use spaces after commas in commands: `echo $VAR, $OTHER`

#### Naming Conventions
- Variables: UPPER_CASE for environment variables (e.g., `DEVHOME`, `GOPATH`)
- Variables: lower_case for local variables in functions
- Functions: Use `snake_case` (e.g., `generate_uuid`, `cd`)
- Aliases: Use lowercase (e.g., `alias ll="ls -alrtF --color"`)

### Zsh Scripts (.zshrc, .zsh/*.zsh)

#### Formatting
- Use 2-space indentation (same as bash)
- Use `autoload -U` for function autoloading
- Use `zstyle` for configuration

#### Best Practices
- Use `command -v` instead of `which` for command detection
- Use `${var}` for parameter expansion (more consistent than bash)
- Use `add-zsh-hook` for prompt and command hooks
- Use `vcs_info` for git prompt (more efficient than calling git directly)

#### Error Handling
- Use `set -e` at the top of scripts when appropriate
- Quote variables to handle spaces: `"$VAR"` not `$VAR`
- Use `[[ ]]` instead of `[ ]` for bash conditionals
- Check for file existence before sourcing: `if [ -f "$FILE" ]; then`

#### Imports/Sourcing
- Source external files with: `. $FILE` or `source "$FILE"`
- Always quote file paths: `SOURCE="${BASH_SOURCE[0]}"`
- Use `dirname` for relative paths: `DIR="$( dirname "$SOURCE" )"`

#### Best Practices
```bash
# Good
if [[ $curr_dir =~ $DEVHOME && -e $curr_dir/.env ]]; then
    source $curr_dir/.env
fi

# Avoid
if [ $curr_dir = $DEVHOME ] # Missing quotes, using [ instead of [[
```

### Vim Configuration (.vimrc)

#### Formatting
- Use 2-space indentation within vimscript
- Use backslash for dictionary/mapping continuations: `\`
- Group related settings together with comment headers

#### Plugin Management
- Use vim-plug for plugin management
- Place plugins between `call plug#begin()` and `call plug#end()`
- Use `{ 'branch': 'branch_name' }` for non-master branches

#### Settings
- Use `set` for boolean options: `set hlsearch incsearch`
- Use `let g:plugin_name_setting = value` for plugin config
- Use `nnoremap` for normal mode mappings (never use `map` - it's recursive)
- Use `<Plug>(plugin-action)` for plugin mappings

#### Naming Conventions
- Plugin variables: `g:pluginname_settingname`
- Functions: Use `CamelCase` or `s:snake_case` for script-local functions
- Autocmd groups: Use meaningful names (e.g., `augroup lsp_install`)

#### Example Patterns
```vim
" Good - proper group and function
augroup lsp_install
    au!
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END

function! s:on_lsp_buffer_enabled() abort
    setlocal omnifunc=lsp#complete
endfunction

" Good - using nnoremap
nnoremap <leader>tn :TestNearest<CR>
```

### Git Commits

- Keep commit messages concise and descriptive
- Focus on "why" rather than "what"
- Example: "Add Go path auto-detection in dev directories"

## Common Tasks

### Adding a new bash alias
Edit `.bashrc_custom` (not `.bashrc`) - it's sourced after main config and won't conflict with upstream updates.

### Adding a new vim plugin
1. Add to `.vimrc` between `call plug#begin()` and `call plug#end()`
2. Run `:PlugInstall` in vim to install
3. Add any required configuration after the `call plug#end()`

### Testing bash changes
```bash
source ~/.bashrc  # Reload configuration
# Or for a specific file:
source ~/.bashrc_custom
```

### Checking vim configuration syntax
```vim
:source ~/.vimrc  " In vim, loads and checks syntax
:echo v:errmsg    " Check for errors after sourcing
```

## Editor Tools (Pre-configured in .vimrc)

- **LSP**: vim-lsp with pylsp, clangd, tsserver, ruby-lsp/solargraph
- **Linting**: ALE with ruff, mypy, rubocop, gofmt
- **Testing**: vim-test with dispatch
- **Completion**: Built-in + LSP
- **Search**: fzf (Leader+ff, fg, fb)
- **Debugging**: Vimspector
- **Copilot**: Enabled for python, javascript, typescript, ruby, go, cpp, c
