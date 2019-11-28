call plug#begin('~/.vim/plugged')
  "Plug 'scrooloose/syntastic'
  Plug 'airblade/vim-gitgutter'
  Plug 'Raimondi/delimitMate'
  "Plug 'vim-ruby/vim-ruby'
  "Plug 'tpope/vim-rails'
  "Plug 'tpope/vim-bundler'
  "Plug 'ngmy/vim-rubocop'
  "Plug 'pangloss/vim-javascript'
  Plug 'ternjs/tern_for_vim', {'do': 'npm install'}
  "Plug 'jparise/vim-graphql'
  "Plug 'dense-analysis/ale'
  "Plug 'leafgarland/typescript-vim'
  Plug 'ianks/vim-tsx'
  "Plug 'mxw/vim-jsx'
  Plug 'sheerun/vim-polyglot'
  Plug 'Quramy/tsuquyomi'
  "Plug 'elzr/vim-json'
  "Plug 'artur-shaik/vim-javacomplete2'
  Plug 'nvie/vim-flake8'
  Plug 'mattn/emmet-vim'
  Plug 'nathanaelkane/vim-indent-guides'
  Plug 'bling/vim-airline'
  Plug 'editorconfig/editorconfig-vim'
  Plug 'ludovicchabant/vim-gutentags'
  Plug 'ctrlpvim/ctrlp.vim'
  "Plug 'ajh17/VimCompletesMe'
  Plug 'neoclide/coc.nvim', {'branch': 'release'}
  Plug 'sickill/vim-monokai'
  Plug 'dracula/vim'
call plug#end()

set exrc
set secure
syntax enable
set nocompatible                " choose no compatibility with legacy vi
set encoding=utf-8
set showcmd                     " display incomplete commands
set showmatch                   " highlight matching [{()}]}]"

set colorcolumn=100
set cursorline
set hidden
set number
set wildmenu                    " visual autocomplete for command menu"
set lazyredraw                  " redraw only when we need to."

filetype on                     " Enable filetype detection
filetype indent on              " Enable filetype-specific indenting
filetype plugin on              " Enable filetype-specific plugins
"set omnifunc=syntaxcomplete#Complete
" Syntastic stuff
autocmd FileType vim let b:vcm_tab_complete = 'vim'
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0


"" Whitespace
set nowrap                      " don't wrap lines
set tabstop=2 shiftwidth=2      " a tab is two spaces (or set this to 4)
set softtabstop=2
set expandtab                   " use spaces, not tabs (optional)
set backspace=indent,eol,start  " backspace through everything in insert mode

"" Searching
set hlsearch                    " highlight matches
set incsearch                   " incremental searching
set ignorecase                  " searches are case insensitive...
set smartcase                   " ... unless they contain at least one capital letter

" Enable folding
set foldmethod=indent
set foldlevel=99

set laststatus=2
" Enable the list of buffers
let g:airline#extensions#tabline#enabled = 1
" " Show just the filename
let g:airline#extensions#tabline#fnamemod = ':t'

let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_start_level=2
let g:indent_guides_guide_size=1

" Clojure stuff
let g:clojure_maxlines = 100

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

" Typescript confs
let g:tsuquyomi_disable_quickfix = 1
let g:syntastic_typescript_checkers = ['tsuquyomi']

set t_Co=256
" color dracula
colorscheme monokai
" set background=dark
" colorscheme solarized

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

" Ale confs
let g:ale_fix_on_save = 1
let g:airline#extensions#ale#enabled = 1
let g:ale_set_highlights = 0

" Autoreload .vimrc
augroup myvimrc
    au!
    au BufWritePost .vimrc,_vimrc,vimrc,.gvimrc,_gvimrc,gvimrc so $MYVIMRC | if has('gui_running') | so $MYGVIMRC | endif
augroup END

" Format JSON files
command! FormatJson execute "%!python -m json.tool"
