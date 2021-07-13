" for testing only
function! unpack#ui#echom(msg)
  echom a:msg
endfunction

" for testing only
function! unpack#ui#echom_err(msg)
  echohl ErrorMsg
  echom a:msg
  echohl NONE
endfunction
