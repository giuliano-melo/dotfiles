unlet! skip_defaults_vim
source $VIMRUNTIME/defaults.vim

syntax on
filetype  plugin indent on

set hlsearch incsearch ignorecase
set number relativenumber
set encoding=UTF-8

nnoremap <leader>c :botright term<CR>

call plug#begin('~/.vim/plugged')
  Plug 'prabirshrestha/async.vim'
  Plug 'prabirshrestha/vim-lsp'
  Plug 'airblade/vim-gitgutter'
  Plug 'Raimondi/delimitMate'
  Plug 'sheerun/vim-polyglot'
  Plug 'mattn/emmet-vim'
  Plug 'nathanaelkane/vim-indent-guides'
  Plug 'bling/vim-airline'
  Plug 'editorconfig/editorconfig-vim'
  Plug 'ludovicchabant/vim-gutentags'
  Plug 'ctrlpvim/ctrlp.vim'
  Plug 'sickill/vim-monokai'
  Plug 'dense-analysis/ale'
  Plug 'liuchengxu/vim-which-key'
  Plug 'vim-test/vim-test', {'requires': 'tpope/vim-dispatch'}
  Plug 'github/copilot.vim'
  Plug 'puremourning/vimspector'
call plug#end()

"--- vim-lsp configuration ---------------------------------------------
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

"Mappings for most-used functions are set in s:on_lsp_buffer_enabled()

"--- ALE settings ------------------------------------------------------"
"ALE now works alongside vim-lsp (vim-lsp handles LSP, ALE handles linting)

"Show linting errors with highlights"
"* Can also be viewed in the loclist with :lope"
let g:ale_set_signs = 1
let g:ale_set_highlights = 1
let g:ale_virtualtext_cursor = 1
highlight ALEError ctermbg=none cterm=underline

"Define when to lint"
let g:ale_lint_on_save = 1
let g:ale_lint_on_insert_leave = 1
let g:ale_lint_on_text_change = 'never'

"Set linters for individual filetypes"
let g:ale_linters_explicit = 1
let g:ale_linters = {
    \ 'go': ['gofmt', 'gopls', 'govet', 'gobuild'],
    \ 'python': ['ruff', 'mypy', 'pylsp'],
\ }
"Specify fixers for individual filetypes"
let g:ale_fixers = {
    \ '*': ['trim_whitespace'],
    \ 'python': ['ruff'],
    \ 'go': ['gopls', 'goimports', 'gofmt', 'gotype', 'govet'],
\ }
"Don't warn about trailing whitespace, as it is auto-fixed by '*' above"
let g:ale_warn_about_trailing_whitespace = 0
"Show info, warnings, and errors; Write which linter produced the message"
let g:ale_lsp_show_message_severity = 'information'
let g:ale_echo_msg_format = '[%linter%] [%severity%:%code%] %s'
"Specify Containerfiles as Dockerfiles"
let g:ale_linter_aliases = {"Containerfile": "dockerfile"}

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

"set exrc
"set secure
"syntax enable
"set nocompatible                " choose no compatibility with legacy vi
"set encoding=utf-8
"set showcmd                     " display incomplete commands
"set showmatch                   " highlight matching [{()}]}]"
"
"set colorcolumn=100
"set cursorline
"set hidden
"set number
"set wildmenu                    " visual autocomplete for command menu"
"set lazyredraw                  " redraw only when we need to."
"
"filetype on                     " Enable filetype detection
"filetype indent on              " Enable filetype-specific indenting
"filetype plugin on              " Enable filetype-specific plugins
"
""" Whitespace
"set nowrap                      " don't wrap lines
"set tabstop=2 shiftwidth=2      " a tab is two spaces (or set this to 4)
"set softtabstop=2
"set expandtab                   " use spaces, not tabs (optional)
"set backspace=indent,eol,start  " backspace through everything in insert mode
"
""" Searching
"set hlsearch                    " highlight matches
"set incsearch                   " incremental searching
"set ignorecase                  " searches are case insensitive...
"set smartcase                   " ... unless they contain at least one capital letter
"
"" Enable folding
"set foldmethod=indent
"set foldlevel=99
"
"set laststatus=2
" Enable the list of buffers
let g:airline#extensions#tabline#enabled = 1
" " Show just the filename
let g:airline#extensions#tabline#fnamemod = ':t'

let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_start_level=2
let g:indent_guides_guide_size=1

" leader = \
" CoC extensions
"let g:coc_global_extensions = ['coc-tsserver']
"" Remap keys for applying codeAction to the current line.
"nmap <leader>ac  <Plug>(coc-codeaction)
"" Apply AutoFix to problem on the current line.
"nmap <leader>qf  <Plug>(coc-fix-current)
"" GoTo code navigation.
"nmap <silent> gd <Plug>(coc-definition)
"nmap <silent> gy <Plug>(coc-type-definition)
"nmap <silent> gi <Plug>(coc-implementation)
"nmap <silent> gr <Plug>(coc-references)
"" Use `[g` and `]g` to navigate diagnostics
"" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list
"nmap <silent> [g <Plug>(coc-diagnostic-prev)
"nmap <silent> ]g <Plug>(coc-diagnostic-next)
"" Formatting selected code
"xmap <leader>f  <Plug>(coc-format-selected)
"nmap <leader>f  <Plug>(coc-format-selected)
"
"inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
"inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
"                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
"" Use K to show documentation in preview window
"nnoremap <silent> K :call ShowDocumentation()<CR>
"
"function! ShowDocumentation()
"  if CocAction('hasProvider', 'hover')
"    call CocActionAsync('doHover')
"  else
"    call feedkeys('K', 'in')
"  endif
"endfunction


" Gutentags confs
let g:gutentags_cache_dir = '~/.tags'
set statusline+=%{gutentags#statusline()}
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

set t_Co=256
colorscheme monokai

" Generate backup files outside current dir
set backupdir=~/.tmp,~/tmp,/var/tmp,/tmp
set backupskip=/tmp/*,/private/tmp/*
set directory=~/.tmp,~/tmp,/var/tmp,/tmp

" Remove trailing whitespaces
autocmd BufWritePre * :%s/\s\+$//e

" Python specific configs
au BufNewFile,BufRead *.py
    \ set tabstop=4 |
    \ set softtabstop=4 |
    \ set shiftwidth=4 |
    \ set textwidth=100 |
    \ set expandtab |
    \ set autoindent |
    \ set fileformat=unix |

" Autoreload .vimrc
augroup myvimrc
    au!
    au BufWritePost .vimrc,_vimrc,vimrc,.gvimrc,_gvimrc,gvimrc so $MYVIMRC | if has('gui_running') | so $MYGVIMRC | endif
augroup END

" Format JSON files
command! FormatJson execute "%!python -m json.tool"

" Prettier command
"command! -nargs=0 Prettier :CocCommand prettier.formatFile
