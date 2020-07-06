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

const s:PATTERNS = {
    \ 'fu':            '^\s*\%(fu\%[nction]\|def\)!\=\s\+',
    \ 'endfu':         '^\s*\%(endf\%[unction]\|enddef\)\%(\s\|"\|$\)',
    \ 'sh_fu':         '^\s*\S\+\s*()\s*{\%(\s*#\s*{{'..'{\d*\s*\)\=$',
    \ 'sh_endfu':      '^}$',
    \ 'ref':           '\[.\{-1,}\](\zs.\{-1,})',
    \ 'path':          '\f*/\&\%(\%(^\|\s\|`\)\)\@1<=[./~]\f\+',
    \ 'url':           '\%(https\=\|ftps\=\|www\)://\|!\=\[.\{-}\]\%((.\{-})\|\[.\{-}\]\)',
    \ 'concealed_url': '\[.\{-}\zs\](.\{-})',
    \ 'codespan':      '`.\{-1,}`',
    \ 'shell_prompt':  '^٪',
    \ }

fu s:snr() abort
    return matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_')
endfu
let s:snr = get(s:, 'snr', s:snr())

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
        return lg#catch()
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
            return lg#catch()
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
    " E776: No location list
    catch /^Vim\%((\a\+)\)\=:\%(E380\|E381\|E776\):/
        " message from last list + message from first list = hit-enter prompt
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
        catch /^Vim\%((\a\+)\)\=:\%(E16\|E776\):/
            return lg#catch()
        endtry
    endtry
endfu

fu brackets#move#regex(kwd, is_fwd) abort "{{{2
    "               ┌ necessary to get the full  name of the mode, otherwise in
    "               │ operator-pending mode, we would get 'n' instead of 'no'
    "               │
    let mode = mode(1)

    " If we're in visual block mode, we can't pass `C-v` directly.
    " It's going to by directly typed on the command-line.
    " On the command-line, `C-v` means:
    "
    "     “insert the next character literally”
    "
    " The solution is to double `C-v`.
    if mode is# "\<c-v>"
        let mode = "\<c-v>\<c-v>"
    endif

    return printf(":\<c-u>call %sjump(%s,%d,%s)\<cr>",
        \ s:snr, string(a:kwd), a:is_fwd, string(mode))
endfu
"}}}1
" Core {{{1
fu s:jump(kwd, is_fwd, mode) abort "{{{2
    let cnt = v:count1
    let pat = get(s:PATTERNS, a:kwd, '')

    if empty(pat) | return | endif

    if a:mode is# 'n'
        norm! m'
    elseif a:mode =~# "^[vV\<c-v>]$"
        " If we  were initially  in visual mode,  we've left it  as soon  as the
        " mapping pressed Enter  to execute the call to this  function.  We need
        " to get back in visual mode, before the search.
        norm! gv
    endif

    while cnt > 0
        " Don't remove `W`; I like it.{{{
        "
        " For  example,  when I'm  cycling  through  urls  in a  markdown  files
        " searching for some link, I like knowing that I've visited them all.
        " If you remove `W`, we keep cycling as long as we press the mapping.
        "}}}
        call search(pat, (a:is_fwd ? '' : 'b')..'W')
        let cnt -= 1
    endwhile

    " the function shouldn't do anything in operator-pending mode
    if a:mode =~# "[nvV\<c-v>]"
        norm! zv
    endif
endfu

