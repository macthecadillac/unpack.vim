" TODO: should probably switch to dictionary functions to avoid script-global
" vars
let s:line_offset = 0

function! unpack#job#start(name, cmd, out_cb, err_cb, exit_cb)
  let l:state = {
        \ 'out_cb': a:out_cb,
        \ 'err_cb': a:err_cb,
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
          \ 'on_stdout': function('s:nvim_stdout'),
          \ 'on_stderr': function('s:nvim_stderr'),
          \ 'on_exit': function('s:nvim_job_exit'),
          \ }
    let l:job_id = jobstart(a:cmd, l:job)
    let g:unpack#jobs[l:job_id] = l:state
    " TODO: check status after launching job and propagate errors if necessary
  elseif v:version >= 800  "vim8
    let l:options = {
          \ 'out_cb': function('s:vim_stdout'),
          \ 'err_cb': function('s:vim_stderr'),
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
endfunction

function! s:vim_stdout(channel, data)
  let l:job = g:unpack#jobs[a:job_id]
  call l:job.out_cb(a:data)
  call add(l:job.stdout, a:data)
endfunction

function! s:vim_stderr(channel, data)
  let l:job = g:unpack#jobs[l:job_id]
  call l:job.err_cb(l:job.line_offset, l:job.name, a:data)
  let l:job.error = v:true
  call add(l:job.stderr, a:data)
endfunction

function! s:vim_job_exit(job, status)

endfunction

function! s:nvim_stdout(job_id, data, event) dict
  let l:job = g:unpack#jobs[a:job_id]
  call l:job.out_cb(a:data)
  call add(l:job.stdout, a:data)
endfunction

function! s:nvim_stderr(job_id, data, event) dict
  let l:job = g:unpack#jobs[a:job_id]
  call l:job.err_cb(l:job.line_offset, l:job.name, a:data)
  let l:job.error = v:true
  call add(l:job.stderr, a:data)
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
