function! unpack#solv#is_optional(name, config)
  let l:spec = a:config.packages[a:name]
  let l:graphs = unpack#solv#nodes(a:config)
  if !empty(l:spec.ft) || !empty(l:spec.cmd) || !empty(l:spec.event) || l:spec['pre'] !=# '' || l:spec.opt
    for l:dependent in keys(l:graphs[a:name].dependents)
      if !unpack#solv#is_optional(l:dependent, a:config)
        return v:false
      endif
    endfor
    return v:true
  else
    return v:false
  endif
endfunction

function! unpack#solv#has_dependents(name, config)
  let l:graphs = unpack#solv#nodes(a:config)
  return !empty(l:graphs[a:name].dependents)
endfunction

function! unpack#solv#nodes(config)
  if !exists('s:graphs')
    let s:graphs = s:build_nodes(a:config, v:false)
  endif
  return s:graphs
endfunction

" move dependencies under dependents (as a tree/graph structure) and remove them
" from the top-level set
function! s:subsume_dependencies(nodes, filter)
  let l:remove_set = {}  " the dictionary is a poor man's set
  for [l:name_i, l:node_i] in items(a:nodes)
    for l:dep in l:node_i.requires
      if l:name_i == l:dep
        echohl ErrorMsg
        echom 'UNSAT: a package cannot depend on itself'
        echohl NONE
      endif
      for [l:name_j, l:node_j] in items(a:nodes)
        if l:name_j == l:dep
          let l:node_j.dependents[l:name_i] = l:node_i
          let l:node_i.dependencies[l:name_j] = l:node_j
          let l:remove_set[l:name_j] = ''
        endif
      endfor
    endfor
  endfor
  if a:filter
    let l:nodes = {}
    for [l:name, l:node] in items(a:nodes)
      if !has_key(l:remove_set, l:name)
        let l:nodes[l:name] = l:node
      endif
    endfor
    return l:nodes
  else
    return a:nodes
  endif
endfunction

function! s:dgaux(specs, filter, toplevel)
  if !a:filter && a:toplevel
    let l:specs = s:subsume_dependencies(a:specs, v:false)
  else
    let l:specs = s:subsume_dependencies(a:specs, v:true)
  endif
  let l:specs_ = {}
  for [l:name, l:spec] in items(l:specs)
    " l:spec_.requires is the stated requirement for the package. Simple string
    " l:spec_.dependencies and l:spec_.dependents are lists of recursive objects
    " that have identical structure to this one. We basically take the
    " `requires` field and turn it into these two fields, which describes the
    " graph structure
    let l:spec_ = {
          \   'requires': l:spec.requires,
          \   'dependents': l:spec.dependents,
          \   'dependencies': s:dgaux(l:spec.dependencies, a:filter, v:false)
          \ }
    let l:specs_[l:name] = l:spec_
  endfor
  return l:specs_
endfunction

function! s:dependency_graphs(specs, filter)
  return s:dgaux(a:specs, a:filter, v:true)
endfunction

" FIXME: find a more precise way to detect cyclical graphs instead relying on
" maxfuncdeph
function! s:graph_nodes(specs, keep_only_orphans)
  try
    let l:nodes = s:dependency_graphs(a:specs, a:keep_only_orphans)
    for l:graph in values(l:nodes)
      unlet l:graph.requires
    endfor
    return l:nodes
  catch /E132/
    echohl ErrorMsg
    echom 'UNSAT: Unable to resolve your dependency graph.'
    echom '       Your dependency graph is either over 100 levels deep or it is cyclic'
    echohl NONE
  endtry
endfunction

function! s:build_nodes(config, keep_only_orphans)
  let l:depndency_specs = {}
  for [l:name, l:package] in items(a:config.packages)
    let l:spec = {
          \   'requires': l:package.requires,
          \   'dependents': {},
          \   'dependencies': {}
          \ }
    let l:depndency_specs[l:name] = l:spec
  endfor
  return s:graph_nodes(l:depndency_specs, a:keep_only_orphans)
endfunction
