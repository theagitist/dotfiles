" Set encoding first (some plugins check on init)
set encoding=UTF-8

" Set leader key (default \)
let mapleader = "\<Space>"

call plug#begin('~/.vim/plugged')

Plug 'ryanoasis/vim-devicons'
Plug 'frazrepo/vim-rainbow'
Plug 'vim-python/python-syntax'
Plug 'ap/vim-css-color'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-fugitive'
Plug 'vim-airline/vim-airline'
Plug 'neoclide/coc.nvim', { 'branch': 'release' }
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'mbbill/undotree'
Plug 'dracula/vim', { 'as': 'dracula' }
Plug 'leafgarland/typescript-vim'
Plug 'vim-utils/vim-man'
Plug 'preservim/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'PhilRunninger/nerdtree-buffer-ops'
Plug 'PhilRunninger/nerdtree-visual-selection'
Plug 'goerz/jupytext.vim'
Plug 'psliwka/vim-smoothie'

call plug#end()

filetype plugin indent on

"Remap ESC to jk
:imap jk <Esc>

" Git (vim-fugitive) key bindings
nmap <leader>gs :G<CR>
nmap <leader>gh :diffget //3<CR>
nmap <leader>gd :diffget //2<CR>

" Set color scheme
colorscheme dracula

" Cursor visibility
set cursorline
set cursorcolumn
highlight CursorLine   cterm=NONE ctermbg=236 guibg=#3a3d4d
highlight CursorColumn cterm=NONE ctermbg=236 guibg=#3a3d4d
highlight CursorLineNr cterm=bold ctermfg=228 guifg=#f1fa8c gui=bold

" Brighter visual selection so the cursor stands out inside it
highlight Visual ctermbg=60 guibg=#5f5f87 guifg=NONE cterm=NONE gui=NONE

" Terminal cursor shape per mode (blinking block / bar / underline)
" Use 2/4/6 instead of 1/3/5 for steady variants
let &t_SI = "\e[5 q"  " insert  -> blinking bar
let &t_SR = "\e[3 q"  " replace -> blinking underline
let &t_EI = "\e[1 q"  " normal  -> blinking block
augroup ResetCursorShape
  autocmd!
  autocmd VimEnter * silent !echo -ne "\e[1 q"
  autocmd VimLeave * silent !echo -ne "\e[5 q"
augroup END

" Always show statusline
set laststatus=2

syntax enable
set number relativenumber
let g:rehash256 = 1

" Use spaces instead of tabs
set expandtab

" Use smart tabs
set smarttab

" 1 tab = 4 spaces
set shiftwidth=4
set tabstop=4 softtabstop=4

" Splits and Tabbed Files
set splitbelow
set splitright

set hidden
set wildmenu
set wildignore+=**/node_modules/**
set incsearch
set hlsearch
set nobackup
set noswapfile
set noerrorbells
set scrolloff=8
set autoread
autocmd FocusGained,CursorHold * checktime
set smoothscroll

" Smooth scrolling (vim-smoothie)
let g:smoothie_speed_constant_factor = 15
let g:smoothie_speed_linear_factor = 15
let g:smoothie_speed_exponentiation_factor = 0.8
set signcolumn=yes
set backspace=indent,eol,start
set smartindent
set nowrap

" Persistent undo
silent !mkdir -p ~/.vim/undodir
set undodir=~/.vim/undodir
set undofile

let g:netrw_browse_split=2
let g:netrw_banner=0
let g:netrw_winsize=25

set colorcolumn=80
highlight ColorColumn ctermbg=0 guibg=lightgray

let g:python_highlight_all=1

" Return to last edit position when opening file
autocmd BufReadPost *
     \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif

" Remap splits navigation to just CTRL + hjkl
noremap <C-h> <C-w>h
noremap <C-j> <C-w>j
noremap <C-k> <C-w>k
noremap <C-l> <C-w>l

" Enhance adjusting split sizes
noremap <Left> :vertical resize -3<CR>
noremap <Right> :vertical resize +3<CR>
noremap <Up> :resize -3<CR>
noremap <Down> :resize +3<CR>

" Change splits from h to v or v to h
map <Leader>th <C-w>t<C-w>H
map <Leader>tk <C-w>t<C-w>K

" Removes pipes | that act as separators on splits
set fillchars+=vert:\

" Clear search highlights
nnoremap <leader><space> :nohlsearch<CR>

" fzf
nnoremap <C-p> :Files<Cr>

let g:coc_node_path = split(globpath(expand('~/.nvm/versions/node'), '*/bin/node'), "\n")[-1]

" Remaps for coc.nvim
nmap <silent> <leader>cd <Plug>(coc-definition)
nmap <silent> <leader>cr <Plug>(coc-references)
nmap <silent> <leader>cf <Plug>(coc-fix-current)
nmap <silent> <leader>ca <Plug>(coc-codeaction)
nmap <silent> <leader>cn <Plug>(coc-rename)

" coc.nvim tab completion
inoremap <silent><expr> <TAB> coc#pum#visible() ? coc#pum#next(1) : "\<TAB>"
inoremap <silent><expr> <S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<CR>"
inoremap <silent><expr> <C-e> coc#pum#visible() ? coc#pum#cancel() : "\<C-e>"

" Shift+(K|J) move block (up|down)
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Half-page scroll with J/K (via smoothie)
nmap J <Plug>(SmoothieDownwards)
nmap K <Plug>(SmoothieUpwards)
nnoremap <leader>j J

" Scroll faster
nnoremap <C-e> 2<C-e>
nnoremap <C-y> 2<C-y>
nnoremap <C-Down> 2<C-e>
nnoremap <C-Up> 2<C-y>
nnoremap <C-Left> b
nnoremap <C-Right> w

" NERDTree
nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-f> :NERDTreeFind<CR>

" Other key mappings
nnoremap <silent> <leader>pv :wincmd v<bar> :Ex <bar> :vertical resize 30<CR>
nnoremap <leader>u :UndotreeToggle<CR>
