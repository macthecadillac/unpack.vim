function! unpack#util#is_optional(name)
  let l:spec = s:configuration.packages[a:name]
  return !empty(l:spec.ft) || !empty(l:spec.cmd) || !empty(l:spec.event)
endfunction
