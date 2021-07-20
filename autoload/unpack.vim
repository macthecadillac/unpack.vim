" TODO: accept commands as well as lambdas (as a string literal) for
" `post-install`, `pre`, and `post`
" TODO: make command for creating funtions in the loader (something like
" UnpackDef ['x', 'y'] ['return a:x + a:y'] with the first array being the list
" of arguments and the second being a list of statements in sequence which will
" then be compiled into an actual vim function in the loader
" TODO: check every dictionary indexing and insert error handler for the
" configuration processing step since users might put in undefined keys
" TODO: either find a workaround for predefining dummy commands/functions and
" have vim load the loader before sourcing the package def sections or simply
" rename the generated plugin into something that doesn't share the `unpack`
" namespace
if !(v:version >= 800 || has('nvim'))
  echohl ErrorMsg
  echom 'Unpack requires neovim or vim version 8 or above'
  echohl NONE
  finish
endif

if exists('s:config_loaded')
  finish
endif

let g:unpack#jobs = {}
let g:unpack#packpath = unpack#platform#config_path()
let s:config_loaded = v:false
let s:default_loader_path = unpack#platform#join(unpack#platform#config_path(), 'unpack')
let g:unpack#loader_path = get(g:, 'unpack#loader_path', s:default_loader_path)
let g:unpack#config_changed = v:true

let s:error = ''
let s:configuration = {}
let s:configuration.packages = {}
let g:unpack#packpath_modified = v:false

let s:default_package_options = {
      \   'opt': v:false,
      \   'ft': [],
      \   'cmd': [],
      \   'event': [],
      \   'branch': '',
      \   'commit': '',
      \   'post-install': '',
      \   'local': v:false,
      \   'pre': '',
      \   'post': '',
      \   'requires': [],
      \ }

" initialize the plugin
function! unpack#begin(...)
  if a:0 >= 1
    let g:unpack#packpath = a:1
    let g:unpack#packpath_modified = v:true
  endif
endfunction

function! unpack#end()
  let s:config_loaded = v:true
  let g:unpack#config_changed = v:true
endfunction

function! s:lift_list(x)
  if type(a:x) ==# 3  " list
    return {'ok': v:true, 'val': a:x}
  elseif type(a:x) ==# 1  " string
    return {'ok': v:true, 'val': [a:x]}
  else
    return {'ok': v:false, 'msg': a:x . ' is not a list or string'}
  endif
endfunction

function! s:check_init_status()
  if !exists('s:config_loaded')
    echohl ErrorMsg
    echom 'Package manager not initialized. Check your configuration. (Hint: did you call unpack#end?)'
    echohl None
    return v:false
  else
    return v:true
  endif
endfunction

function! unpack#load(path, ...)
  if s:check_init_status()
    if a:0
      let l:opts = a:1
    else
      let l:opts = s:default_package_options
    endif
    let l:name = s:extract_name(trim(a:path))
    let l:full_path = s:get_full_path(a:path)
    if l:name.ok && l:full_path.ok
      let l:spec = extend(deepcopy(s:default_package_options), l:opts)
      let l:ft = s:lift_list(l:spec.ft)
      let l:cmd = s:lift_list(l:spec.cmd)
      let l:event = s:lift_list(l:spec.event)
      let l:requires = s:lift_list(l:spec.requires)
      if l:ft.ok && l:cmd.ok && l:event.ok && l:requires.ok
        let l:spec.ft = l:ft.val
        let l:spec.cmd = l:cmd.val
        let l:spec.event = l:event.val
        let l:spec.requires = l:requires.val
        let l:spec.local = l:full_path.local
        let l:spec.path = l:full_path.path
        let s:configuration.packages[l:name.name] = l:spec
      else
        echohl ErrorMsg
        if !l:ft.ok
          echom l:ft.msg
        elseif !l:cmd.ok
          echom l:cmd.msg
        elseif !l:event.ok
          echom l:event.msg
        elseif !l:requires.ok
          echom l:requires.msg
        endif
        echohl NONE
        unlet s:config_loaded
      endif
    else
      echohl ErrorMsg
      if !l:name.ok
        echom l:name.msg
      else
        echom l:full_path.msg
      endif
      echohl NONE
      unlet s:config_loaded
    endif
  endif
endfunction

function! unpack#compile()
  if s:check_init_status()
    let l:output = unpack#code#gen(s:configuration)
    let l:config_path = unpack#platform#config_path()
    if isdirectory(g:unpack#loader_path)  " remove previously generated loaders
      call delete(g:unpack#loader_path, 'rf')
    endif
    call mkdir(g:unpack#loader_path, 'p')

    if !empty(l:output.ftplugin)
      let l:ftplugin = unpack#platform#join(g:unpack#loader_path, 'ftplugin')
      call mkdir(l:ftplugin)
      for [l:ft, l:ft_loader] in items(l:output.ftplugin)
        call writefile(l:ft_loader, unpack#platform#join(l:ftplugin, l:ft . '.vim'))
      endfor
    endif

    if !empty(l:output.plugin.unpack)
      let l:plugin = unpack#platform#join(g:unpack#loader_path, 'plugin')
      call mkdir(l:plugin)
      call writefile(l:output.plugin.unpack, unpack#platform#join(l:plugin, 'unpack.vim'))
    endif

    if !empty(l:output.autoload.unpack.loader)
      let l:autoload = unpack#platform#join(g:unpack#loader_path, 'autoload', 'unpack')
      call mkdir(l:autoload, 'p')
      call writefile(l:output.autoload.unpack.loader, unpack#platform#join(l:autoload, 'loader.vim'))
    endif
  endif
endfunction

function! unpack#write()
  if s:check_init_status()
    let l:opt_packages = unpack#platform#ls(unpack#platform#opt_path())
    let l:start_packages = unpack#platform#ls(unpack#platform#start_path())
    for [l:package, l:spec] in items(s:configuration.packages)
      if s:is_member(l:package, l:opt_packages) && !unpack#solv#is_optional(l:package, s:configuration)
        call s:make_mandatory(l:package)
      elseif s:is_member(l:package, l:start_packages) && unpack#solv#is_optional(l:package, s:configuration)
        call s:make_optional(l:package)
      endif
    endfor
    call unpack#compile()
  endif
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

" TODO: add timeout
function! s:clone(name)
  let l:spec = s:configuration.packages[a:name]
  let l:opt_dir = unpack#platform#join(unpack#platform#opt_path(), a:name) 
  let l:start_dir = unpack#platform#join(unpack#platform#start_path(), a:name) 
  if !(isdirectory(l:opt_dir) || isdirectory(l:start_dir))
    let l:dir = unpack#solv#is_optional(a:name, s:configuration) ? unpack#platform#opt_path() : unpack#platform#start_path()
    if !(isdirectory(l:dir))
      call mkdir(l:dir, 'p')
    endif
    let l:Update = function('unpack#ui#update')
    if empty(l:spec.branch) && empty(l:spec.commit)
      let l:cmd = ['git', '-C', l:dir, 'clone', l:spec.path]
      call unpack#job#start(a:name, l:cmd, {->0}, l:Update, l:spec['post-install'])
    elseif !empty(l:spec.commit) && !empty(l:spec.branch)
      let l:cmd1 = ['git', '-C', l:dir, 'clone', '-b', l:spec.branch, l:spec.path]
      let l:cmd2 = ['git', '-C', unpack#platform#join(l:dir, a:name), 'checkout', l:spec.commit]
      call unpack#job#start(a:name, l:cmd1, {->0}, l:Update, {->
         \ unpack#job#start(a:name, l:cmd2, {->0}, l:Update, l:spec['post-install'])})
    elseif !empty(l:spec.commit)
      let l:cmd1 = ['git', '-C', l:dir, 'clone', l:spec.path]
      let l:cmd2 = ['git', '-C', unpack#platform#join(l:dir, a:name), 'checkout', l:spec.commit]
      call unpack#job#start(a:name, l:cmd1, {->0}, l:Update, {->
         \ unpack#job#start(a:name, l:cmd2, {->0}, l:Update, l:spec['post-install'])})
    else
      let l:cmd = ['git', '-C', l:dir, 'clone', '-b', l:spec.branch, l:spec.path]
      call unpack#job#start(a:name, l:cmd, {->0}, l:Update, l:spec['post-install'])
    endif
  endif
endfunction

" TODO: add timeout
function! s:fetch(name)
  let l:spec = s:configuration.packages[a:name]
  let l:dir = unpack#solv#is_optional(a:name, s:configuration) ?
        \ unpack#platform#opt_path() : unpack#platform#start_path()
  let l:Update = function('unpack#ui#update')
  let l:cmd = ['git', '-C', unpack#platform#join(l:dir, a:name), 'fetch']
  " TODO: only run post-install if something changed
  call unpack#job#start(a:name, l:cmd, {->0}, l:Update, l:spec['post-install'])
endfunction

function! unpack#list(text, ...)
  return filter(sort(keys(s:configuration.packages)), {_, s -> stridx(s, a:text) ==# 0})
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
  if l:spec.local
    if unpack#solv#is_optional(a:name, s:configuration)
      let l:install_path = unpack#platform#opt_path()
    else
      let l:install_path = unpack#platform#start_path()
    endif
    call unpack#platform#ln(l:spec.path, unpack#platform#join(l:install_path, a:name))
  else
    call s:clone(a:name)
  endif
endfunction

" FIXME: the 'commit' flag is not applied
" FIXME: empty configuration should still get to the quit prompt
" FIXME: might be creating links within local repos
" TODO: auto load plugins after installation
function! unpack#install(...)
  if s:check_init_status()
    call unpack#ui#new_window()
    call s:for_each_package_do(function('s:install'), a:000)
  endif
endfunction

" FIXME: check that the function does what is intended
function! unpack#clean()
  if s:check_init_status()
    let l:opt_dir = unpack#platform#opt_path()
    let l:start_dir = unpack#platform#start_path()
    call s:remove_package_if_not_in_list(l:opt_dir)
    call s:remove_package_if_not_in_list(l:start_dir)
  endif
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

" TODO: auto reload plugins after installation
function! unpack#update(...)
  if s:check_init_status()
    call unpack#ui#new_window()
    call s:for_each_package_do(function('s:fetch'), a:000)
  endif
endfunction

function! s:extract_name(path)
  if stridx(a:path, '/') > 0
    if stridx(a:path, 'http:') ==# 0 || stridx(a:path, 'https:') ==# 0 || stridx(a:path, 'git@') ==# 0
      let repo = split(a:path, '/')[-1]
      if repo[-4:] ==# '.git'
        return {'ok': v:true, 'name': repo[:-4]}
      else
        return {'ok': v:false, 'path': a:path, 'msg': 'not a valid git repo'}
      endif
    else  " not a url
      return {'ok': v:true, 'name': split(a:path, '/')[-1]}
    endif
  else
    return {'ok': v:false, 'path': a:path, 'msg': 'not a valid entry'}
  endif
endfunction

function! s:get_full_path(path)
  if count(a:path, '/') ==# 1  " path for Github
    return {'ok': 1, 'local': 0, 'path': 'https://github.com/' . a:path . '.git'}
  elseif count(a:path, '/') > 1
    if stridx(a:path, 'http:') ==# 1 || stridx(a:path, 'https:') ==# 1
      if a:path[-4] ==# '.git'
        return {'ok': v:true, 'local': v:false, 'path': a:path}
      else
        return {'ok': v:false, 'path': a:path, 'msg': 'not a valid git repo'}
      endif
    else
      return {'ok': v:true, 'local': v:true, 'path': a:path}
    endif
  else
    return {'ok': v:false, 'path': a:path, 'msg': 'not a valid entry'}
  endif
endfunction
