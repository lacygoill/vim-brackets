if exists('g:autoloaded_brackets#move#nvim')
    finish
endif
let g:autoloaded_brackets#move#nvim = 1

" Init{{{1

const s:MAX_SIZE = 200

" Interface {{{1
fu brackets#move#nvim#qflist(lhs) abort "{{{2
    let is_loclist = a:lhs =~# 'l'
    " Some parts of `#qflist()` are time-consuming  on a big qfl (the bigger the
    " qfl, the slower they  are).  Even when invoked just once,  they can be way
    " too expensive.
    if s:is_too_big(is_loclist)
        return s:next_or_wrap(a:lhs)
    endif

    " There is  no reason to  re-invoke the slow  part of `#qflist()`  again and
    " again when we smash `]q`; we use  a timer-based guard to prevent that from
    " happening and improve the perf.
    if exists('s:was_invoked_recently')
        call timer_stop(s:was_invoked_recently)
        " Why `50`ms?{{{
        "
        " I found  the value empirically  (tested against  a qfl whose  size was
        " just below 500).
        " If  the value  is too  small, when  you smash  `]q`, sometimes  the qf
        " window is not updated.
        "}}}
        let s:was_invoked_recently = timer_start(50, {-> execute('unlet! s:was_invoked_recently')})
        return s:next_or_wrap(a:lhs)
    else
        let s:was_invoked_recently = timer_start(50, {-> execute('unlet! s:was_invoked_recently')})
    endif

    let _qfl = is_loclist ? getloclist(0) : getqflist()
    let qfl = deepcopy(_qfl)
    call s:remove_entries_from_other_files(qfl, is_loclist)

    " there is no entry in the current file; we can't run anything before `:cnext`/`:cprevious`
    if empty(qfl) | call s:next_or_wrap(a:lhs) | return brackets#util#open_fold(a:lhs) | endif

    " let's try to visit the next/previous entry in the file
    call call('s:remove_entries_'..(a:lhs =~# ']' ? 'before' : 'after')..'_cursor', [qfl, a:lhs])
    if !empty(qfl)
        let entry = a:lhs =~# ']' ? qfl[0] : qfl[-1]
        let idx = index(_qfl, entry) + 1
        exe (is_loclist ? 'll ' : 'cc ')..idx
        return brackets#util#open_fold(a:lhs)
    endif

    " there is no next/previous entry in the current file; let's try in the next/previous file
    let qfl = deepcopy(_qfl)
    call s:remove_entries_from_other_files(qfl, is_loclist)
    let entry = a:lhs =~# ']' ? qfl[-1] : qfl[0]
    let idx = index(_qfl, entry) + 1
    " first, let's jump to the last/first entry in the current file
    exe (is_loclist ? 'll ' : 'cc ')..idx
    " ok, now we can run `:cnext`/`:cprevious`
    call s:next_or_wrap(a:lhs)
    call brackets#util#open_fold(a:lhs)
endfu
"}}}1
" Core {{{1
fu s:next_or_wrap(lhs) abort "{{{2
    let [cmd1, cmd2] = {
        \ ']q': ['cnext', 'cfirst'],
        \ '[q': ['cprevious', 'clast'],
        \ ']l': ['lnext', 'lfirst'],
        \ '[l': ['lprevious', 'llast'],
        \ }[a:lhs]
    try
        exe cmd1
    catch /^Vim\%((\a\+)\)\=:\%(E42\|E776\):/
        " the qfl is empty
        return lg#catch_error()
    catch /^Vim\%((\a\+)\)\=:E553:/
        " the qfl is not empty, but we've reached the start/end of the list; wrap around
        exe cmd2
    endtry
endfu

fu s:remove_entries_from_other_files(qfl, isloclist) abort "{{{2
    let curfile = expand('%:p')
    call filter(a:qfl, printf('fnamemodify(bufname(%s[v:key].bufnr), "%:p") is# curfile',
        \ a:isloclist ? 'getloclist(0)' : 'getqflist()'))
endfu

fu s:remove_entries_before_cursor(qfl, lhs) abort "{{{2
    let [lnum, col] = getcurpos()[1:2]
    " `>=` is necessary to handle the case where the cursor is right on the first entry of a file
    call filter(a:qfl, printf('v:val.lnum > lnum || (v:val.lnum == lnum && v:val.col %s col)',
        \ a:lhs =~# ']' ? '>' : '>='))
endfu

fu s:remove_entries_after_cursor(qfl, lhs) abort "{{{2
    let [lnum, col] = getcurpos()[1:2]
    " `<=` is necessary to handle the case where the cursor is right on the last entry of a file
    call filter(a:qfl, printf('v:val.lnum < lnum || (v:val.lnum == lnum && v:val.col %s col)',
        \ a:lhs =~# ']' ? '<=' : '<'))
endfu
"}}}1
" Utilities {{{1
fu s:is_too_big(is_loclist) abort "{{{2
    if a:is_loclist
        let size = getloclist(0, {'size': 0}).size
    else
        let size = getqflist({'size': 0}).size
    endif
    return size > s:MAX_SIZE
endfu

