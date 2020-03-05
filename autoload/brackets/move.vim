if exists('g:autoloaded_brackets#move')
    finish
endif
let g:autoloaded_brackets#move = 1

" Init {{{1
const s:LHS2CMD = {
    \ ']q': ['cnext', 'cfirst'],
    \ '[q': ['cprevious', 'clast'],
    \ ']l': ['lnext', 'lfirst'],
    \ '[l': ['lprevious', 'llast'],
    \ '] c-q': ['cnfile', 'cfirst'],
    \ '[ c-q': ['cpfile', 'clast'],
    \ '] c-l': ['lnfile', 'lfirst'],
    \ '[ c-l': ['lpfile', 'llast'],
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

fu brackets#move#cnext(lhs) abort "{{{2
    " Do *not* try to use `:cafter` & friends.{{{
    "
    " It  may seem  useful to  make our  custom commands  take into  account the
    " current cursor position.  However:
    "
    "    - it needs a lot of code to get it right (see commit ef1ea5b89864969e0725b64b5a1159396344ce81)
    "
    "    - it only works under the assumption that your qf entries are sorted by their buffer,
    "      line and column number; this is not always the case (e.g. `:WTF`)
    "}}}
    let cnt = v:count1
    let [cmd1, cmd2] = s:LHS2CMD[a:lhs]

    for i in range(cnt)
        try
            exe cmd1
        " no entry in the qfl
        catch /^Vim\%((\a\+)\)\=:E\%(42\|776\):/
            return lg#catch_error()
        " no more entry in the qfl; wrap around the edge
        catch /^Vim\%((\a\+)\)\=:E553:/
            exe cmd2
        endtry
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

