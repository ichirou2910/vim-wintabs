" util functions to for v:version < 704
function! wintabs#gettabwinvar(tabnr, winnr, varname, def)
  let vars = gettabwinvar(a:tabnr, a:winnr, '')
  if empty(vars)
    return a:def
  endif
  return get(vars, a:varname, a:def)
endfunction
function! wintabs#getwinvar(winnr, varname, def)
  let vars = getwinvar(a:winnr, '')
  if empty(vars)
    return a:def
  endif
  return get(vars, a:varname, a:def)
endfunction

" jump to next/previous tab
" next tab if offset == 1, previous tab if offset == -1
function! wintabs#jump(offset)
  call wintabs#refresh_buflist(0)

  let [n, found] = s:current_tab()

  " if current window contains no tabs, do nothing
  if n < 0
    return
  endif

  " if substitute is used, use it as previous tab
  let offset = a:offset
  if !found
    let offset = offset < 0 ? 0 : offset
  endif

  " jump
  let size = len(w:wintabs_buflist)
  let n = (n + offset) % size
  let n = n < 0 ? n + size : n
  call s:switch_tab(n)
endfunction

" close current tab
function! wintabs#close()
  call wintabs#refresh_buflist(0)
  let buffer = bufnr('%')

  " try to save buffer if it's modified, abort if save fails
  if !s:can_be_closed(buffer)
    try
      confirm edit
    catch /E32:/
    endtry
  endif
  if !s:can_be_closed(buffer)
    return
  endif

  call wintabs#refresh_buflist(0)
  let size = len(w:wintabs_buflist)
  let buffer = bufnr('%')
  let [n, found] = s:current_tab()
  let close_window = 0

  " close window if:
  " autoclose is 1 or 2 && no tab is listed
  " autoclose is 2 && only current tab is listed
  " otherwise, switch to previous tab or a new buffer
  if size == 0
    if g:wintabs_autoclose == 0
      let switch_to = -1
    else
      let close_window = 1
    endif
  elseif size == 1 && found
    if g:wintabs_autoclose != 2
      let switch_to = -1
    else
      let close_window = 1
    endif
  else
    " switch to alternate buffer if it's in buflist
    let alt = index(w:wintabs_buflist, bufnr('#'))
    if (alt != -1)
      let switch_to = alt
    elseif found
      let switch_to = n == 0 ? 1 : n - 1
    else
      let switch_to = n
    endif
  endif

  if close_window
    call s:close_window()
  else
    call s:switch_tab(switch_to)
    call filter(w:wintabs_buflist, 'v:val != '.buffer)
  endif

  call s:post_delete(buffer)
endfunction

" undo closed tab
function! wintabs#undo()
  let filepath = wintabs#undo#peak()
  if empty(filepath)
    return
  endif

  " if peak isn't valid, pop and try again
  if bufnr('%') == bufnr(filepath) || !filereadable(filepath)
    call wintabs#undo#pop()
    call wintabs#undo()
    return
  endif

  " edit peak, pop if buffer is successfully changed
  execute 'edit '.filepath
  if bufnr('%') == bufnr(filepath)
    call wintabs#undo#pop()
  endif
endfunction

" close all but current tab
function! wintabs#only()
  call wintabs#refresh_buflist(0)

  let buflist = []
  let deleted_buflist = []
  let modified = 0

  " keep modified tabs and current buffer
  for buffer in w:wintabs_buflist
    if buffer == bufnr('%')
      call add(buflist, buffer)
    elseif s:can_be_closed(buffer)
      call add(deleted_buflist, buffer)
    else
      call add(buflist, buffer)
      let modified = 1
    endif
  endfor

  if modified
    echoerr 'Some tabs contain changes'
  endif

  let w:wintabs_buflist = buflist
  call wintabs#init()

  for buffer in deleted_buflist
    call s:post_delete(buffer)
  endfor
endfunction

" open all wintabs inside current vim tab in current window
function! wintabs#all()
  call wintabs#refresh_buflist(0)

  for window in range(1, winnr('$'))
    if window == winnr()
      continue
    endif

    call wintabs#refresh_buflist(window)

    for buffer in wintabs#getwinvar(window, 'wintabs_buflist', [])
      if index(w:wintabs_buflist, buffer) == -1
        call add(w:wintabs_buflist, buffer)
      endif
    endfor
  endfor

  call wintabs#init()
endfunction

" open all vim buffers in current window
function! wintabs#all_buffers()
  call wintabs#refresh_buflist(0)

  let buflist = wintabs#getwinvar(winnr(), 'wintabs_buflist', [])
  for buffer in range(1, bufnr('$'))
    if index(buflist, buffer) == -1 && s:buflisted(buffer)
      if (g:wintabs_reverse_order)
        call insert(buflist, buffer)
      else
        call add(buflist, buffer)
      endif
    endif
  endfor

  call wintabs#init()
endfunction

" close current window
function! wintabs#close_window()
  let w:wintabs_closing = 1
  let s:modified = 0

  call s:close_tabs_window()
  call wintabs#init()

  if s:modified
    echoerr 'Some tabs contain changes'
  endif
endfunction

" close all but current window
function! wintabs#only_window()
  let window = winnr()
  windo let w:wintabs_closing = winnr() != window
  let s:modified = 0

  windo call s:close_tabs_window()
  call wintabs#init()

  if s:modified
    echoerr 'Some tabs contain changes'
  endif
endfunction

" close current vim tab
function! wintabs#close_vimtab()
  " set autoclose so that tab is closed after all windows are closed
  let autoclose = g:wintabs_autoclose_vimtab
  let g:wintabs_autoclose_vimtab = 1

  windo let w:wintabs_closing = 1
  let s:modified = 0

  windo call s:close_tabs_window()
  call wintabs#init()

  if s:modified
    echoerr 'Some tabs contain changes'
  endif

  " reset autoclose
  let g:wintabs_autoclose_vimtab = autoclose
endfunction

" close all but current vim tab
function! wintabs#only_vimtab()
  " set autoclose so that tab is closed after all windows are closed
  let autoclose = g:wintabs_autoclose_vimtab
  let g:wintabs_autoclose_vimtab = 1

  let tabpage = tabpagenr()
  tabdo windo let w:wintabs_closing = tabpagenr() != tabpage
  let s:modified = 0

  tabdo windo call s:close_tabs_window()
  call wintabs#init()

  if s:modified
    echoerr 'Some tabs contain changes'
  endif

  " reset autoclose
  let g:wintabs_autoclose_vimtab = autoclose
endfunction

" go to nth tab
function! wintabs#go(n)
  call wintabs#refresh_buflist(0)

  let size = len(w:wintabs_buflist)

  " positive n needs -1 since n is ordinal number not index number
  " negative n means reverse index
  let n = a:n > 0 ? a:n - 1 : size + a:n

  " if n is out of range, do nothing
  if n < 0 || n >= size
    return
  endif

  call s:switch_tab(n)
endfunction

" move the current tab by n tabs
function! wintabs#move(n)
  call wintabs#refresh_buflist(0)

  " do nothing if current tab isn't listed
  let buffer = bufnr('%')
  let pos = index(w:wintabs_buflist, buffer)
  if pos == -1
    return
  endif

  " get new position, clamp at boundary
  let size = len(w:wintabs_buflist)
  let new_pos = pos + a:n
  if new_pos < 0
    let new_pos = 0
  endif
  if new_pos >= size
    let new_pos = size - 1
  endif

  " move
  call remove(w:wintabs_buflist, pos)
  call insert(w:wintabs_buflist, buffer, new_pos)

  call wintabs#init()
endfunction

" move the current tab to an adjacent window
function! wintabs#move_to_window(wincmd_arg)
  let old_winnr = winnr()
  let buffer = bufnr('%')

  " go to new window
  execute 'wincmd '.a:wincmd_arg
  let new_winnr = winnr()

  " if buffer window wasn't changed by wincmd_arg, do nothing
  if buffer == bufnr('%') || old_winnr == new_winnr
    return
  endif

  " temporarily disable switchbuf and autoclose behavior
  let switchbuf = &switchbuf
  let &switchbuf = ''
  let wintabs_switchbuf = g:wintabs_switchbuf
  let g:wintabs_switchbuf = ''
  let autoclose = g:wintabs_autoclose
  let g:wintabs_autoclose = 0

  " open buffer in new window, go back to old window, close current buffer, come 
  " back to new window
  execute 'buffer '.buffer
  execute old_winnr.'wincmd w'
  call wintabs#close()
  execute new_winnr.'wincmd w'

  " restore switchbuf and autoclose
  let &switchbuf = switchbuf
  let g:wintabs_switchbuf = wintabs_switchbuf
  let g:wintabs_autoclose = autoclose

  call wintabs#init()
endfunction

" move the current split window to its own Vim tab
function! wintabs#maximize()
  " do nothing if current Vim tab has only one window
  if winnr('$') == 1
    return
  endif

  call wintabs#refresh_buflist(0)

  let buflist = w:wintabs_buflist
  execute "normal! \<C-W>T"
  let w:wintabs_buflist = buflist

  call wintabs#init()
endfunction

" execute cmd for each tab
function! wintabs#do(cmd)
  call wintabs#refresh_buflist(0)

  for buffer in copy(w:wintabs_buflist)
    execute 'buffer! '.buffer
    execute a:cmd
  endfor
endfunction

" set tabline/statusline
function! wintabs#init()
  call wintabs#refresh_buflist(0)

  if g:wintabs_display == 'tabline'
    " disable gui tabline
    if has('gui_running')
      set guioptions-=e
    endif

    set showtabline=2
    set tabline=%!wintabs#ui#get_tabline()
  elseif g:wintabs_display == 'statusline'
    set laststatus=2

    " statusline needs constant reset to test for active window
    augroup wintabs_set_statusline
      autocmd!
      autocmd BufWinEnter,WinEnter,VimEnter * call wintabs#ui#set_statusline()
    augroup END
    call wintabs#ui#set_statusline()

    " show original statusline in tabline
    if !empty(g:wintabs_statusline)
      set showtabline=2
      let &tabline = g:wintabs_statusline
      augroup wintabs_set_tabline
        autocmd!
        autocmd InsertEnter,InsertLeave,CursorMoved,CursorMovedI * :let &ro=&ro
      augroup END
    endif
  else
    autocmd BufWinEnter,WinEnter,VimEnter * call wintabs#refresh_buflist(0)
  endif

  if g:wintabs_display != 'statusline'
    augroup wintabs_set_statusline
      autocmd!
    augroup END
  endif

  " hijack buffer switching
  augroup wintabs_switching_buffer
    autocmd!
    autocmd BufWinEnter * call wintabs#switching_buffer()
  augroup END

  " handle statuslie/tabline changes done by other plugins
  augroup wintabs_override_plugin_changes
    autocmd!
    autocmd CmdwinEnter,CmdwinLeave,GUIEnter,ColorScheme,OptionSet,SourcePre,
          \VimEnter,WinEnter,BufWinEnter,FileType,BufUnload,CompleteDone,
          \VimResized,TabEnter,BufWritePost,SessionLoadPost * call s:override_plugin_changes()
  augroup END

  call wintabs#renderers#init()
endfunction

" refresh buffer list
function! wintabs#refresh_buflist(window)
  let window = a:window == 0 ? winnr() : a:window

  " load buflist from saved value
  let buflist = wintabs#getwinvar(window, 'wintabs_buflist', [])

  " remove stale bufs
  call filter(buflist, 's:buflisted(v:val)')

  " add current buf
  let current_buffer = winbufnr(window)
  if index(buflist, current_buffer) == -1 && s:buflisted(current_buffer)
    if (g:wintabs_reverse_order)
      call insert(buflist, current_buffer)
    else
      call add(buflist, current_buffer)
    endif
  endif

  " save buflist
  call setwinvar(window, 'wintabs_buflist', buflist)

  " save this to session
  call wintabs#session#save(tabpagenr(), window)
endfunction

" switch buffer according to g:wintabs_switchbuf
function! wintabs#switching_buffer()
  let buffer = bufnr('%')
  if !s:buflisted(buffer)
    return
  endif

  " it's a new buffer if it isn't in current buflist
  if !s:is_in_buflist(0, 0, buffer)
    " search range
    if g:wintabs_switchbuf =~ 'usetab'
      let tabrange = [tabpagenr()] + range(1, tabpagenr('$'))
    elseif g:wintabs_switchbuf =~ 'useopen'
      let tabrange = [tabpagenr()]
    else
      let tabrange = []
    endif

    for tabpage in tabrange
      for window in range(1, tabpagewinnr(tabpage, '$'))
        " ignore current window
        if tabpage == tabpagenr() && window == winnr()
          continue
        endif

        " buffer exists in another window
        if s:is_in_buflist(tabpage, window, buffer)
          " if window isn't new (wintabs_buflist exists), close buffer
          " otherwise close window since it's likely opened for this buffer
          if exists('w:wintabs_buflist')
            call wintabs#close()
          else
            confirm close
          endif

          " if vim supports async, switch to the existing buffer at next tick to 
          " avoid racing with autocmds, otherwise switch immediately
          if has('timers') && has('lambda')
            call timer_start(0, {-> s:open_buffer_in(tabpage, window, buffer)})
          else
            call s:open_buffer_in(tabpage, window, buffer)
          endif
          return
        endif
      endfor
    endfor
  endif
endfunction

" private functions below

" buffers listed as wintabs are
" buflisted()
" not ignored by g:wintabs_ignored_filetypes
" not empty: no buffer name and not modified
function! s:buflisted(buffer)
  let filetype = getbufvar(a:buffer, '&filetype')
  let ignored = index(g:wintabs_ignored_filetypes, filetype) != -1
  let empty = bufname(a:buffer) == '' && !getbufvar(a:buffer, '&modified')
  return buflisted(a:buffer) && !ignored && !empty
endfunction

" get current tab or a sensible substitute
" returns [n, found]: n is tab's ordinal, found is 0 if substitute is used
" returns [-1, 0] if current window contains no tabs
function! s:current_tab()
  " if there is no tab, return -1
  if len(w:wintabs_buflist) == 0
    return [-1, 0]
  endif

  let buffer = bufnr('%')

  " if % is unlisted, use #
  if !s:buflisted(buffer)
    let buffer = bufnr('#')
  endif

  let n = index(w:wintabs_buflist, buffer)

  " if no such tab, use last tab
  if n == -1
    let n = len(w:wintabs_buflist) - 1
    let found = 0
  else
    let found = buffer == bufnr('%')
  endif

  return [n, found]
endfunction

" switch to (n-1)th tab, or create a new tab if n < 0
" do nothing if n >= number of tabs
function! s:switch_tab(n)
  " do nothing if n >= size
  if a:n >= len(w:wintabs_buflist)
    return
  endif

  " set hidden to keep changes in current buffer
  let hidden = &hidden
  let &hidden = 1

  if a:n < 0
    enew
  else
    execute 'buffer '.w:wintabs_buflist[a:n]
  endif

  " restore hidden
  let &hidden = hidden
endfunction

" close current window, considering all autoclose behaviors
function! s:close_window()
  " one window, one tab => quit vim
  if winnr('$') == 1 && tabpagenr('$') == 1 && g:wintabs_autoclose_vim
    confirm quit
    return
  endif

  " more than one window => close window
  " one window, more than one tab => close tab
  if winnr('$') > 1 || tabpagenr('$') > 1 && g:wintabs_autoclose_vimtab
    confirm close
    return
  endif

  " otherwise close all wintabs
  let w:wintabs_buflist = []
  call s:switch_tab(-1)
endfunction

" close all tabs in current window and window itself
function! s:close_tabs_window()
  " if window doesn't set wintabs_closing, do nothing
  if !wintabs#getwinvar(0, 'wintabs_closing', 0)
    return
  endif
  let w:wintabs_closing = 0

  call wintabs#refresh_buflist(0)

  let buflist = []
  let deleted_buflist = []
  let modified = 0

  " keep modified tabs
  for buffer in w:wintabs_buflist
    if s:can_be_closed(buffer)
      call add(deleted_buflist, buffer)
    else
      call add(buflist, buffer)
      let modified = 1
    endif
  endfor

  if modified
    let s:modified = 1
    let w:wintabs_buflist = buflist

    " if current buffer should be closed, switch to first tab
    if s:can_be_closed(bufnr('%'))
      call s:switch_tab(0)
    endif
  else
    call s:close_window()
  endif

  for buffer in deleted_buflist
    call s:post_delete(buffer)
  endfor
endfunction

" test if current buffer is in given tab and window
function! s:is_in_buflist(tabnr, winnr, buffer)
  let tabpage = a:tabnr == 0 ? tabpagenr() : a:tabnr
  let window = a:winnr == 0 ? winnr() : a:winnr
  let buflist = wintabs#gettabwinvar(tabpage, window, 'wintabs_buflist', [])
  return index(buflist, a:buffer) != -1
endfunction

" run post-delete triggers
function! s:post_delete(buffer)
  call wintabs#undo#push(a:buffer)
  call s:purge(a:buffer)
endfunction

" delete buffer from buflist if it's safe to do so: the buffer must be listed, 
" not modified, not attached to any window, not shown in any window
function! s:purge(buffer)
  if !buflisted(a:buffer)
        \|| getbufvar(a:buffer, '&modified')
        \|| s:count_occurrence(a:buffer) > 0
    return
  endif
  for tabpage in range(1, tabpagenr('$'))
    if index(tabpagebuflist(tabpage), a:buffer) != -1
      return
    endif
  endfor
  execute 'bdelete '.a:buffer
endfunction

" count in how many windows in all vimtabs a buffer is attached
function! s:count_occurrence(buffer)
  let occurrences = 0
  for tabpage in range(1, tabpagenr('$'))
    for window in range(1, tabpagewinnr(tabpage, '$'))
      if s:is_in_buflist(tabpage, window, a:buffer)
        let occurrences += 1
      endif
    endfor
  endfor
  return occurrences
endfunction

" test if a buffer can be safely closed: it can if it isn't modified, or it's 
" attached to more than one window
function! s:can_be_closed(buffer)
  return !getbufvar(a:buffer, '&modified') || s:count_occurrence(a:buffer) > 1
endfunction

" open a buffer inside a particular window
function! s:open_buffer_in(tabpage, window, buffer)
  execute 'tabnext '.a:tabpage
  execute a:window.'wincmd w'
  execute 'confirm buffer '.a:buffer
endfunction

" override statusline/tabline changes made by other plugins
function! s:override_plugin_changes()
  if g:wintabs_display == 'tabline'
        \&& match(&tabline, '%!wintabs#ui#get_tabline') == -1
    set tabline=%!wintabs#ui#get_tabline()
  elseif g:wintabs_display == 'statusline'
        \&& match(&statusline, '%!wintabs#ui#get_statusline') == -1
    call wintabs#ui#set_statusline()
  endif
endfunction
