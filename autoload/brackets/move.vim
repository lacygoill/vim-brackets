if exists('g:autoloaded_brackets#move')
    finish
endif
let g:autoloaded_brackets#move = 1

" FAQ{{{1
" You sometimes write "current entry" in the comments.  What do you mean exactly?{{{2
"
" The current entry is the one reported by:
"
"     :echo getqflist({'idx':0}).idx
"
"}}}1

" Init {{{1
const s:LHS2CMD = {
    \ ']q': ['cafter', 'cbefore', 'cnext', 'cfirst'],
    \ '[q': ['cbefore', 'cafter', 'cprevious', 'clast'],
    \ ']l': ['lafter', 'lbefore', 'lnext', 'lfirst'],
    \ '[l': ['lbefore', 'lafter', 'lprevious', 'llast'],
    \ }

" Interface {{{1
fu brackets#move#next(lhs) abort "{{{2
    let cnt = v:count1
    " Do *not* use a `:try` conditional inside this function.{{{
    "
    " Inside a try conditional, `:next`/`:prev` fail when the next/previous argument
    " is not readable.
    "
    " https://github.com/vim/vim/issues/5451
    "}}}
    let argc = argc()
    if argc < 2
        echohl ErrorMsg | echo 'E163: There is only one file to edit' | echohl NONE
        return
    endif
    for i in range(cnt)
        let argidx = argidx()
        if a:lhs is# ']a' && argidx == argc - 1
            first
        elseif a:lhs is# '[a' && argidx == 0
            last
        elseif a:lhs is# ']a'
            next
        elseif a:lhs =~# '[a'
            prev
        endif
    endfor
endfu

fu brackets#move#tnext(lhs) abort "{{{2
    let cnt = v:count ? v:count : ''

    let [cmd1, cmd2] = {
        \ ']t': ['tnext', 'tfirst'],
        \ '[t': ['tprevious', 'tlast'],
        \ }[a:lhs]

    try
        exe cnt..cmd1
    " E73: tag stack empty
    catch /^Vim\%((\a\+)\)\=:E73:/
        return lg#catch_error()
    " E425: Cannot go before first matching tag
    " E428: Cannot go beyond last matching tag
    catch /^Vim\%((\a\+)\)\=:\%(E425\|E428\):/
        exe cmd2
    endtry
endfu

fu brackets#move#cafter(lhs) abort "{{{2
    let cnt = v:count1

    if &ft is# 'qf'
        sil exe (a:lhs =~# 'q' ? 'cc ' : 'll ')..line('.')
    endif

    " Nvim doesn't  support `:cafter`/`:cbefore`  yet; we  try to  emulate their
    " behavior in a special function.
    if has('nvim')
        for i in range(cnt)
            call brackets#move#nvim#qflist(a:lhs)
        endfor
        return
    endif
    for i in range(cnt)
        call s:cafter(a:lhs)
    endfor
    call brackets#util#open_fold(a:lhs)
endfu

fu brackets#move#cnewer(lhs) abort "{{{2
    let cnt = v:count1
    try
        for i in range(1, cnt)
            let cmd =  {
                \ '<q': 'colder',
                \ '>q': 'cnewer',
                \ '<l': 'lolder',
                \ '>l': 'lnewer',
                \ }[a:lhs]
            if i < cnt
                sil exe cmd
            else
                exe cmd
            endif
        endfor
    " we've reached the end of the qf stack (or it's empty)
    " E380: At bottom of quickfix stack
    " E381: At top of quickfix stack
    catch /^Vim\%((\a\+)\)\=:E38[01]:/
        " 8.1.1281 has not been merged in Vim yet.
        if has('nvim')
            return lg#catch_error()
        else
            redraw
            try
                exe {
                    \ '<q': getqflist({'nr': '$'}).nr ..'chi',
                    \ '>q': '1chi',
                    \ '<l': getloclist(0, {'nr': '$'}).nr ..'lhi',
                    \ '>l': '1lhi',
                    \ }[a:lhs]
            " the qf stack is empty
            " E16: Invalid range
            catch /^Vim\%((\a\+)\)\=:E16:/
                return lg#catch_error()
            endtry
        endif
    endtry
endfu

fu brackets#move#cnfile(lhs) abort "{{{2
    let cnt = v:count1
    if &ft is# 'qf'
        sil exe (a:lhs =~# 'q' ? 'cc ' : 'll ')..line('.')
    endif
    for i in range(cnt)
        call s:cnfile(a:lhs)
    endfor
endfu
"}}}1
" Core {{{1
fu s:cafter(lhs) abort "{{{2
    let [cmd1, cmd2, cmd3, cmd4] = s:LHS2CMD[a:lhs]
    try
        let pos = getcurpos()
        " for `]q`, try to visit next entry relative to current cursor position (via `:cafter`)
        exe cmd1
        " `:cafter` failed silently because the next entry has been deleted/moved,{{{
        " and its position does not exist anymore:
        "
        "     $ vim -Nu NONE +"%d|pu=['pat', '', 'xxx', 'xxx pat', '', '', 'pat']|sil vim /pat/ %" +'4j|1' /tmp/file
        "     :cafter
        "     " jumps on 1st "pat"
        "     :cafter
        "     " jumps on 5th line where the 2nd "pat" was originally (before `:j`)
        "     :cafter
        "     " no jump because the 5th column can't be reached;
        "     " the cursor is forever stuck before the non-existing position "line 5 col 5";
        "     " the third "pat" will never be reached unless the cursor is moved manually past "line 5 col 5"
        "}}}
        if pos == getcurpos()
            try
                " run `:cnext` to move past the non-existing position
                exe cmd3
            catch /^Vim\%((\a\+)\)\=:\%(E42\|E776\):/
                " the qfl is empty
                return lg#catch_error()
            endtry
        endif
    " What's the difference between{{{
    "}}}
    "   `E553` and `E42`?{{{
    "
    " In the  case of  `:cafter`, `E553` is  raised when there  is at  least one
    " entry in the buffer, but none of them is after the cursor.
    "
    " OTOH, `E42` is raised when there is no entry at all in the current buffer
    "
    " ---
    "
    " In the case  of `:cnext`, `E553` is  raised when there are  entries in the
    " quickfix list, but none of them are after the current one.
    " `E42` is raised when the qfl is empty.
    "}}}
    "   `E42` and `E776`?{{{
    "
    " `E776` is the equivalent of `E42` for the location list.
    "}}}
    catch /^Vim\%((\a\+)\)\=:\%(E553\|E42\|E776\):/
        try
            " It failed.  We need `:cnext`, but first, run `:cbefore|cafter` to be sure we're on last entry in file.{{{
            "
            " Otherwise, `:cnext` would move relative to the current entry which
            " may be *any* entry in the qfl; not necessarily the last entry in the
            " current file.
            "}}}
            sil! exe cmd2
            "  │{{{
            "  └ there could be no entry in the current file
            "}}}
            sil! exe cmd1
            "  │     │{{{
            "  │     └  if initially we were  not *after* the last  entry, but
            "  │     *on* the last  entry, the previous `:cbefore`  made us move
            "  │     onto the last-but-one entry; make sure we are on the *last*
            "  │     entry
            "  │
            "  └ OTOH, if we *were* on the last entry, `:cafter` will fail
            "  (or, again, there could be no entry in the file)
            "}}}

            " Warning: `:cbefore|cafter` may fail, which may give an unexpected result.{{{
            "
            " Suppose that:
            "
            "    - the current entry is not in the current file
            "    - the current file contains only 1 entry
            "    - your cursor is right on this unique entry
            "    - you press `]q` to visit the next entry
            "
            " The next entry will be chosen relative to the current entry.
            " That's not what we want.
            " We want it to be chosen relative to the entry of the current file.
            "
            " If there is only 1 entry  in the current file, both `:cbefore` and
            " `:cafter` fail.
            "
            " MWE:
            "
            "     $ echo "entry1\nentry2" >/tmp/file1 ; \
            "       echo "entry3" >/tmp/file2 ; \
            "       echo "entry4" >/tmp/file3 ; \
            "       vim /tmp/file{1..3} +'vim /entry/gj ##' +'cc 1|next'
            "
            "     " press ]q
            "     " without the next block, the current entry switches to `entry2` (✘) instead of `entry4` (✔)
            "}}}
            "   Why don't you write some special code to handle this case?{{{
            "
            " Indeed, we could write some special  code to make sure the current
            " entry is reset to the unique  entry in the current file, before we
            " can execute `:cnext`.
            "
            " I did in the past, but the bigger the qfl, the slower it is.
            " I even tried to include a timer-based guard to temporarily disable
            " the code, so that it's not run too many times in a short period of
            " time when we smash `;`.  It helped, but not for the first keypress.
            "}}}
            "   Why don't you't just move the cursor by 1 character before `:cbefore`/`:cafter`?{{{
            "
            " Let's assume we choose to move 1 character forward.
            "
            " The unique entry could be positioned  at the very end of the file;
            " in which case, there is no later position we could move to.
            " We would need some special code to detect the motion has failed, or will fail;
            " then we would need to move 1 character backward before running `:cafter`.
            " But what if there is no previous position either (only 1 character in the file)?
            "
            " Besides, moving the cursor  may change the view, which I  guess (?) is not
            " an issue  if `:cnext` succeeds,  but what if it  fails?  We would  need to
            " make sure the view and the cursor position are restored.
            "
            " Too many questions, too many code paths, too many possible pitfalls.
            "}}}
            "   Is it ok to not do anything?{{{
            "
            " I  think so.  It looks  like an edge-case that  in practice, we'll
            " rarely if ever encounter.
            "}}}

            " ok, now we can safely execute `:cnext`
            exe cmd3
        catch /^Vim\%((\a\+)\)\=:\%(E42\|E776\):/
            " the qfl is empty
            return lg#catch_error()
        catch /^Vim\%((\a\+)\)\=:E553:/
            " `:cnext` failed; wrap around the start of the list with `:cfirst`
            exe cmd4
        endtry
    endtry
endfu

fu s:cnfile(lhs) abort "{{{2
    " Nvim doesn't support `:cafter`/`:cbefore`.
    " We could try to emulate it, but it doesn't seem worth the trouble.
    " We rarely (never?) use `] C-q` & friends anyway.
    if has('nvim')
        let [cmd1, cmd2] = {
            \ ']q': ['cnfile', 'cfirst'],
            \ '[q': ['cpfile', 'clast'],
            \ ']l': ['lnfile', 'lfirst'],
            \ '[l': ['lpfile', 'llast'],
            \ }[a:lhs]
        try
            exe cmd1
        catch /^Vim\%((\a\+)\)\=:\%(E42\|E776\):/
            return lg#catch_error()
        catch /^Vim\%((\a\+)\)\=:E553:/
            exe cmd2
        endtry
        return
    endif

    let [cmd1, cmd2, cmd3, cmd4] = s:LHS2CMD[a:lhs]
    while 1
        try
            " for `] C-q`, run `:cafter` repeatedly, until you reach the last entry in the file
            sil exe cmd1
        " Why don't you bail out if `E42` or `E776` is raised?{{{
        "
        " It's too early.
        " If `:cafter` raises `E42`, it doesn't mean the qfl is empty yet.
        " It could just mean that there is no entry after the cursor in the current file.
        "}}}
        catch /^Vim\%((\a\+)\)\=:\%(E553\|E42\|E776\):/
            " We've finally reached the end of the list; break.{{{
            "
            " But first,  make sure the  current qf entry  is reset to  the last
            " entry in the  file (necessary in case we've pressed  `] C-q` while
            " the cursor was already after the last entry in the file).
            "}}}
            sil! exe cmd2
            sil! exe cmd1
            break
        endtry
    endwhile
    try
        " ok now we can run `:cnext`
        exe cmd3
    catch /^Vim\%((\a\+)\)\=:\%(E42\|E776\):/
        " there are no entries in the list; bail out
        return lg#catch_error()
    catch /^Vim\%((\a\+)\)\=:E553:/
        " we've reached the end of the list, get back to the start
        exe cmd4
    endtry
endfu

