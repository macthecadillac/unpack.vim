if exists('g:unpacked')
  finish
endif

let s:default_package_options = {
      \   'opt': v:false,
      \   'ft': [],
      \   'cmd': [],
      \   'event': [],
      \   'post-install': '',
      \   'before-load': '',
      \   'after-load' '',
      \ }

function! unpack#begin(path)
  let s:configuration = {}
  let s:configuration.packpath = a:path
  let s:configuration.packages = {}
endfunction

function! unpack#end()
endfunction

function! unpack#load(path, opts)
  if !exists('s:unpacked')
    echohl ErrorMsg
    echom 'Plug-in not initialized. Check your configuration. (Hint: did you call unpack#begin?)'
    echohl None
    finish
  endif

  let s:unpacked = v:true
  let l:name = s:extract_name(a:path)
  let l:full_path = s:get_full_path(a:path)
  if l:name[0] ==# 'ok' && l:full_path[0] ==# 'ok'
    let s:packages[l:name] = extend(deepcopy(s:default_package_options), a:opts)
    let s:packages[l:name].location = l:full_path[1][0]
    let s:packages[l:name].path = l:full_path[1][1]
    return ['ok']
  else
    return l:name
  endif
endfunction

function! unpack#compile()
endfunction

function! unpack#install()
endfunction

function! unpack#clean()
endfunction

function! unpack#update()
endfunction

function! s:extract_name(path)
  if stridx(a:path, '/') > 0
    if stridx(a:path, 'http:') ==# 1 || stridx(a:path, 'https:') ==# 1
      let repo = split(a:path, '/')[-1]
      if repo[-4:] ==# '.git'
        return ['ok', repo[:-4]]
      else
        return ['error', [a:path, 'not a valid git repo']]
      endif
    else  " not a url
      return ['ok', split(a:path, '/')[-1]]
    endif
  else
    return ['error', [a:path, 'not a valid entry']]
  endif
endfunction

function! s:get_full_path(path)
  if count(a:path, '/') ==# 1  " path for Github
    return ['ok', ['remote', 'https://github.com/' . a:path . '.git']]
  elseif count(a:path, '/') > 1
    if stridx(a:path, 'http:') ==# 1 || stridx(a:path, 'https:') ==# 1
      if a:path[-4] ==# '.git'
        return ['ok', ['remote', a:path]]
      else
        return ['error', [a:path, 'not a valid git repo']]
      endif
    else
      return ['ok', ['local', a:path]]
    endif
  else
    return ['error', [a:path, 'not a valid entry']]
  endif
endfunction

command! -nargs=+ -bar Load call unpack#load(<args>)
