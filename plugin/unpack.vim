command! -nargs=+ Unpack call unpack#load(<args>)
command! -nargs=0 UnpackClean call unpack#clean()
command! -nargs=0 UnpackCompile call unpack#compile()
command! -nargs=0 UnpackWrite call unpack#write()
command! -nargs=* -complete=customlist,unpack#list UnpackInstall call unpack#install(<args>)
command! -nargs=* -complete=customlist,unpack#list UnpackUpdate call unpack#update(<args>)
