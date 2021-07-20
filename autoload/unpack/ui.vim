function! unpack#ui#update(offset, name, text)
  let l:offset = a:offset + 3
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

function! unpack#ui#new_window()
  if !exists('s:win_id')
    let s:buf_id = nvim_create_buf(v:false, v:true)
    let l:width = float2nr(str2nr(&columns) * 0.8)
    let l:height = float2nr(str2nr(&lines) * 0.8)
    let l:row = (str2nr(&lines) - l:height) / 2
    let l:col = (str2nr(&columns) - l:width) / 2
    let l:opts = {
          \ 'anchor': 'NW',
          \ 'style': 'minimal',
          \ 'relative': 'editor',
          \ 'width': l:width,
          \ 'height': l:height,
          \ 'row': l:row,
          \ 'col': l:col,
          \ 'focusable': v:true,
          \ }
    let s:win_id = nvim_open_win(s:buf_id, v:true, l:opts)
  endif
endfunction

function! unpack#ui#close_window()
  call nvim_win_close(s:win_id, v:true)
  call nvim_buf_delete(s:buf_id, {'force': v:true})
  unlet s:win_id
  unlet s:buf_id
endfunction

function! unpack#ui#prepare_to_exit()
  let l:line_count = nvim_buf_line_count(s:buf_id)
  call nvim_set_current_buf(s:buf_id)
  nmap <buffer> q :q<CR>
  set modifiable
  call nvim_buf_set_lines(s:buf_id, l:line_count, l:line_count, v:true, ['', '   Press q to exit'])
  set nomodifiable
endfunction

function! s:format(name, text)
  let l:text = a:name . ': ' . join(a:text)
  let l:max_width = str2nr(&columns) - 6
  if len(l:text) > l:max_width
    return ['   ' . l:text[:l:max_width - 1] . '…']
  endif
  return ['   ' . l:text]
endfunction
