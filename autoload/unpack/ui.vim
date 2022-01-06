" TODO: should probably switch to dictionary functions to avoid script-global
" vars
let s:jobs = 0
let s:progress = -1

function! unpack#ui#update(offset, name, text)
  let l:offset = a:offset + 6
  call nvim_set_current_buf(s:buf_id)
  set modifiable
  let l:line_count = nvim_buf_line_count(s:buf_id)
  if l:line_count <= l:offset
    let l:n = l:offset - l:line_count + 1
    call nvim_buf_set_lines(s:buf_id, l:line_count - 1, l:line_count - 1, v:true, repeat([''], l:n))
  endif
  call nvim_buf_set_lines(s:buf_id, l:offset - 1, l:offset, v:true, s:format(a:name, a:text))
  set nomodifiable
endfunction

function! unpack#ui#incr_cnt()
  let s:jobs += 1
endfunction

function! unpack#ui#update_progress_bar()
  let s:progress += 1
  let l:nbars = (s:win_width - 8) * (s:jobs ? s:progress : 0) / (s:jobs ? s:jobs : 1)
  let l:spaces = s:win_width - l:nbars - 8
  call nvim_set_current_buf(s:buf_id)
  set modifiable
  let l:line_count = nvim_buf_line_count(s:buf_id)
  if l:line_count <= 3
    call nvim_buf_set_lines(s:buf_id, 0, 0, v:true, ['', '', '   [' . join(repeat(['='], l:nbars), '') . join(repeat([''], l:spaces)) . ']'])
  else
    call nvim_buf_set_lines(s:buf_id, 2, 3, v:true, ['   [' . join(repeat(['='], l:nbars), '') . join(repeat([''], l:spaces)) . ']'])
  endif
  set nomodifiable
  call nvim_win_set_cursor(s:win_id, [1, 0])
endfunction

function! unpack#ui#new_window()
  if !exists('s:win_id')
    let s:buf_id = nvim_create_buf(v:false, v:true)
    let s:win_width = float2nr(str2nr(&columns) * 0.8)
    let l:height = float2nr(str2nr(&lines) * 0.8)
    let l:row = (str2nr(&lines) - l:height) / 2
    let l:col = (str2nr(&columns) - s:win_width) / 2
    let l:opts = {
          \ 'anchor': 'NW',
          \ 'style': 'minimal',
          \ 'relative': 'editor',
          \ 'width': s:win_width,
          \ 'height': l:height,
          \ 'row': l:row,
          \ 'col': l:col,
          \ 'focusable': v:true,
          \ }
    let s:win_id = nvim_open_win(s:buf_id, v:true, l:opts)
  endif
  call unpack#ui#update_progress_bar()
endfunction

function! unpack#ui#close_window()
  call nvim_win_close(s:win_id, v:true)
  call execute(['bwipeout', s:buf_id])
  unlet s:win_id
  unlet s:buf_id
  " clear commandline
  echom ''
endfunction

function! unpack#ui#prepare_to_exit()
  let l:line_count = nvim_buf_line_count(s:buf_id)
  call nvim_set_current_buf(s:buf_id)
  nmap <buffer> q :call unpack#ui#close_window()<CR>
  set modifiable
  call nvim_buf_set_lines(s:buf_id, 3, 4, v:true, ['   Press q to exit'])
  set nomodifiable
  let s:jobs = 0
  let s:progress = -1
  unlet s:win_width
endfunction

function! s:format(name, text)
  let l:text = a:name . ': ' . join(a:text)
  let l:max_width = str2nr(&columns) - 6
  if len(l:text) > l:max_width
    return ['   ' . l:text[:l:max_width - 1] . '…']
  endif
  return ['   ' . l:text]
endfunction
