if exists('g:unpacked')
  finish
endif

let g:unpack#packpath = unpack#platform#config_path()
let g:unpacked = v:false

let s:error = ''
let s:configuration = {}
let s:configuration.packages = {}
let g:unpack#packpath_modified = v:false

let s:default_package_options = {
      \   'ft': [],
      \   'cmd': [],
      \   'event': [],
      \   'branch': '',
      \   'commit': '',
      \   'post-install': '',
      \   'local': v:false,
      \   'setup': '',
      \   'config': '',
      \ }

" initialize the plugin
function! unpack#begin(...)
  if a:0 >= 1
    let g:unpack#packpath = a:1
    let g:unpack#packpath_modified = v:true
  endif
endfunction

function! unpack#end()
  let g:unpacked = v:true
endfunction

function! unpack#load(path, ...)
  if !exists('g:unpacked')
    echohl ErrorMsg
    echom 'Plug-in not initialized. Check your configuration. (Hint: did you call unpack#end?)'
    echohl None
    finish
  endif

  if a:0
    let l:opts = a:1
  else
    let l:opts = s:default_package_options
  endif
  let g:unpacked = v:true
  let l:name = s:extract_name(trim(a:path))
  let l:full_path = s:get_full_path(a:path)
  if l:name.ok && l:full_path.ok
    let l:spec = extend(deepcopy(s:default_package_options), l:opts)
    let l:spec.local = l:full_path.local
    let l:spec.path = l:full_path.path
    let s:configuration.packages[l:name.name] = l:spec
  else
    echohl ErrorMsg
    if !l:name.ok
      echom l:name.msg
    else
      echom l:full_path.msg
    endif
    echohl NONE
  endif
endfunction

" TODO: split filetype autocmds into ftplugins within the loader plugin. That
" way lazyload on filetype will have literally zero overhead
function! unpack#compile()
  let l:state = {
        \ 'packages': [],
        \ 'ft': {},
        \ 'cmd': {},
        \ 'event': {},
        \ 'branch': {},
        \ 'commit': {},
        \ 'local': {},
        \ 'post-install': {},
        \ 'setup': {},
        \ 'config': {},
        \ 'path': {}
        \ }
  for [l:name, l:opts] in items(s:configuration.packages)
    let l:state = s:compile_item(l:name, l:opts, l:state)
  endfor
  let l:output = unpack#code#gen(l:state, s:configuration)
  let l:config_path = unpack#platform#config_path()
  let l:dir = unpack#platform#join(l:config_path, 'plugin', 'unpack')
  let l:ftplugin = unpack#platform#join(l:dir, 'ftplugin')
  if !isdirectory(l:ftplugin)
    call mkdir(l:ftplugin, 'p')
  endif
  call writefile(l:output.loader, unpack#platform#join(l:dir, 'loader.vim'))
  call writefile(l:output.unplug, unpack#platform#join(l:dir, 'unplug.vim'))
endfunction

function! unpack#write()
  let l:opt_packages = unpack#platform#ls(unpack#platform#opt_path())
  let l:start_packages = unpack#platform#ls(unpack#platform#start_path())
  for l:package in keys(s:configuration.packages)
    if s:is_member(l:package, l:opt_packages) && !s:is_optional(l:package)
      call s:make_mandatory(l:package)
    elseif s:is_member(l:package, l:start_packages) && s:is_optional(l:package)
      call s:make_optional(l:package)
    endif
  endfor
  call unpack#compile()
endfunction

function! s:is_member(item, list)
  for l:item in a:list
    if l:item ==# a:item
      return v:true
    endif
  endfor
  return v:false
endfunction

function! s:make_optional(name)
  let l:opt_dir = unpack#platform#join(unpack#platform#opt_path(), a:name)
  let l:start_dir = unpack#platform#join(unpack#platform#start_path(), a:name)
  call unpack#platform#move(l:start_dir, l:opt_dir)
endfunction

function! s:make_mandatory(name)
  let l:opt_dir = unpack#platform#join(unpack#platform#opt_path(), a:name)
  let l:start_dir = unpack#platform#join(unpack#platform#start_path(), a:name)
  call unpack#platform#move(l:opt_dir, l:start_dir)
endfunction

function! s:is_optional(name)
  let l:spec = s:configuration.packages[a:name]
  return !empty(l:spec.ft) || !empty(l:spec.cmd) || !empty(l:spec.event)
endfunction

function! s:compile_item(name, opts, state)
  for [l:key, l:val] in items(a:opts)
    let a:state[l:key][a:name] = l:val
  endfor
  return a:state
endfunction

" TODO: add timeout
function! s:clone(name)
  let l:spec = s:configuration.packages[a:name]
  let l:opt_dir = unpack#platform#join(unpack#platform#opt_path(), a:name) 
  let l:start_dir = unpack#platform#join(unpack#platform#opt_path(), a:name) 
  if !(isdirectory(l:opt_dir) || isdirectory(l:start_dir))
    let l:dir = s:is_optional(a:name) ? unpack#platform#opt_path() : unpack#platform#start_path()
    if !(isdirectory(l:dir))
      call mkdir(l:dir, 'p')
    endif
    let l:Post = type(l:spec['post-install'] ==# 2) ? l:spec['post-install'] : {_ -> 0}
    let l:Echom = function('unpack#ui#echom')
    let l:Echom_err = function('unpack#ui#echom_err')
    if empty(l:spec.branch) && empty(l:spec.commit)
      let l:cmd = ['git', '-C', l:dir, 'clone', l:spec.path]
      call unpack#job#start(l:cmd, l:Echom, l:Echom_err, l:Post)
    elseif !empty(l:spec.commit) && !empty(l:spec.branch)
      let l:cmd1 = ['git', '-C', l:dir, 'clone', '-b', l:spec.branch, l:spec.path]
      let l:cmd2 = ['git', '-C', unpack#platform#join(l:dir, a:name), 'checkout', l:spec.commit]
      call unpack#job#start(l:cmd1, l:Echom, l:Echom_err, {->
         \ unpack#job#start(l:cmd2, l:Echom, l:Echom_err, l:Post)})
    elseif !empty(l:spec.commit)
      let l:cmd1 = ['git', '-C', l:dir, 'clone', l:spec.path]
      let l:cmd2 = ['git', '-C', unpack#platform#join(l:dir, a:name), 'checkout', l:spec.commit]
      call unpack#job#start(l:cmd1, l:Echom, l:Echom_err, {->
         \ unpack#job#start(l:cmd2, l:Echom, l:Echom_err, l:Post)})
    else
      let l:cmd = ['git', '-C', l:dir, 'clone', '-b', l:spec.branch, l:spec.path]
      call unpack#job#start(l:cmd, l:Echom, l:Echom_err, l:Post)
    endif
  endif
endfunction

" TODO: add timeout
function! s:fetch(name)
  let l:spec = s:configuration.packages[a:name]
  let l:dir = s:is_optional(a:name) ? unpack#platform#opt_path() : unpack#platform#start_path()
  let l:Echom = function('unpack#ui#echom')
  let l:Echom_err = function('unpack#ui#echom_err')
  let l:cmd = ['git', '-C', unpack#platform#join(l:dir, a:name), 'fetch']
  " TODO: only run post-install if something changed
  let l:Post = type(l:spec['post-install'] ==# 2) ? l:spec['post-install'] : {_ -> 0}
  call unpack#job#start(l:cmd, l:Echom, l:Echom_err, l:Post)
endfunction

function! unpack#list()
  return sort(keys(s:configuration.packages))
endfunction

function! s:for_each_package_do(f, names)
  if len(a:names) >= 1  " user specified packages to perform action
    let l:error = 0
    for l:name in a:names
      if !has_key(s:configuration.packages, l:name)
        echohl ErrorMsg
        echom l:name . ' is not a known package.'
        echohl NONE
        let l:error = 1
        break
      endif
    endfor

    if !l:error
      for l:name in a:names
        call a:f(l:name)
      endfor
    endif
  else
    for l:name in keys(s:configuration.packages)
      call a:f(l:name)
    endfor
  endif
endfunction

function! s:install(name)
  let l:spec = s:configuration.packages[a:name]
  echom s:configuration.packages
  echom l:spec
  if l:spec.local
    if s:is_optional(a:name)
      let l:install_path = unpack#platform#opt_path()
    else
      let l:install_path = unpack#platform#start_path()
    endif
    call unpack#platform#ln(l:spec.path, unpack#platform#join(l:install_path, a:name))
  else
    call s:clone(a:name)
  endif
endfunction

function! unpack#install(...)
  call s:for_each_package_do(function('s:install'), a:000)
endfunction

function! unpack#clean()
  let l:opt_dir = unpack#platform#opt_path()
  let l:start_dir = unpack#platform#start_path()
  call s:remove_package_if_not_in_list(l:opt_dir)
  call s:remove_package_if_not_in_list(l:start_dir)
endfunction

function! s:remove_package_if_not_in_list(base_path)
  for l:package in unpack#platform#ls(a:base_path)
    let l:name = unpack#platform#split(l:package)[-1]
    if !s:is_member(l:name, keys(s:configuration.packages))
      let l:path = unpack#platform#join(a:base_path, l:package)
      call delete(l:path, 'rf')
    endif
  endfor
endfunction

function! unpack#update(...)
  call s:for_each_package_do(function('s:fetch'), a:000)
endfunction

function! s:extract_name(path)
  if stridx(a:path, '/') > 0
    if stridx(a:path, 'http:') ==# 0 || stridx(a:path, 'https:') ==# 0 || stridx(a:path, 'git@') ==# 0
      let repo = split(a:path, '/')[-1]
      if repo[-4:] ==# '.git'
        return {'ok': 1, 'name': repo[:-4]}
      else
        return {'ok': 0, 'path': a:path, 'msg': 'not a valid git repo'}
      endif
    else  " not a url
      return {'ok': 1, 'name': split(a:path, '/')[-1]}
    endif
  else
    return {'ok': 0, 'path': a:path, 'msg': 'not a valid entry'}
  endif
endfunction

function! s:get_full_path(path)
  if count(a:path, '/') ==# 1  " path for Github
    return {'ok': 1, 'local': 0, 'path': 'https://github.com/' . a:path . '.git'}
  elseif count(a:path, '/') > 1
    if stridx(a:path, 'http:') ==# 1 || stridx(a:path, 'https:') ==# 1
      if a:path[-4] ==# '.git'
        return {'ok': 1, 'local': 0, 'path': a:path}
      else
        return {'ok': 0, 'path': a:path, 'msg': 'not a valid git repo'}
      endif
    else
      return {'ok': 1, 'local': 1, 'path': a:path}
    endif
  else
    return {'ok': 0, 'path': a:path, 'msg': 'not a valid entry'}
  endif
endfunction
