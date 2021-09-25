function! wintabs#renderers#defaults()
  return {
        \'buffer': function('wintabs#renderers#buffer'),
        \'icon': function('wintabs#renderers#icon'),
        \'buffer_sep': function('wintabs#renderers#buffer_sep'),
        \'tab': function('wintabs#renderers#tab'),
        \'tab_sep': function('wintabs#renderers#tab_sep'),
        \'left_arrow': function('wintabs#renderers#left_arrow'),
        \'right_arrow': function('wintabs#renderers#right_arrow'),
        \'line_sep': function('wintabs#renderers#line_sep'),
        \'padding': function('wintabs#renderers#padding'),
        \}
endfunction

function! wintabs#renderers#init()
  augroup wintabs_ui_on_colorscheme
    autocmd!
    autocmd ColorScheme,VimEnter * call s:on_colorscheme()
  augroup END
  call s:on_colorscheme()
endfunction

function! wintabs#renderers#buffer(bufnr, config)
  let label = wintabs#renderers#buf_label(a:bufnr, a:config)
  let highlight = a:config.is_active ? 'WintabsActive' : 'WintabsInactive'
  let highlight = s:maybe_nc(highlight, a:config)
  return { 'label': ' '.label.' ', 'highlight': highlight }
endfunction

function! wintabs#renderers#icon(bufnr, config)
  if g:wintabs_ui_buffer_icon == 0
    return { 'label': '', 'highlight': '' }
  endif
  let element = wintabs#renderers#buf_icon(a:bufnr, a:config)
  let highlight = a:config.is_active ? 'wintabsIcon_' . element.type : 'WintabsInactive'
  let highlight = s:maybe_nc(highlight, a:config)
  return { 'label': ' '.element.icon, 'highlight': highlight }
endfunction

function! wintabs#renderers#buffer_sep(config)
  if a:config.is_leftmost
    return { 'label': '', 'highlight': '' }
  endif

  let highlight = 'WintabsInactive'
  if a:config.is_active && a:config.is_left
    let highlight = 'WintabsInactiveSepActive'
  elseif a:config.is_active && a:config.is_right && !a:config.is_rightmost
    let highlight = 'WintabsActiveSepInactive'
  elseif a:config.is_active && a:config.is_rightmost
    let highlight = 'WintabsActiveSepEmpty'
  elseif !a:config.is_active && a:config.is_rightmost
    let highlight = 'WintabsInactiveSepEmpty'
  endif

  let highlight = s:maybe_nc(highlight, a:config)
  let is_transitional = has_key(s:sep_is_transitional, highlight)
        \? s:sep_is_transitional[highlight]
        \: 0
  let label = is_transitional
        \? g:wintabs_ui_sep_buffer_transition
        \: g:wintabs_ui_sep_buffer
  return { 'label': label, 'highlight': highlight }
endfunction

function! wintabs#renderers#tab(tabnr, config)
  let label = ' '.wintabs#renderers#tab_label(a:tabnr).' '
  let highlight = a:config.is_active ? 'WintabsActive' : 'WintabsInactive'
  let highlight = s:maybe_nc(highlight, a:config)
  return { 'label': label, 'highlight': highlight }
endfunction

function! wintabs#renderers#tab_sep(config)
  if a:config.is_rightmost
    return { 'label': '', 'highlight': '' }
  endif

  let highlight = 'WintabsInactive'
  if a:config.is_active && a:config.is_right
    let highlight = 'WintabsInactiveSepActive'
  elseif a:config.is_active && a:config.is_left && !a:config.is_leftmost
    let highlight = 'WintabsActiveSepInactive'
  elseif a:config.is_active && a:config.is_leftmost
    let highlight = 'WintabsActiveSepEmpty'
  elseif !a:config.is_active && a:config.is_leftmost
    let highlight = 'WintabsInactiveSepEmpty'
  endif

  let highlight = s:maybe_nc(highlight, a:config)
  let is_transitional = has_key(s:sep_is_transitional, highlight)
        \? s:sep_is_transitional[highlight]
        \: 0
  let label = is_transitional
        \? g:wintabs_ui_sep_tab_transition
        \: g:wintabs_ui_sep_tab
  return { 'label': label, 'highlight': highlight }
endfunction

function! wintabs#renderers#left_arrow()
  return {
        \'type': 'left_arrow',
        \'label': g:wintabs_ui_arrow_left,
        \'highlight': 'WintabsArrow',
        \}
endfunction

function! wintabs#renderers#right_arrow()
  return {
        \'type': 'right_arrow',
        \'label': g:wintabs_ui_arrow_right,
        \'highlight': 'WintabsArrow',
        \}
endfunction

function! wintabs#renderers#line_sep()
  return {
        \'type': 'sep',
        \'label': '  ',
        \'highlight': 'WintabsEmpty',
        \}
endfunction

function! wintabs#renderers#padding(len)
  return {
        \'type': 'sep',
        \'label': repeat(' ', a:len),
        \'highlight': 'WintabsEmpty',
        \}
endfunction

function! wintabs#renderers#bufname(bufnr)
  let name = fnamemodify(bufname(a:bufnr), ':t')
  let name = substitute(name, '%', '%%', 'g')
  if empty(name)
    let name = '[No Name]'
  endif
  return name
endfunction

function! wintabs#renderers#bufmod(bufnr)
  let mod = ''
  if getbufvar(a:bufnr, '&readonly')
    let mod = mod.g:wintabs_ui_readonly
  elseif getbufvar(a:bufnr, '&modified')
    let mod = mod.g:wintabs_ui_modified
  endif
  return mod
endfunction

function! wintabs#renderers#buf_label(bufnr, config)
  let label = g:wintabs_ui_buffer_name_format
  let label = substitute(label, "%t", wintabs#renderers#bufname(a:bufnr), "g")
  let label = substitute(label, "%n", a:bufnr, "g")
  let label = substitute(label, "%o", a:config.ordinal, "g")

  let mod = wintabs#renderers#bufmod(a:bufnr)
  return label.mod
endfunction

function! wintabs#renderers#buf_icon(bufnr, config)
  let bufname = wintabs#renderers#bufname(a:bufnr)
  let type = wintabs#icon#get_type(bufname)
  let icon = wintabs#icon#get_icon(type)
  return {'icon': icon, 'type': type}
endfunction

function! wintabs#renderers#tab_label(tabnr)
  let label = ''
  if get(g:, 'loaded_taboo', 0)
    let label = TabooTabTitle(a:tabnr)
  endif

  if empty(label) && exists('*gettabvar')
    let label = gettabvar(a:tabnr, 'label')
  endif

  if empty(label)
    let buflist = tabpagebuflist(a:tabnr)
    let winnr = tabpagewinnr(a:tabnr)
    let bufnr = buflist[winnr - 1]
    let label = wintabs#renderers#bufname(bufnr)
  endif

  let label = substitute(g:wintabs_ui_vimtab_name_format, "%t", label, "g")
  let label = substitute(label, "%n", a:tabnr, "g")
  return label
endfunction

function! s:on_colorscheme()
  let s:sep_is_transitional = {}
  call s:highlight('WintabsInactiveSepActive', 'WintabsInactive', 'WintabsActive')
  call s:highlight('WintabsActiveSepInactive', 'WintabsActive', 'WintabsInactive')
  call s:highlight('WintabsActiveSepEmpty', 'WintabsActive', 'WintabsEmpty')
  call s:highlight('WintabsInactiveSepEmpty', 'WintabsInactive', 'WintabsEmpty')
  call s:highlight('WintabsInactiveSepActiveNC', 'WintabsInactiveNC', 'WintabsActiveNC')
  call s:highlight('WintabsActiveSepInactiveNC', 'WintabsActiveNC', 'WintabsInactiveNC')
  call s:highlight('WintabsActiveSepEmptyNC', 'WintabsActiveNC', 'WintabsEmpty')
  call s:highlight('WintabsInactiveSepEmptyNC', 'WintabsInactiveNC', 'WintabsEmpty')
endfunction

function! s:highlight(higroup, fg_higroup, bg_higroup)
  let fg_color = s:get_color(a:fg_higroup, 'bg')
  let bg_color = s:get_color(a:bg_higroup, 'bg')
  let is_transitional = fg_color != bg_color
  if !is_transitional
    let fg_color = s:get_color(a:fg_higroup, 'fg')
  endif
  let s:sep_is_transitional[a:higroup] = is_transitional

  let cmd = 'highlight! '.a:higroup
  for mode in ['gui', 'cterm']
    let cmd = cmd.' '.mode.'fg='.fg_color[mode]
    let cmd = cmd.' '.mode.'bg='.bg_color[mode]
  endfor
  execute cmd
endfunction

function! s:get_color(higroup, type)
  let color = {}
  for mode in ['gui', 'cterm']
    let value = synIDattr(synIDtrans(hlID(a:higroup)), a:type, mode)
    if empty(value)
      if a:higroup ==? 'Normal'
        let value = a:type == 'fg' ? 'Black' : 'White'
      else
        let value = s:get_color('Normal', a:type)[mode]
      endif
    endif
    let color[mode] = value
  endfor
  return color
endfunction

function! s:maybe_nc(higroup, config)
  let is_nc = has_key(a:config, 'is_active_window') && !a:config.is_active_window
  let higroup = is_nc ? a:higroup.'NC' : a:higroup
  " echom higroup
  return higroup
endfunction
