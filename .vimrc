call plug#begin('~/.vim/plugged')
    Plug 'scrooloose/syntastic'
    Plug 'airblade/vim-gitgutter'
    Plug 'Raimondi/delimitMate'
    Plug 'Valloric/YouCompleteMe'
    Plug 'vim-ruby/vim-ruby'
    Plug 'tpope/vim-rails'
    Plug 'tpope/vim-bundler'
    Plug 'ngmy/vim-rubocop'
    Plug 'pangloss/vim-javascript'
    Plug 'marijnh/tern_for_vim'
    Plug 'helino/vim-json'
    Plug 'nathanaelkane/vim-indent-guides'
    Plug 'mattn/emmet-vim'
    Plug 'fatih/vim-go'
    Plug 'derekwyatt/vim-scala'
    Plug 'bling/vim-airline'
    Plug 'editorconfig/editorconfig-vim'
    Plug 'nvie/vim-flake8'
    Plug 'sickill/vim-monokai'
    Plug 'craigemery/vim-autotag'
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

"" Whitespace
set nowrap                      " don't wrap lines
set tabstop=4 shiftwidth=4      " a tab is two spaces (or set this to 4)
set softtabstop=4
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

" set tags=~/.tags

set laststatus=2
" Enable the list of buffers
let g:airline#extensions#tabline#enabled = 1
" " Show just the filename
let g:airline#extensions#tabline#fnamemod = ':t'

set t_Co=256
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

