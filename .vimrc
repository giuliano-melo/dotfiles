unlet! skip_defaults_vim
source $VIMRUNTIME/defaults.vim

syntax on
filetype  plugin indent on

set hlsearch incsearch ignorecase
set encoding=UTF-8

nnoremap <leader>c :botright term<CR>

call plug#begin('~/.vim/plugged')
  Plug 'prabirshrestha/async.vim'
  Plug 'prabirshrestha/vim-lsp'
  Plug 'airblade/vim-gitgutter'
  Plug 'Raimondi/delimitMate'
  Plug 'mattn/emmet-vim'
  Plug 'nathanaelkane/vim-indent-guides'
  Plug 'itchyny/lightline.vim'
  Plug 'maximbaz/lightline-ale'
  Plug 'editorconfig/editorconfig-vim'
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
  Plug 'tpope/vim-surround'
  Plug 'tpope/vim-repeat'
  Plug 'tpope/vim-unimpaired'
  Plug 'mg979/vim-visual-multi', {'branch': 'master'}
  Plug 'ludovicchabant/vim-gutentags'
  Plug 'sickill/vim-monokai'
  Plug 'dense-analysis/ale'
  Plug 'liuchengxu/vim-which-key'
  Plug 'vim-test/vim-test', {'requires': 'tpope/vim-dispatch'}
  Plug 'tpope/vim-rails'
  Plug 'github/copilot.vim'
  Plug 'puremourning/vimspector'
call plug#end()

set t_Co=256
colorscheme monokai

"--- lightline.vim configuration --------------------------------------
let g:lightline = {
      \ 'colorscheme': 'powerline',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ], [ 'readonly', 'filename', 'modified' ] ],
      \   'right': [ [ 'linter_checking', 'linter_errors', 'linter_warnings', 'linter_ok' ], [ 'lineinfo' ], [ 'percent' ], [ 'fileformat', 'fileencoding', 'filetype' ] ]
      \ },
      \ 'separator': { 'left': ' ', 'right': ' ' },
      \ 'subseparator': { 'left': ' ', 'right': ' ' }
      \ }

let g:lightline.tabline = {
      \ 'left': [ [ 'tabnum' ] ],
      \ 'right': [ ]
      \ }

function! LightlineTabnum()
  let tabnum = tabpagenr()
  let total = tabpagenr("$")
  return tabnum . '/' . total
endfunction

let g:lightline.component = {
      \ 'tabnum': '%{LightlineTabnum()}'
      \ }

let g:lightline.component_expand = {
      \ 'linter_checking': 'lightline#ale#checking',
      \ 'linter_warnings': 'lightline#ale#warnings',
      \ 'linter_errors': 'lightline#ale#errors',
      \ 'linter_ok': 'lightline#ale#ok',
      \ }

let g:lightline.component_type = {
      \ 'linter_checking': 'left',
      \ 'linter_warnings': 'warning',
      \ 'linter_errors': 'error',
      \ 'linter_ok': 'left',
      \ }

set showtabline=2
set laststatus=2

"--- vim-lsp configuration ---------------------------------------------
let g:lsp_use_native_client = 1

if executable('pylsp')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'pylsp',
        \ 'cmd': {server_info->['pylsp']},
        \ 'allowlist': ['python'],
        \ })
endif

if executable('clangd')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'clangd',
        \ 'cmd': {server_info->['clangd', '--background-index']},
        \ 'allowlist': ['c', 'cpp'],
        \ })
endif

if executable('typescript-language-server')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'tsserver',
        \ 'cmd': {server_info->['typescript-language-server', '--stdio']},
        \ 'allowlist': ['javascript', 'typescript'],
        \ })
endif

" Ruby LSP configuration (both ruby-lsp and solargraph)
if executable('ruby-lsp')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'ruby-lsp',
        \ 'cmd': {server_info->['ruby-lsp']},
        \ 'allowlist': ['ruby', 'rake', 'erb', 'gemfile'],
        \ })
endif

if executable('solargraph')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'solargraph',
        \ 'cmd': {server_info->['solargraph', 'stdio']},
        \ 'allowlist': ['ruby', 'rake', 'erb', 'gemfile'],
        \ })
endif

function! s:on_lsp_buffer_enabled() abort
    setlocal omnifunc=lsp#complete
    setlocal signcolumn=yes
    nmap <buffer> gd <plug>(lsp-definition)
    nmap <buffer> gr <plug>(lsp-references)
    nmap <buffer> gi <plug>(lsp-implementation)
    nmap <buffer> K <plug>(lsp-hover)
endfunction

augroup lsp_install
    au!
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END

"Enable auto selection of the first autocomplete item"
augroup LspSetup
    au!
    au User LspAttached set completeopt-=noselect
augroup END
"Disable newline on selecting completion option"
inoremap <expr> <CR> pumvisible() ? "\<C-Y>" : "\<CR>"

"Mappings for most-used functions are set in s:on_lsp_buffer_enabled()"

"--- vim-rails configuration -------------------------------------------
let g:rails_projections = {
      \ "app/controllers/*_controller.rb": {
      \   "command": "controller",
      \   "test": "spec/controllers/",
      \   "keywords": {
      \     "skip_before_action": { "keyword": "before", "type": "filter" },
      \     "before_action": { "keyword": "before", "type": "filter" }
      \   }
      \ },
      \ "app/models/*.rb": {
      \   "command": "model",
      \   "test": "spec/models/"
      \ },
      \ "app/views/**/*.erb": {
      \   "command": "view",
      \   "test": "spec/views/",
      \   "alternate": "spec/views/%s/_%f"
      \ },
      \ "config/routes.rb": {
      \   "command": "routes",
      \   "keywords": {
      \     "get ": { "keyword": "route", "search": "config/routes.rb" },
      \     "post ": { "keyword": "route", "search": "config/routes.rb" },
      \     "put ": { "keyword": "route", "search": "config/routes.rb" },
      \     "patch ": { "keyword": "route", "search": "config/routes.rb" },
      \     "delete ": { "keyword": "route", "search": "config/routes.rb" }
      \   }
      \ },
      \ "db/migrate/*.rb": {
      \   "command": "migration",
      \   "test": "spec/migrations/"
      \ },
      \ "spec/*_spec.rb": {
      \   "command": "spec",
      \   "alternate": "app/%s"
      \ }
      \ }

nmap <leader>Ra :Rails<CR>

"--- ALE settings ------------------------------------------------------"
"ALE now works alongside vim-lsp (vim-lsp handles LSP, ALE handles linting)"

"Show linting errors with highlights"
"* Can also be viewed in the loclist with :lope"
let g:ale_set_signs = 1
let g:ale_set_highlights = 1
let g:ale_virtualtext_cursor = 1

"Custom error/warning symbols
let g:ale_sign_error = '✗'
let g:ale_sign_warning = '⚠'

highlight ALEError ctermbg=none cterm=underline
highlight ALEWarning ctermbg=none cterm=underline

"Define when to lint"
let g:ale_lint_on_save = 1
let g:ale_lint_on_insert_leave = 1
let g:ale_lint_on_text_change = 'never'

"Set linters for individual filetypes"
let g:ale_linters_explicit = 1
let g:ale_linters = {
    \ 'go': ['gofmt', 'gopls', 'govet', 'gobuild'],
    \ 'python': ['ruff', 'mypy', 'pylsp'],
    \ 'ruby': ['rubocop', 'ruby'],
    \ 'javascript': ['eslint'],
    \ 'typescript': ['eslint', 'tsserver'],
    \ 'sh': ['shellcheck'],
    \ 'dockerfile': ['hadolint'],
    \ }
"Specify fixers for individual filetypes"
let g:ale_fixers = {
    \ '*': ['trim_whitespace'],
    \ 'python': ['ruff'],
    \ 'ruby': ['rubocop', 'rufo'],
    \ 'go': ['gopls', 'goimports', 'gofmt', 'gotype', 'govet'],
    \ 'javascript': ['eslint', 'prettier'],
    \ 'typescript': ['eslint', 'prettier'],
    \ 'json': ['jq', 'fixjson'],
    \ 'sh': ['shfmt'],
    \ }
"Don't warn about trailing whitespace, as it is auto-fixed by '*' above"
let g:ale_warn_about_trailing_whitespace = 0
"Show info, warnings, and errors; Write which linter produced the message"
let g:ale_lsp_show_message_severity = 'information'
let g:ale_echo_msg_format = '[%linter%] [%severity%:%code%] %s'
"Specify Containerfiles as Dockerfiles"
let g:ale_linter_aliases = {"Containerfile": "dockerfile"}

"Navigation mappings for errors"
nmap ]e <Plug>(ale_next_wrap)
nmap [e <Plug>(ale_previous_wrap)

"Toggle ALE"
nnoremap <leader>at :ALEToggle<CR>

"Mapping to run fixers on file"
nnoremap <leader>L :ALEFix<CR>

"--- Vim Test settings -----------------------------------------------"
nnoremap <leader>tn :TestNearest<CR>
nnoremap <leader>tf :TestFile<CR>
nnoremap <leader>ts :TestSuite<CR>
nnoremap <leader>tl :TestLast<CR>

let test#strategy = "dispatch"

"--- Github Copilot settings -----------------------------------------------"
let g:copilot_filetypes = {
  \ '*': v:false,
  \ 'python': v:true,
  \ 'javascript': v:true,
  \ 'typescript': v:true,
  \ 'ruby': v:true,
  \ 'go': v:true,
  \ 'cpp': v:true,
  \ 'c': v:true,
  \ }

"--- Vimspector settings -----------------------------------------------"
let g:vimspector_enable_mappings='HUMAN'
" mnemonic 'di' = 'debug inspect' (pick your own, if you prefer!)
" for normal mode - the word under the cursor
nmap <Leader>di <Plug>VimspectorBalloonEval
" for visual mode, the visually selected text
xmap <Leader>di <Plug>VimspectorBalloonEval
command! VR :VimspectorReset

"--- WhichKey settings ---------------------------------------------"
"Put this before any of the other plugin-specific config"
let g:mapleader = "\\"
nnoremap <silent> <leader> :<c-u>WhichKey '\'<CR>
set timeoutlen=200

"--- FZF settings ------------------------------------------------------
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-s': 'split',
  \ 'ctrl-v': 'vsplit'
  \ }
let g:fzf_colors = {
  \ 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'Normal'],
  \ 'bg+':     ['bg', 'Normal'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment']
  \ }
nnoremap <leader>ff :Files<CR>
nnoremap <leader>fg :Rg<CR>
nnoremap <leader>fb :Buffers<CR>
nnoremap <leader>fh :Helptags<CR>


"--- Gutentags confs ----------------------------------------------------
let g:gutentags_cache_dir = '~/.tags'
let g:gutentags_ctags_exclude = [
      \ '*.git', '*.svg', '*.hg',
      \ '*/tests/*',
      \ 'build',
      \ 'dist',
      \ '*sites/*/files/*',
      \ 'bin',
      \ 'node_modules',
      \ 'bower_components',
      \ 'cache',
      \ 'compiled',
      \ 'docs',
      \ 'example',
      \ 'bundle',
      \ 'vendor',
      \ '*.md',
      \ '*-lock.json',
      \ '*.lock',
      \ '*bundle*.js',
      \ '*build*.js',
      \ '.*rc*',
      \ '*.json',
      \ '*.min.*',
      \ '*.map',
      \ '*.bak',
      \ '*.zip',
      \ '*.pyc',
      \ '*.class',
      \ '*.sln',
      \ '*.Master',
      \ '*.csproj',
      \ '*.tmp',
      \ '*.csproj.user',
      \ '*.cache',
      \ '*.pdb',
      \ 'tags*',
      \ 'cscope.*',
      \ '*.css',
      \ '*.less',
      \ '*.scss',
      \ '*.exe', '*.dll',
      \ '*.mp3', '*.ogg', '*.flac',
      \ '*.swp', '*.swo',
      \ '*.bmp', '*.gif', '*.ico', '*.jpg', '*.png',
      \ '*.rar', '*.zip', '*.tar', '*.tar.gz', '*.tar.xz', '*.tar.bz2',
      \ '*.pdf', '*.doc', '*.docx', '*.ppt', '*.pptx',
      \ ]

"--- Backup and swap file settings ------------------------------------
set backupdir=~/.tmp,~/tmp,/var/tmp,/tmp
set backupskip=/tmp/*,/private/tmp/*
set directory=~/.tmp,~/tmp,/var/tmp,/tmp

"--- Python specific configs ---------------------------------------------
au BufNewFile,BufRead *.py
    \ set tabstop=4 |
    \ set softtabstop=4 |
    \ set shiftwidth=4 |
    \ set textwidth=100 |
    \ set expandtab |
    \ set autoindent |
    \ set fileformat=unix |

"--- Autoreload .vimrc ----------------------------------------------------
augroup myvimrc
    au!
    au BufWritePost .vimrc,_vimrc,vimrc,.gvimrc,_gvimrc,gvimrc so $MYVIMRC | if has('gui_running') | so $MYGVIMRC | endif
augroup END

"--- Format JSON files ----------------------------------------------------
command! FormatJson execute "%!python -m json.tool"
