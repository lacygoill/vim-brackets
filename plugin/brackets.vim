if exists('g:loaded_brackets')
    finish
endif
let g:loaded_brackets = 1

" Commands {{{1
" Ilist {{{2

"                                                ┌ command{{{
"                                                │
"                                                │   ┌ pattern is NOT word under cursor
"                                                │   │
"                                                │   │  ┌ do NOT start searching after current line
"                                                │   │  │  start from beginning of file
"                                                │   │  │
"                                                │   │  │   ┌ search in comments only if a bang is added
"                                                │   │  │   │
"                                                │   │  │   │        ┌ pattern
"                                                │   │  │   │        │}}}
com -bang -nargs=1 Ilist call brackets#di_list('i', 0, 0, <bang>0, <q-args>)
com -bang -nargs=1 Dlist call brackets#di_list('d', 0, 0, <bang>0, <q-args>)

" Mappings {{{1
" ]ablqt        move in lists {{{2
" Init {{{3

const s:MIL_CMD = {
              \   '<q': ['colder', ''],
              \   '>q': ['cnewer', ''],
              \   '<l': ['lolder', ''],
              \   '>l': ['lnewer', ''],
              \
              \   '[<c-l>': ['lpfile', ''],
              \   ']<c-l>': ['lnfile', ''],
              \   '[<c-q>': ['cpfile', ''],
              \   ']<c-q>': ['cnfile', ''],
              \
              \   '[A': ['first',      ''],
              \   ']A': ['last',       ''],
              \   '[B': ['bfirst',     ''],
              \   ']B': ['blast',      ''],
              \   '[L': ['lfirst',     ''],
              \   ']L': ['llast',      ''],
              \   '[Q': ['cfirst',     ''],
              \   ']Q': ['clast',      ''],
              \   '[T': ['tfirst',     ''],
              \   ']T': ['tlast',      ''],
              \
              \   '[a': ['previous',   'last'],
              \   ']a': ['next',       'first'],
              \   '[b': ['bprevious',  'blast'],
              \   ']b': ['bnext',      'bfirst'],
              \   '[l': ['lprevious',  'llast'],
              \   ']l': ['lnext',      'lfirst'],
              \   '[q': ['cprevious',  'clast'],
              \   ']q': ['cnext',      'cfirst'],
              \   '[t': ['tprevious',  'tlast'],
              \   ']t': ['tnext',      'tfirst'],
              \ }

" Functions {{{3
fu s:mil(lhs) abort "{{{4
    let cnt = (v:count ? v:count : '')

    let cmd1 = s:MIL_CMD[a:lhs][0]
    let cmd2 = s:MIL_CMD[a:lhs][1]
    try
        " FIXME: Sometimes, the command doesn't seem to be executed. Why?{{{
        "
        " MWE:
        "
        "     $ touch /tmp/file{1..3}
        "     $ sudo chown root:root /tmp/file3 && sudo chmod 600 /tmp/file3
        "     $ vim /tmp/file{1..3}
        "     :try | next | endtry
        "     @:
        "     :echo expand('%:p')
        "     /tmp/file3~
        "     :args
        "     /tmp/file1   [/tmp/file2] /tmp/file3~
        "                  ^^^^^^^^^^^^
        "
        " Why is the current argument still `/tmp/file2`, and not `/tmp/file3`?
        " If you had  removed the `try` conditional, the  current argument would
        " be `/tmp/file3`; why the difference?
        "
        "     :try | next | endtry
        "     " the current argument and the current file have not changed, and no error is raised
        "     " why?
        "
        "     :prev
        "     :try | next | endtry
        "     :try | next | endtry
        "     :args
        "     /tmp/file1   /tmp/file2   [/tmp/file3]~
        "                               ^^^^^^^^^^^^
        "     " this time, the current argument is correctly `/tmp/file3`
        "     " why did `:next` work now – to visit the last argument – but not before?
        "
        " ---
        "
        " It seems to be linked to the conditional `try`.
        " Because `:next` works outside of it.
        "
        " It only happens when an argument is a non-readable file/directory.
        " How to ignore non-readable files/directories?
        "
        " Ideas:
        "
        "     :args `=systemlist('find /etc -type f -maxdepth 1 -readable')`
        "
        " or:
        "
        "     :PA find /etc/ -maxdepth 1
        "
        " ---
        "
        " I can see 3 issues.
        "
        " First, the behavior of `:next` is inconsistent inside/outside a `try`
        " (it works as expected outside but not inside).
        "
        " Second, the behavior of `:next` is inconsistent inside a `try`
        " (it works as expected only after you fail to visit the unreadable
        " argument then run `:prev`).
        "
        " Third, if it is an error to ask Vim to read a non-readable file, then
        " the error  should be  catchable so that  I can react,  and ask  Vim to
        " visit the next argument if there is one (or the first if we've reached
        " the end of the arglist).
        "
        " ---
        "
        " Note that  when you ask Vim  to read a non-readable  file, usually, it
        " prints a message on the command-line to inform you that you can't read
        " the file:
        "
        "     /path/to/unreadable/file" [Permission Denied]
        "                               ^^^^^^^^^^^^^^^^^^^
        "
        " Unless you include the `F` flag in `'shm'`.
        "}}}
        exe cnt..cmd1
    catch
        try
            exe cmd2
        catch
            return lg#catch_error()
        endtry
    endtry

    " If an entry in the quickfix / location list is located inside folds, we
    " want them to be opened to see it directly.
    if a:lhs =~? '\v[lq]$|c-[lq]' && foldclosed('.') != -1
        norm! zv
    endif
endfu

fu s:mil_build_mapping(key, pfx) abort "{{{4
    let prev = '['..a:key
    let next = ']'..a:key
    exe 'nno  <silent><unique>  '..prev..'  :<c-u>call <sid>mil('..string(prev)..')<cr>'
    exe 'nno  <silent><unique>  '..next..'  :<c-u>call <sid>mil('..string(next)..')<cr>'

    let first = '['..toupper(a:key)
    let last  = ']'..toupper(a:key)
    exe 'nno  <silent><unique>  '..first..'  :<c-u>call <sid>mil('..string(first)..')<cr>'
    exe 'nno  <silent><unique>  '..last..'  :<c-u>call <sid>mil('..string(last)..')<cr>'

    " If a:pfx = 'c' then we also define the mappings `[ C-q` and `] C-q`
    " which execute the commands `:cpfile` and `:cnfile`:
    "
    "    - `:cpfile` = go to last error in the previous file in qfl.
    "    - `:cnfile` = go to first error in the next file in qfl.
    "
    " We do the same thing if a:pfx = 'l' :
    "
    "    - [ C-l mapped to `:lpfile`
    "    - ] C-l mapped to `:lnfile`
    "
    " We also do the same thing to move in the qf stack:
    "
    "   - <q >q    (qfl)
    "   - <l >l    (loclist)

    if a:pfx =~# '[cl]'
        if a:pfx is# 'c'
            let pqf_key = '<q'
            let nqf_key = '>q'

            let pfile_key = '[<c-q>'
            let nfile_key = ']<c-q>'
        else
            let pqf_key = '<l'
            let nqf_key = '>l'

            let pfile_key = '[<c-l>'
            let nfile_key = ']<c-l>'
        endif

        exe 'nno  <silent><unique>  '..pqf_key..'  :<c-u>call <sid>mil('..string(pqf_key)..')<cr>'
        exe 'nno  <silent><unique>  '..nqf_key..'  :<c-u>call <sid>mil('..string(nqf_key)..')<cr>'

        exe 'nno  <silent><unique>  '..pfile_key
        \ ..'  :<c-u>call <sid>mil('..substitute(string(pfile_key), '<', '<lt>', '')..')<cr>'
        exe 'nno  <silent><unique>  '..nfile_key
        \ ..'  :<c-u>call <sid>mil('..substitute(string(nfile_key), '<', '<lt>', '')..')<cr>'
    endif
endfu
"}}}3
" Installation {{{3
"
" Install a bunch of mappings to move in the:
"    arglist
"    buffer    list
"    location  list
"    quickfix  list
"    tag match list

call s:mil_build_mapping('a','')
call s:mil_build_mapping('b','b')
call s:mil_build_mapping('l','l')
call s:mil_build_mapping('q','c')
call s:mil_build_mapping('t','t')
"}}}3

" ]e            move line {{{2

nno <silent><unique> [e :<c-u>call brackets#mv_line_save_dir('up')<bar>set opfunc=brackets#mv_line<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> ]e :<c-u>call brackets#mv_line_save_dir('down')<bar>set opfunc=brackets#mv_line<bar>exe 'norm! '..v:count1..'g@l'<cr>

" ]f            move in files {{{2

nno <silent><unique> ]f :<c-u>e <c-r>=fnameescape(brackets#next_file_to_edit(v:count1))<cr><cr>
nno <silent><unique> [f :<c-u>e <c-r>=fnameescape(brackets#next_file_to_edit(-v:count1))<cr><cr>

" ]I            [di]list {{{2

"                                                           ┌ don't start to search at cursor,
"                                                           │ but at beginning of file
"                                                           │
"                                                           │  ┌ don't pass a bang to the commands
"                                                           │  │ normal commands don't accept one anyway
nno <silent><unique> [I :<c-u>call brackets#di_list('i', 1, 0, 0)<cr>
"                                                    │   │
"                                                    │   └ search current word
"                                                    └ command to execute (ilist or dlist)

xno <silent><unique> [I :<c-u>call brackets#di_list('i', 0, 0, 1)<cr>
"                                                        │
"                                                        └ don't search current word, but visual selection

nno <silent><unique> ]I :<c-u>call brackets#di_list('i', 1, 1, 0)<cr>
"                                                           │
"                                                           └ start to search after the line where the cursor is

xno <silent><unique> ]I :<c-u>call brackets#di_list('i', 0, 1, 1)<cr>

nno <silent><unique> [D :<c-u>call brackets#di_list('d', 1, 0, 0)<cr>
xno <silent><unique> [D :<c-u>call brackets#di_list('d', 0, 0, 1)<cr>

nno <silent><unique> ]D :<c-u>call brackets#di_list('d', 1, 1, 0)<cr>
xno <silent><unique> ]D :<c-u>call brackets#di_list('d', 0, 1, 1)<cr>

" ]p {{{2

" By default `]p` puts a copied line with the indentation of the current line.
" But if the copied text is characterwise, `]p` puts it as a characterwise text.
" We don't want that, we want the text to be put as linewise even if it was
" selected with a characterwise motion.

"                                                           ┌ how to put internally{{{
"                                                           │
"                                                           │    ┌ how to indent afterwards
"                                                           │    │}}}
nno <silent><unique> [p :<c-u>call brackets#put_save_param('[p', '')<bar>set opfunc=brackets#put<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> ]p :<c-u>call brackets#put_save_param(']p', '')<bar>set opfunc=brackets#put<bar>exe 'norm! '..v:count1..'g@l'<cr>

" The following mappings put the unnamed register after the current line,
" treating its contents as linewise (even if characterwise) AND perform another
" action:
"
"    - >p >P    add a level of indentation
"    - <p <P    remove a level of indentation
"    - =p =P    auto-indentation (respecting our indentation-relative options)
nno <silent><unique> >P :<c-u>call brackets#put_save_param('[p', ">']")<bar>set opfunc=brackets#put<bar>exe 'norm! '.v:count1.'g@l'<cr>
nno <silent><unique> >p :<c-u>call brackets#put_save_param(']p', ">']")<bar>set opfunc=brackets#put<bar>exe 'norm! '.v:count1.'g@l'<cr>
nno <silent><unique> <P :<c-u>call brackets#put_save_param('[p', "<']")<bar>set opfunc=brackets#put<bar>exe 'norm! '.v:count1.'g@l'<cr>
nno <silent><unique> <p :<c-u>call brackets#put_save_param(']p', "<']")<bar>set opfunc=brackets#put<bar>exe 'norm! '.v:count1.'g@l'<cr>
nno <silent><unique> =P :<c-u>call brackets#put_save_param('[p', "=']")<bar>set opfunc=brackets#put<bar>exe 'norm! '.v:count1.'g@l'<cr>
nno <silent><unique> =p :<c-u>call brackets#put_save_param(']p', "=']")<bar>set opfunc=brackets#put<bar>exe 'norm! '.v:count1.'g@l'<cr>

" A simpler version of the same mappings would be:
"
"     nno >P [p>']
"     nno >p ]p>']
"     nno <P [p<']
"     nno <p ]p<']
"     nno =P [p=']
"     nno =p ]p=']
"
" But with these ones, we would lose the linewise conversion.

" ]sS {{{2

" Why? {{{
"
" By default, `zh` and `zl` move the cursor on a long non-wrapped line.
" But at the same time, we use `zj` and `zk` to split the window.
" I don't like  the `hjkl` being used  with a same prefix (`z`)  for 2 different
" purposes.
" So, we'll  use `z[hjkl]` to split  the window, and  `[s` and `]s` to  scroll a
" long non-wrapped line.
"}}}
" Warning: this shadows the default `]s` command{{{
"
" ... which  moves the  cursor to  the next wrongly spelled word.
" It's not a big deal, because you can still use `]S` which does the same thing,
" ignoring rare words and words for other regions (which is what we usually want).
"}}}

nno <unique> [s 5zh
nno <unique> ]s 5zl
"             │
"             └ mnemonic: Scroll

" ] space {{{2

nno <silent><unique> =<space> :<c-u>set opfunc=brackets#put_lines_around<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> [<space> :<c-u>call brackets#put_line_save_param(0)<bar>set opfunc=brackets#put_line<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> ]<space> :<c-u>call brackets#put_line_save_param(1)<bar>set opfunc=brackets#put_line<bar>exe 'norm! '..v:count1..'g@l'<cr>

" ] - {{{2

nno <silent><unique> [- :<c-u>call brackets#rule_motion(0)<cr>
nno <silent><unique> ]- :<c-u>call brackets#rule_motion(1)<cr>

nno <silent><unique> <c-g>[- :<c-u>call brackets#rule_put(0)<cr>
nno <silent><unique> <c-g>]- :<c-u>call brackets#rule_put(1)<cr>

