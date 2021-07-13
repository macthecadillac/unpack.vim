function! unpack#platform#join(...)
  if (has('win32') || has('win64')) && !(has('win32unix') || has('win64unix'))
    return join(a:000, '\')
  else
    return join(a:000, '/')
  endif
endfunction

function! unpack#platform#split(path)
  if (has('win32') || has('win64')) && !(has('win32unix') || has('win64unix'))
    return split(a:path, '\')
  else
    return split(a:path, '/')
  endif
endfunction

function! unpack#platform#cmd(...)
  if has('win32') || has('win64')
    return join(a:000, ' ')
  else
    return a:000
  endif
endfunction

function! unpack#platform#config_path()
  return exists('*stdpath') ? stdpath('config') : split(&rtp, ',')[0]
endfunction

function! unpack#platform#move(origin, dest)
  if (has('win32') || has('win64')) && !(has('win32unix') || has('win64unix'))
    call system(join(['move', a:origin, a:dest]))
  else
    call system(join(['mv', a:origin, a:dest]))
  endif
endfunction

function! unpack#platform#ls(path)
  return map(split(globpath(a:path, '*'), '\n'), {_, s -> unpack#platform#split(s)[-1]})
endfunction

function! unpack#platform#ln(origin, dest)
  if (has('win32') || has('win64')) && !(has('win32unix') || has('win64unix'))
    call system(join(['mklink', '/D', a:origin, a:dest]))
  else
    call system(join(['ln', '-s', a:origin, a:dest]))
  endif
endfunction

function! unpack#platform#opt_path()
  return unpack#platform#join(g:unpack#packpath, 'pack', 'unpack', 'opt')
endfunction

function! unpack#platform#start_path()
  return unpack#platform#join(g:unpack#packpath, 'pack', 'unpack', 'start')
endfunction
