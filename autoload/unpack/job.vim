" TODO: handle real error cases (check exit code. stderr output doesn't mean
" error in general)
" TODO: should probably switch to dictionary functions to avoid script-global
" vars
let s:line_offset = 0

function! unpack#job#start(name, cmd, exit_cb)
  let l:state = {
        \ 'exit_cb': a:exit_cb,
        \ 'name': a:name,
        \ 'line_offset': s:line_offset,
        \ 'stdout': [],
        \ 'stderr': [],
        \ 'error': v:false
        \ }
  let s:line_offset += 1
  if has('nvim')  " neovim
    let l:job = {
          \ 'on_stdout': function('s:to_buf'),
          \ 'on_stderr': function('s:to_buf'),
          \ 'on_exit': function('s:nvim_job_exit'),
          \ }
    let l:job_id = jobstart(a:cmd, l:job)
    let g:unpack#jobs[l:job_id] = l:state
    " TODO: check status after launching job and propagate errors if necessary
  elseif v:version >= 800  "vim8
    let l:options = {
          \ 'out_cb': function('s:to_buf'),
          \ 'err_cb': function('s:to_buf'),
          \ 'exit_cb': function('s:vim_job_exit'),
          \ 'err_mode': 'raw',
          \ 'out_mode': 'raw'
          \ }
    let l:cmd = unpack#platform#cmd(a:cmd)
    let l:job_id = job_start(l:cmd, l:options)
    let g:unpack#jobs[l:job_id] = l:state
    " TODO: check status after launching job and propagate errors if necessary
  else
    echohl ErrorMsg
    echom 'Unpack requires neovim or vim version 8 or above'
    echohl NONE
    finish
  endif
  call unpack#ui#incr_cnt()
  call unpack#ui#update(l:state.line_offset, l:state.name, [''])
endfunction

function! s:to_buf(job_id, text, event) dict
  let l:job = g:unpack#jobs[a:job_id]
  call unpack#ui#update(l:job.line_offset, l:job.name, a:text)
  call add(l:job.stdout, a:text)
endfunction

function! s:nvim_job_exit(job_id, data, event) dict
  let l:job = g:unpack#jobs[a:job_id]
  if !l:job.error
    call l:job.exit_cb()
  endif
  call unpack#ui#update(l:job.line_offset, l:job.name, ['Done'])
  call unpack#ui#update_progress_bar()
  unlet g:unpack#jobs[a:job_id]
  if empty(g:unpack#jobs)
    call unpack#ui#prepare_to_exit()
    let s:line_offset = 0
  endif
endfunction
