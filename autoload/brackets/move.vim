vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Init {{{1

import Catch from 'lg.vim'

const LHS2CMD: dict<list<string>> = {
    ']q': ['cnext',     'cfirst'],
    '[q': ['cprevious', 'clast'],
    ']l': ['lnext',     'lfirst'],
    '[l': ['lprevious', 'llast'],
    '] c-q': ['cnfile', 'cfirst'],
    '[ c-q': ['cpfile', 'clast'],
    '] c-l': ['lnfile', 'lfirst'],
    '[ c-l': ['lpfile', 'llast'],
    }

const PATTERNS: dict<string> = {
    fu:            '^\C\s*\%(fu\%[nction]\|\%(export\s*\)\=def\)!\=\s\+',
    endfu:         '^\C\s*\%(endf\%[unction]\|enddef\)\%(\s\|"\|$\)',
    sh_fu:         '^\s*\S\+\s*()\s*{\%(\s*#\s*{{' .. '{\d*\s*\)\=$',
    sh_endfu:      '^}$',
    ref:           '\[.\{-1,}\](\zs.\{-1,})',
    path:          '\f*/\&\%(\%(^\|\s\|`\)\)\@1<=[./~]\f\+',
    url:           '\C\%(https\=\|ftps\=\|www\)://\|!\=\[.\{-}\]\%((.\{-})\|\[.\{-}\]\)',
    concealed_url: '\[.\{-}\zs\](.\{-})',
    codespan:      '`.\{-1,}`',
    shell_prompt:  '^٪',
    }

# Interface {{{1
def brackets#move#next(lhs: string) #{{{2
    var cnt: number = v:count1
    # Do *not* use a `:try` conditional inside this function.{{{
    #
    # Inside a try conditional, `:next`/`:prev` fail when the next/previous argument
    # is not readable.
    #
    # https://github.com/vim/vim/issues/5451
    #}}}
    var argc: number = argc()
    if argc < 2
        echohl ErrorMsg
        echo 'E163: There is only one file to edit'
        echohl NONE
        return
    endif
    for i in range(cnt)
        var argidx: number = argidx()
        if lhs == ']a' && argidx == argc - 1
            first
        elseif lhs == '[a' && argidx == 0
            last
        elseif lhs == ']a'
            next
        elseif lhs =~ '[a'
            prev
        endif
    endfor
enddef

def brackets#move#tnext(lhs: string) #{{{2
    var cnt: string = v:count ? v:count->string() : ''

    var cmd1: string
    var cmd2: string
    [cmd1, cmd2] = {
        ']t': ['tnext', 'tfirst'],
        '[t': ['tprevious', 'tlast'],
        }[lhs]

    try
        exe cnt .. cmd1
    # E73: tag stack empty
    catch /^Vim\%((\a\+)\)\=:E73:/
        Catch()
        return
    # E425: Cannot go before first matching tag
    # E428: Cannot go beyond last matching tag
    catch /^Vim\%((\a\+)\)\=:\%(E425\|E428\):/
        exe cmd2
    endtry
enddef

def brackets#move#cnext(lhs: string) #{{{2
    # Do *not* try to use `:cafter` & friends.{{{
    #
    # It  may seem  useful to  make our  custom commands  take into  account the
    # current cursor position.  However:
    #
    #    - it needs a lot of code to get it right (see commit ef1ea5b89864969e0725b64b5a1159396344ce81)
    #
    #    - it only works under the assumption that your qf entries are sorted by their buffer,
    #      line and column number; this is not always the case (e.g. `:WTF`)
    #}}}
    var cnt: number = v:count1
    var cmd1: string
    var cmd2: string
    [cmd1, cmd2] = LHS2CMD[lhs]

    for i in range(cnt)
        try
            exe cmd1
        # no entry in the qfl
        catch /^Vim\%((\a\+)\)\=:E\%(42\|776\):/
            Catch()
            return
        # no more entry in the qfl; wrap around the edge
        catch /^Vim\%((\a\+)\)\=:E553:/
            exe cmd2
        # E92: Buffer 123 not found
        # can happen if the buffer has been wiped out since the last time you visited it
        catch /^Vim\%((\a\+)\)\=:E92:/
            Catch()
            return
        endtry
    endfor

    brackets#util#openFold(lhs)
enddef

def brackets#move#cnewer(lhs: string) #{{{2
    var cnt: number = v:count1
    try
        for i in range(1, cnt)
            var cmd: string = {
                '<q': 'colder',
                '>q': 'cnewer',
                '<l': 'lolder',
                '>l': 'lnewer',
                }[lhs]
            if i < cnt
                sil exe cmd
            else
                exe cmd
            endif
        endfor
    # we've reached the end of the qf stack (or it's empty)
    # E380: At bottom of quickfix stack
    # E381: At top of quickfix stack
    # E776: No location list
    catch /^Vim\%((\a\+)\)\=:\%(E380\|E381\|E776\):/
        # message from last list + message from first list = hit-enter prompt
        redraw
        try
            exe {
                '<q': getqflist({nr: '$'}).nr .. 'chi',
                '>q': '1chi',
                '<l': getloclist(0, {nr: '$'}).nr .. 'lhi',
                '>l': '1lhi',
                }[lhs]
        # the qf stack is empty
        # E16: Invalid range
        catch /^Vim\%((\a\+)\)\=:\%(E16\|E776\):/
            Catch()
            return
        endtry
    endtry
enddef

def brackets#move#regex(kwd: string, is_fwd: bool): string #{{{2
    #                       ┌ necessary to get the full  name of the mode, otherwise in
    #                       │ operator-pending mode, we would get 'n' instead of 'no'
    #                       │
    var mode: string = mode(true)
    # If we're in visual block mode, we can't pass `C-v` directly.{{{
    #
    # Since  8.2.2062,  `<cmd>`  handles  `C-v`  just like  it  would  be  on  a
    # command-line entered  with `:`.  That  is, it's interpreted as  "insert the
    # next character literally".
    #
    # Solution: double `<C-v>`.
    #}}}
    return printf("\<cmd>call %s(%s, %d, %s)\<cr>",
        Jump, string(kwd), is_fwd ? 1 : 0, string(mode))
enddef
#}}}1
# Core {{{1
def Jump(kwd: string, is_fwd: bool, mode: string) #{{{2
    var cnt: number = v:count1
    var pat: string = get(PATTERNS, kwd, '')

    if empty(pat)
        return
    endif

    if mode == 'n'
        norm! m'
    endif

    while cnt > 0
        # Don't remove `W`; I like it.{{{
        #
        # For  example,  when I'm  cycling  through  urls  in a  markdown  files
        # searching for some link, I like knowing that I've visited them all.
        # If you remove `W`, we keep cycling as long as we press the mapping.
        #}}}
        search(pat, (is_fwd ? '' : 'b') .. 'W')
        cnt -= 1
    endwhile

    # the function shouldn't do anything in operator-pending mode
    if mode =~ "[nvV\<c-v>]"
        norm! zv
    endif
enddef

