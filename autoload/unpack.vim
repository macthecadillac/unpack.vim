if exists('g:unpacked')
  finish
endif

let g:unpack#packpath = unpack#platform#config_path()

let s:error = ''
let s:configuration = {}
let s:configuration.packages = {}
let s:packpath_modified = v:false

let s:default_package_options = {
      \   'ft': [],
      \   'cmd': [],
      \   'event': [],
      \   'branch': '',
      \   'commit': '',
      \   'post-install': '',
      \   'setup': '',
      \   'config': '',
      \ }

" initialize the plugin
function! unpack#begin(...)
  let g:unpacked = v:false
  if a:0 >= 1
    let g:unpack#packpath = a:1
    let s:packpath_modified = v:true
  endif
endfunction

function! unpack#end()
  let g:unpacked = v:true
endfunction

function! unpack#load(path, opts)
  if !exists('g:unpacked')
    echohl ErrorMsg
    echom 'Plug-in not initialized. Check your configuration. (Hint: did you call unpack#begin?)'
    echohl None
    finish
  endif

  let g:unpacked = v:true
  let l:name = s:extract_name(trim(a:path))
  let l:full_path = s:get_full_path(a:path)
  if l:name.ok && l:full_path.ok
    let l:spec = extend(deepcopy(s:default_package_options), a:opts)
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
  let l:state = {}
  let l:state.packages = []
  let l:state.ft = {}
  let l:state.cmd = {}
  let l:state.event = {}
  let l:state['post-install'] = {}
  let l:state.setup = {}
  let l:state.config = {}
  let l:state.location = {}
  let l:state.path = {}
  for [l:name, l:opts] in items(s:configuration.packages)
    let l:state = s:compile_item(name, opts, l:state)
  endfor
  let l:output = s:codegen(l:state)
  let l:config_path = unpack#platform#config_path()
  let l:dir = unpack#platform#join(l:config_path, 'plugin', 'unpack')
  let l:loader = 'loader.vim'
  if !isdirectory(l:dir)
    call mkdir(l:dir, 'p')
  endif
  call writefile(l:output, unpack#platform#join(l:dir, l:loader))
endfunction

function! unpack#write()
  let l:opt_packages = unpack#platform#ls(unpack#platform#opt_path())
  let l:start_packages = unpack#platform#ls(unpack#platform#start_path())
  for l:package in keys(s:configuration.packages)
    if s:is_member(l:package, l:opt_packages) && !s:is_optional(l:package)
      call s:make_mandatory(l:package)
    elseif s:is_menber(l:package, l:start_packages) && s:is_optional(l:package)
      call s:make_optional(l:package)
    endif
  endfor
  call unpack#compile()
endfunction

function! s:is_member(iter, list)
  for l:item in a:list
    if l:item ==# a:item
      return v:true
    endif
  endfor
  return v:false
endfunction

function! s:make_optional(name)
  let l:opt_dir = unpack#platform#opt_path()
  let l:start_dir = unpack#platform#start_path()
  call unpack#platform#move(l:start_dir, l:opt_dir)
endfunction

function! s:make_mandatory(name)
  let l:opt_dir = unpack#platform#opt_path()
  let l:start_dir = unpack#platform#start_path()
  call unpack#platform#move(l:opt_dir, l:start_dir)
endfunction

function! s:is_optional(name)
  let l:spec = s:configuration.packages[a:name]
  return !empty(l:spec.ft) || !empty(l:spec.cmd) || !empty(l:event)
endfunction

function! s:compile_item(name, opts, state)
  for [l:key, l:val] in items(a:opts)
    let a:state[l:key][a:name] = l:val
  endfor
  return a:state
endfunction

function! s:augroup_gen(name, defs)
  let l:output = ['augroup ' . a:name]
  for [l:type, l:filters, l:cmd] in a:defs
    for l:filter in l:filters
      call add(l:output, '  autocmd ' . l:type . ' ' . l:filter . ' ' . l:cmd)
    endfor
  endfor
  return add(l:output, 'augroup END')
endfunction

function! s:pre_post_gen(exe)
  if a:exe ==# ''
    return []
  elseif type(a:exe) ==# 1  " string
    return ['    execute "' . a:exe . '"']
  elseif type(a:exe) ==# 2  " lambda
    return ['    call ' . a:exe . '()']
  else
    let error = '"setup" must be either a lambda or a string'
    return []
  endif
endfunction

function! s:loader_gen(name, state)
  let l:output = []
  let l:name = substitute(tolower(a:name), '\.', '_', 'g')
  let l:flag = 'g:unpack_loader_' . l:name . '_init_status'
  call add(l:output, 'let ' . l:flag . ' = 0')
  call add(l:output, 'function! unpack#loader#' . l:name . '()')
  call add(l:output, '  if !' . l:flag)
  call add(l:output, '    let ' . l:flag . ' = 1')

  call extend(l:output, s:pre_post_gen(get(a:state.setup, a:name, '')))
  call add(l:output, '    execute "packadd ' . a:name . '"')
  call extend(l:output, s:pre_post_gen(get(a:state.config, a:name, '')))

  call add(l:output, '  endif')
  call add(l:output, 'endfunction')
  return l:output
endfunction

function! s:item_gen(name, state)
  let l:output = []
  let l:defs = []
  let l:name = substitute(tolower(a:name), '\.', '_', 'g')
  let l:cmd = 'call unpack#loader#' . l:name . '()'

  for [l:type, l:key] in [['FileType', 'ft'], ['CmdUndefined', 'cmd']]
    if has_key(a:state[l:key], a:name)
      call add(l:defs, [l:type, a:state[l:key][a:name], l:cmd])
    endif
  endfor

  if has_key(a:state.event, a:name)
    for l:event in a:state.event[a:name]
      call add(l:defs, [l:event, ['*'], l:cmd])
    endfor
  endif

  return extend(s:loader_gen(a:name, a:state), s:augroup_gen(toupper(l:name), l:defs))
endfunction

function! s:codegen(state)
  let l:output = []
  call add(l:output, '" autogenerated by unpack#compile()')
  if s:packpath_modified
    call add(l:output, 'set packpath+=' . g:unpack#packpath)
  endif
  for l:name in keys(s:configuration.packages)
    call extend(l:output, s:item_gen(l:name, a:state))
  endfor
  return l:output
endfunction

function! s:clone(name, spec)
  let l:opt_dir = unpack#platform#join(unpack#platform#opt_path(), name) 
  let l:start_dir = unpack#platform#join(unpack#platform#opt_path(), name) 
  if !(isdirectory(l:opt_dir) || isdirectory(l:start_dir))
    let l:dir = is_optional(name) ? unpack#platform#opt_path() : unpack#platform#start_path()
    let l:post = type(spec['post-install'] ==# 2) ? spec['post-install'] : {_ -> 0}
    let l:Echom = function('unpack#ui#echom')
    let l:Echom_err = function('unpack#ui#echom_err')
    if empty(spec.branch) && empty(spec.commit)
      let l:cmd = ['git', '-C', l:dir, 'clone', a:spec.path]
      call unpack#job#start(l:cmd, l:Echom, l:Echom_err, l:post)
    elseif !empty(spec.commit) && !empty(spec.branch)
      let l:cmd1 = ['git', '-C', l:dir, 'clone', '-b', spec.branch, a:spec.path]
      let l:cmd2 = ['git', '-C', unpack#platform#join(l:dir, a:name), 'checkout', spec.commit]
      call unpack#job#start(l:cmd1, l:Echom, l:Echom_err, {->
         \ unpack#job#start(l:cmd2, l:Echom, l:Echom_err, l:post)})
    elseif !empty(spec.commit)
      let l:cmd1 = ['git', '-C', l:dir, 'clone', a:spec.path]
      let l:cmd2 = ['git', '-C', unpack#platform#join(l:dir, a:name), 'checkout', spec.commit]
      call unpack#job#start(l:cmd1, l:Echom, l:Echom_err, {->
         \ unpack#job#start(l:cmd2, l:Echom, l:Echom_err, l:post)})
    else
      let l:cmd = ['git', '-C', l:dir, 'clone', '-b', spec.branch, a:spec.path]
      call unpack#job#start(l:cmd, l:Echom, l:Echom_err, l:post)
    endif
  endif
endfunction

function! s:fetch(name, spec)
  let l:dir = is_optional(name) ? unpack#platform#opt_path() : unpack#platform#start_path()
  let l:Echom = function('unpack#ui#echom')
  let l:Echom_err = function('unpack#ui#echom_err')
  let l:cmd = ['git', '-C', unpack#platform#join(l:dir, name), 'fetch']
  " TODO: only run post-install if something changed
  let l:post = type(spec['post-install'] ==# 2) ? spec['post-install'] : {_ -> 0}
  call unpack#job#start(l:cmd, l:Echom, l:Echom_err, l:post)
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
        call a:f(l:name, s:configuration.packages[l:name])
      endfor
    endif
  else
    for [l:name, l:spec] in items(s:configuration.packages)
      call a:f(l:name, l:spec)
    endfor
  endif
endfunction

function! unpack#install(...)
  call s:for_each_package_do(function('s:clone'), a:000)
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
    if !s:is_member(l:name, s:configuration.packages)
      call delete(l:package, 'rf')
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
