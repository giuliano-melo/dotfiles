set exrc
set secure
syntax enable
set nocompatible                " choose no compatibility with legacy vi
set encoding=utf-8
set showcmd                     " display incomplete commands

set background=dark
colorscheme solarized
set t_Co=256

set colorcolumn=120
set cursorline
set hidden
set number

filetype on                     " Enable filetype detection
filetype indent on              " Enable filetype-specific indenting
filetype plugin on              " Enable filetype-specific plugins

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

set tags=./tags;

set laststatus=2
" Enable the list of buffers
 let g:airline#extensions#tabline#enabled = 1
" " Show just the filename
 let g:airline#extensions#tabline#fnamemod = ':t'

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
  Plug 'bling/vim-airline'
call plug#end()

