set hlsearch    " highlight all search results
set ignorecase  " do case insensitive search
set incsearch   " show incremental search results as you type
set number relativenumber      " display hybrid line number (rel and abs)
set noswapfile  " disable swap file
set nocompatible    " disable vi compatibility

" Y yanks to end of line. similar to C and D
nnoremap Y y$

" zz to center and zv to open fold when moving next and previous
nnoremap n nzzzv
nnoremap N Nzzzv

" restore cursor position after joining lines with J
nnoremap J mzJ`z

" Break undo into smaller chunks
inoremap , ,<c-g>u
inoremap . .<c-g>u
inoremap ! !<c-g>u
inoremap ? ?<c-g>u
inoremap <Space> <Space><c-g>u
inoremap <Enter> <Enter><c-g>u