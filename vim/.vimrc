" ---- Basics ----
scriptencoding utf-8
set encoding=utf-8
syntax on                  " color-coded syntax highlighting
filetype plugin indent on  " per-filetype plugins + indent rules

set number                 " show line numbers
set relativenumber         " relative numbers above/below cursor (fast jumps: 5j, 3k)

" ---- Indentation: 2 spaces everywhere, smart auto-indent ----
set tabstop=2 shiftwidth=2 softtabstop=2
set expandtab               " spaces, not tabs
set smartindent             " context-aware indent for C-like/lua/etc
set autoindent              " fallback: copy indent from current line

" yaml is picky about tabs vs spaces; keep it explicit even though it's
" the same as the global default above
autocmd FileType yaml,lua setlocal tabstop=2 shiftwidth=2 expandtab

" ---- Quality of life ----
set ignorecase smartcase     " case-insensitive search, unless you type a capital
set incsearch hlsearch       " highlight as you type, keep matches lit
set hidden                   " switch buffers without saving first
set wildmenu                 " tab-complete menu for :commands and file paths
set scrolloff=5              " keep 5 lines of context above/below cursor
set noswapfile nobackup      " skip swap/backup clutter for a single-user machine
set undofile                 " persistent undo across sessions
set undodir=~/.vim/undodir
set list listchars=tab:>\ ,trail:.   " show tabs/trailing whitespace (ASCII, no encoding surprises)
set laststatus=2             " always show statusline (buffer name, position)
set mouse=a                  " optional: mouse support for scroll/resize

let g:DirDiffExcludes = ".git"
