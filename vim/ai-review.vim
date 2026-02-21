" AI Review Workflow for Vim
" Place in ~/.vimrc or source from it: source ~/.vim/review-workflow.vim

" ---------------------------------------------------------------
" Helper: get leading whitespace of a line number
" ---------------------------------------------------------------
function! s:GetIndent(lnum)
  return matchstr(getline(a:lnum), '^\s*')
endfunction

" ---------------------------------------------------------------
" <leader>ar (normal) — insert # REVIEW: above current line
" ---------------------------------------------------------------
function! s:AddSingleReview()
  let l:lnum = line('.')
  let l:indent = s:GetIndent(l:lnum)
  call append(l:lnum - 1, l:indent . '# REVIEW: ')
  call cursor(l:lnum, len(l:indent) + 11)
  startinsert!
endfunction

nnoremap <leader>ar :call <SID>AddSingleReview()<CR>

" ---------------------------------------------------------------
" <leader>ar (visual) — wrap selection with START / END block
" ---------------------------------------------------------------
function! s:AddMultiReview() range
  let l:start = a:firstline
  let l:end   = a:lastline
  let l:indent = s:GetIndent(l:start)

  " Insert END first so line numbers stay valid for START insert
  call append(l:end, l:indent . '# REVIEW: END')
  call append(l:start - 1, l:indent . '# REVIEW: START ')

  " Land cursor at end of START line in insert mode
  call cursor(l:start, len(l:indent) + 17)
  startinsert!
endfunction

vnoremap <leader>ar :call <SID>AddMultiReview()<CR>

" ---------------------------------------------------------------
" <leader>as (normal) — extract reviews and pipe to agent
" ---------------------------------------------------------------
function! s:SendReviews()
  let l:file = expand('%:p')
  if l:file ==# ''
    echohl WarningMsg | echo 'No file open' | echohl None
    return
  endif
  let l:agent = input('Agent (claude/kiro): ', 'claude -p')
  if l:agent ==# ''
    return
  endif
  let l:cmd = printf(
    \ 'extract-vim-comment-reviews.sh "%s" | %s "Fix the following review comments in %s:"',
    \ l:file, l:agent, l:file)
  execute 'split | terminal ' . l:cmd
endfunction

nnoremap <leader>as :call <SID>SendReviews()<CR>

" ---------------------------------------------------------------
" <leader>ac (normal) — strip all # REVIEW: lines from buffer
" ---------------------------------------------------------------
function! s:ClearReviews()
  let l:before = line('$')
  global/^\s*# REVIEW:/delete
  let l:removed = l:before - line('$')
  echo 'Removed ' . l:removed . ' review comment line(s)'
endfunction

nnoremap <leader>ac :call <SID>ClearReviews()<CR>
