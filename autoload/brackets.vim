import {Catch, GetSelection} from 'lg.vim'

" Interface {{{1
fu brackets#di_list(cmd, search_cur_word, start_at_cursor, search_in_comments, ...) abort "{{{2
    " Derive the commands used below from the first argument.
    let excmd = a:cmd .. 'list' .. (a:search_in_comments ? '!' : '')
    let normcmd = toupper(a:cmd)

    " if we call the function from a normal mode mapping, the pattern is the
    " word under the cursor
    if a:search_cur_word
        " `silent!` because pressing `]I` on a unique word raises `E389`
        let output = execute('norm! ' .. (a:start_at_cursor ? ']' : '[') .. normcmd, 'silent!')
        let title = (a:start_at_cursor ? ']' : '[') .. normcmd

    else
        " otherwise if the function was called with a fifth optional argument,
        " by one of our custom Ex command, use it as the pattern
        if a:0 > 0
            let pat = a:1
        else
            " otherwise the function must have been called from visual mode
            " (visual mapping): use the visual selection as the pattern
            let pat = s:GetSelection()

            " `:ilist` can't find a multiline pattern
            if len(pat) != 1 | return s:error('E389: Couldn''t find pattern') | endif
            let pat = pat[0]

            " make sure the pattern is interpreted literally
            let pat = '\V' .. escape(pat, '\/')
        endif

        let output = execute((a:start_at_cursor ? '+,$' : '') .. excmd .. ' /' .. pat, 'silent!')
        let title = excmd .. ' /' .. pat
    endif

    let lines = split(output, '\n')
    " bail out on errors
    if get(lines, 0, '') =~ '^Error detected\|^$'
        return s:error('Could not find ' .. string(a:search_cur_word ? expand('<cword>') : pat))
    endif

    " Our results may span multiple files so we need to build a relatively
    " complex list based on filenames.
    let filename = ''
    let ll_entries = []
    for line in lines
        " A line in the output of `:ilist` and `dlist` can be a filename.
        " It happens when there are matches in other included files.
        " It's how `:ilist` / `:dlist`tells us in which files are the
        " following entries.
        "
        " When we find such a line, we don't parse its text to add an entry
        " in the ll, as we would do for any other line.
        " We use it to update the variable `filename`, which in turn is used
        " to generate valid entries in the ll.
        if line !~ '^\s*\d\+:'
            let filename = fnamemodify(line, ':p:.')
        "                                      │ │{{{
        "                                      │ └ relative to current working directory
        "                                      └ full path
        "}}}
        else
            let lnum = split(line)[1]

            " remove noise from the text output:
            "
            "    1:   48   line containing pattern
            " ^__________^
            "     noise

            let text = substitute(line, '^\s*\d\{-}\s*:\s*\d\{-}\s', '', '')

            let col = match(text, a:search_cur_word ? '\C\<' .. expand('<cword>') .. '\>' : pat) + 1
            call add(ll_entries, #{
                \ filename: filename,
                \ lnum: lnum,
                \ col: col,
                \ text: text,
                \ })
        endif
    endfor

    call setloclist(0, [], ' ', {'items': ll_entries, 'title': title})

    " Populating the location list doesn't fire any event.
    " Fire `QuickFixCmdPost`, with the right pattern (*), to open the ll window.
    "
    " (*) `lvimgrep`  is a  valid pattern (`:h  QuickFixCmdPre`), and  it begins
    " with a `l`.   The autocmd that we  use to automatically open  a qf window,
    " relies on  the name  of the  command (how its  name begins),  to determine
    " whether it must open the ll or qfl window.
    do <nomodeline> QuickFixCmdPost lwindow
    if &bt isnot# 'quickfix' | return | endif

    " hide location
    call qf#set_matches('brackets:di_list', 'Conceal', 'location')
    call qf#create_matches()
endfu

fu brackets#mv_line_setup(dir) abort "{{{2
    let s:mv_line_dir = a:dir
    let &opfunc = expand('<SID>') .. 'mv_line'
    return 'g@l'
endfu

fu brackets#next_file_to_edit(cnt) abort "{{{2
    let here = expand('%:p')
    let cnt = a:cnt

    " If we start Vim without any file argument, `here` is empty.
    " It doesn't cause any pb to move forward (`]f`), but it does if we try
    " to move backward (`[f`), because we end up stuck in a loop with:   here  =  .
    "
    " To fix this, we reset `here` by giving it the path to the working directory.
    if empty(here)
        let here = getcwd() .. '/'
    endif

    " The main code of this function is a double nested loop.
    " We use both to move in the tree:
    "
    "    - the outer loop    to climb up    the tree
    "    - the inner loop    to go down     the tree
    "
    " We also use the outer loop to determine when to stop:
    " once `cnt` reaches 0.
    " Indeed, at the end of each iteration, we get a previous/next file.
    " It needs to be done exactly `cnt` times (by default 1).
    " So, at the end of each iteration, we update `cnt`, by [in|de]crementing it.
    while cnt != 0
        let entries = fnamemodify(here, ':h')->s:what_is_around()

        " We use `a:cnt` instead of `cnt` in our test, because `cnt` is going
        " to be [in|de]cremented during the execution of the outer loop.
        if a:cnt > 0
            " remove the entries whose names come BEFORE the one of the current
            " entry, and sort the resulting list
            call filter(entries, {_, v -> v ># here})->sort()
        else
            " remove the entries whose names come AFTER the one of the current
            " entry, sort the resulting list, and reverse the order
            " (so that the previous entry comes first instead of last)
            call filter(entries, {_, v -> v <# here})->sort()->reverse()
        endif
        let next_entry = get(entries, 0, '')

        " If inside the current directory, there's no other entry before/after
        " the current one (depends in which direction we're looking)
        " then we update `here`, by replacing it with its parent directory.
        " We don't update `cnt` (because we haven't found a valid file), and get
        " right back to the beginning of the main loop.
        " If we end up in an empty directory, deep inside the tree, this will
        " allow us to climb up as far as needed.
        if empty(next_entry)
            let here = fnamemodify(here, ':h')

        else
            " If there IS another entry before/after the current one, store it
            " inside `here`, to correctly set up the next iteration of the main loop.
            let here = next_entry

            " We're only interested in a file, not a directory.
            " And if it's a directory, we don't know how far is the next file.
            " It could be right inside, or inside a sub-sub-directory …
            " So, we need to check whether what we found is a directory, and go on
            " until we find an entry which is a file.  Thus a 2nd loop.
            "
            " Each time we find an entry which is a directory, we look at its
            " contents.
            " If at some point, we end up in an empty directory, we simply break
            " the inner loop, and get right back at the beginning of the outer
            " loop.
            " The latter will make us climb up as far as needed to find a new
            " file entry.
            "
            " OTOH, if there's something inside a directory entry, we update
            " `here`, by storing the first/last entry of its contents.
            let found_a_file = 1

            while isdirectory(here)
                let entries = s:what_is_around(here)
                if empty(entries)
                    let found_a_file = 0
                    break
                endif
                let here = entries[cnt > 0 ? 0 : -1]
            endwhile

            " Now  that `here`  has been  updated, we  also need  to update  the
            " counter.  For  example, if we've  hit `3]f`, we need  to decrement
            " `cnt` by one.
            " But, we only update it if we didn't ended up in an empty directory
            " during the inner loop.
            " Because in this case, the value of `here` is this empty directory.
            " And that's not a valid entry for us, we're only interested in
            " files.
            if found_a_file
                let cnt += cnt > 0 ? -1 : 1
            endif
        endif
    endwhile
    return here
endfu

fu s:what_is_around(dir) abort
    " If `dir` is the root of the tree, we need to get rid of the
    " slash, because we're going to add a slash when calling `glob('/*')`.
    let dir = substitute(a:dir, '/$', '', '')
    let entries = glob(dir .. '/.*', 0, 1)
    let entries += glob(dir .. '/*', 0, 1)

    " The first call to `glob()` was meant to include the hidden entries,
    " but it produces 2 garbage entries which do not exist.
    " For example, if `a:dir` is `/tmp`, the 1st command will
    " produce, among other valid entries:
    "
    "         /tmp/.
    "         /tmp/..
    "
    " We need to get rid of them.
    call filter(entries, {_, v -> v !~# '/\.\.\=$'})

    return entries
endfu

fu brackets#put_setup(where, how_to_indent) abort "{{{2
    let s:put = {
        \ 'where': a:where,
        \ 'how_to_indent': a:how_to_indent,
        \ 'register': v:register,
        \ }
    let &opfunc = expand('<SID>') .. 'put'
    return 'g@l'
endfu

fu brackets#put_line_setup(dir) abort "{{{2
    let s:put_line_below = a:dir is# ']'
    let &opfunc = expand('<SID>') .. 'put_line'
    return 'g@l'
endfu

fu brackets#put_lines_around(...) abort "{{{2
    if !a:0
        let &opfunc = 'brackets#put_lines_around'
        return 'g@l'
    endif
    " above
    let s:put_line_below = v:false
    call s:put_line('')

    " below
    let s:put_line_below = v:true
    call s:put_line('')
endfu

fu brackets#rule_motion(below, ...) abort "{{{2
    let cnt = v:count1
    " after this function has been called from the command-line, we're in normal
    " mode; we need to get back to visual mode so that the search motion extends
    " the visual selection, instead of just moving the cursor
    if a:0 && a:1 is# 'vis' | exe 'norm! gv' | endif
    let cml = '\V' .. matchstr(&l:cms, '\S*\ze\s*%s')->escape('\') .. '\m'
    let flags = (a:below ? '' : 'b') .. 'W'
    for i in range(1, cnt)
        if &ft is# 'markdown'
            let pat = '^---$'
            let stopline = search('^#', flags .. 'n')
        else
            let pat = '^\s*' .. cml .. ' ---$'
            let fmr = '\%(' .. split(&l:fmr, ',')->join('\|') .. '\)\d*'
            let stopline = search('^\s*' .. cml .. '.*' .. fmr .. '$', flags .. 'n')
        endif
        let lnum = search(pat, flags .. 'n')
        if stopline == 0 || (a:below && lnum < stopline || !a:below && lnum > stopline)
            call search(pat, flags, stopline)
        endif
    endfor
endfu

fu brackets#rule_put(below) abort "{{{2
    call append('.', ["\x01", '---', "\x01", "\x01"])
    if &ft isnot# 'markdown'
        +,+4CommentToggle
    endif
    sil keepj keepp +,+4s/\s*\%x01$//e
    if &ft isnot# 'markdown'
        sil exe 'norm! V3k=3jA '
    endif
    if !a:below
        -4m.
        exe 'norm! ' .. (&ft is# 'markdown' ? '' : '==') .. 'k'
    endif
    startinsert!
endfu
"}}}1
" Core {{{1
fu s:mv_line(_) abort "{{{2
    let cnt = v:count1

    " disabling the folds may alter the view, so save it first
    let view = winsaveview()

    " Why do you disable folding?{{{
    "
    " We're going to do 2 things:
    "
    "    1. move a / several line(s)
    "    2. update its / their indentation
    "
    " If we're inside a fold, the `:move` command will close it.
    " Why?
    " Because of patch  `7.4.700`.  It solves one problem related  to folds, and
    " creates a new one:
    " https://github.com/vim/vim/commit/d5f6933d5c57ea6f79bbdeab6c426cf66a393f33
    "
    " Then, it gets worse: because the fold is now closed, the indentation
    " command will indent the whole fold, instead of the line(s) on which we
    " were operating.
    "
    " MWE:
    "
    "     $ echo "fold\nfoo\nbar\nbaz\n" >/tmp/file && vim -Nu NONE /tmp/file
    "     :set fdm=marker
    "     VGzf
    "     zv
    "     j
    "     :m + | norm! ==
    "     5 lines indented ✘ it should be just one~
    "
    " Maybe we could use  `norm! zv` to open the folds, but  it would be tedious
    " and error-prone in the future.  Every time  we would add a new command, we
    " would have  to remember  to use  `norm! zv`.   It's better  to temporarily
    " disable folding entirely.
    "
    " Remember:
    " Because of a quirk of Vim's implementation, always temporarily disable
    " 'fen' before moving lines which could be in a fold.
    "}}}
    let [fen_save, winid, bufnr] = [&l:fen, win_getid(), bufnr('%')]
    let &l:fen = 0
    try
        " Why do we mark the line since we already saved the view?{{{
        "
        " Because,  after  the restoration  of  the  view,  the cursor  will  be
        " positioned on the old address of the line we moved.
        " We don't want that.
        " We want  the cursor to be  positioned on the same  line, whose address
        " has changed.   We can't  rely on an  address, so we  need to  mark the
        " current line.  The mark will follow the moved line, not an address.
        "}}}
        " Vim doesn't provide the concept of extended mark; use a dummy text property instead
        call prop_type_add('tempmark', #{bufnr: bufnr('%')})
        call prop_add(line('.'), col('.'), #{type: 'tempmark'})

        " move the line
        if s:mv_line_dir is# '['
            " Why this convoluted `:move` just to move a line?  Why don't you simply move the line itself?{{{
            "
            " To preserve the text property.
            "
            " To move a line, internally, Vim  first copies it at some other
            " location, then removes the original.
            " The copy  does not inherit the  text property, so in  the end,
            " the latter  is lost.   But we  need it  to restore  the cursor
            " position.
            "
            " As a workaround, we don't move the line itself, but its direct
            " neighbor.
            "}}}
            exe '-' .. cnt .. ',-m.|-' .. cnt
        else
            " `sil!` suppresses `E16` when reaching the end of the buffer
            sil! exe '+,+1+' .. (cnt-1) .. 'm-|+'
        endif

        " indent the line
        if &ft isnot# 'markdown' && &ft != ''
            sil norm! ==
        endif
    catch
        return s:Catch()
    finally
        " restoration and cleaning
        if winbufnr(winid) == bufnr
            let [tabnr, winnr] = win_id2tabwin(winid)
            call settabwinvar(tabnr, winnr, '&fen', fen_save)
        endif
        " restore the view *after* re-enabling folding, because the latter may alter the view
        call winrestview(view)
        " restore cursor position
        " use the text property to restore the cursor position
        let info = [prop_find(#{type: 'tempmark'}, 'f'), prop_find(#{type: 'tempmark'}, 'b')]
        call filter(info, {_, v -> !empty(v)})
        if !empty(info)
            call cursor(info[0].lnum, info[0].col)
        endif
        " remove the text property
        call prop_remove(#{type: 'tempmark', all: v:true})
        call prop_type_delete('tempmark', #{bufnr: bufnr('%')})
    endtry
endfu

fu s:put(_) abort "{{{2
    let cnt = v:count1

    " If the register is empty, an error should be raised.{{{
    "
    " And we want the exact message we would  have, if we were to try to put the
    " register without our mapping.
    "
    " That's the whole purpose of the next `:norm`:
    "
    "     Vim(normal):E353: Nothing in register "~
    "     Vim(normal):E32: No file name~
    "     Vim(normal):E30: No previous command line~
    "     ...~
    "}}}
    if getreg(s:put.register, 1, 1) == []
        try
            exe 'norm! "' .. s:put.register .. 'p'
        catch
            return s:Catch()
        endtry
    endif

    if s:put.register =~# '[/:%#.]'
        " The type of the register we put needs to be linewise.
        " But some registers are special: we can't change their type.
        " So, we'll temporarily duplicate their contents into `z` instead.
        let reg_save = getreginfo('z')
    else
        let reg_save = getreginfo(s:put.register)
    endif

    " Warning: about folding interference{{{
    "
    " If one of  the lines you paste  is recognized as the beginning  of a fold,
    " and you  paste using  `<p` or  `>p`, the  folding mechanism  may interfere
    " unexpectedly, causing too many lines to be indented.
    "
    " You could prevent that by temporarily disabling 'fen'.
    " But doing so will sometimes make the view change.
    " So, you would also need to save/restore the view.
    " But doing so  will position the cursor right back  where you were, instead
    " of the first line of the pasted text.
    "
    " All in all, trying to fix this rare issue seems to cause too much trouble.
    " So, we don't.
    "}}}
    try
        if s:put.register =~# '[/:%#.]'
            let reg_to_use = 'z'
            call getreginfo(s:put.register)->extend({'regtype': 'l'})->setreg('z')
        else
            let reg_to_use = s:put.register
        endif

        " If  we've just  sourced some  line of  code in  a markdown  file, with
        " `+s{text-object}`, the register `o` contains its output.
        " We want it to be highlighted as a code output, so we append `~` at the
        " end of every non-empty line.
        if reg_to_use is# 'o'
            \ && &ft is# 'markdown'
            \ && synID('.', col('.'), 1)->synIDattr('name') =~# '^markdown.*CodeBlock$'
            let contents = getreg('o', 1, 1)
            call map(contents, {_, v -> v != '' ? v .. '~' : v})
            call setreg('o', contents, 'l')
        endif

        " force the type of the register to be linewise
        call getreginfo(reg_to_use)->extend({'regtype': 'l'})->setreg(reg_to_use)

        " put the register (`s:put.where` can be `]p` or `[p`)
        exe 'norm! "' .. reg_to_use .. cnt .. s:put.where .. s:put.how_to_indent

        " make sure the cursor is on the first non-whitespace
        call search('\S', 'cW')
    catch
        return s:Catch()
    finally
        call setreg(reg_to_use, reg_save)
    endtry
endfu

fu s:put_line(_) abort "{{{2
    let cnt = v:count1
    let line = getline('.')
    let cml = '\V' .. matchstr(&l:cms, '\S*\ze\s*%s')->escape('\') .. '\m'

    let is_first_line_in_diagram = line =~# '^\s*\%(' .. cml .. '\)\=├[─┐┘ ├]*$'
    let is_in_diagram = line =~# '^\s*\%(' .. cml .. '\)\=\s*[│┌┐└┘├┤]'
    if is_first_line_in_diagram
        if s:put_line_below && line =~# '┐' || !s:put_line_below && line =~# '┘'
            let line = ''
        else
            let line = substitute(line, '[^├]', ' ', 'g')
            let line = substitute(line, '├', '│', 'g')
        endif
    elseif is_in_diagram
        let line = substitute(line, '\%([│┌┐└┘├┤].*\)\@<=[^│┌┐└┘├┤]', ' ', 'g')
        let l:Rep = {m ->
            \    m[0] is# '└' && s:put_line_below
            \ || m[0] is# '┌' && !s:put_line_below
            \ ? '' : '│'}
        let line = substitute(line, '[└┌]', Rep, 'g')
    else
        let line = ''
    endif
    let line = substitute(line, '\s*$', '', '')
    let lines = repeat([line], cnt)

    let lnum = line('.') + (s:put_line_below ? 0 : -1)
    " if we're in a closed fold, we don't want to simply add an empty line,
    " we want to create a visual separation between folds
    let [fold_begin, fold_end] = [foldclosed('.'), foldclosedend('.')]
    let is_in_closed_fold = fold_begin != -1

    if is_in_closed_fold && &ft is# 'markdown'
        " for  a  markdown  buffer,  where  we  use  a  foldexpr,  a  visual
        " separation means an empty fold
        let prefix = getline(fold_begin)->matchstr('^#\+')
        " fold marked by a line starting with `#`
        if prefix =~# '#'
            if prefix is# '#' | let prefix = '##' | endif
            let lines = repeat([prefix], cnt)
        " fold marked by a line starting with `===` or `---`
        elseif getline(fold_begin+1)->matchstr('^===\|^---') != ''
            let lines = repeat(['---', '---'], cnt)
        endif
        let lnum = s:put_line_below ? fold_end : fold_begin - 1
    endif

    " could fail if the buffer is unmodifiable
    try
        call append(lnum, lines)
        " Why?{{{
        "
        " By default, we  set the foldmethod to `manual`, because  `expr` can be
        " much more expensive.
        " As a  consequence, when you  insert a  new fold, it's  not immediately
        " detected as such; not until you've temporarily switched to `expr`.
        " That's what `#compute()` does.
        "}}}
        if &ft is# 'markdown' && lines[0] =~# '^[#=-]'
            sil! call fold#lazy#compute()
        endif
    catch
        return s:Catch()
    endtry
endfu
"}}}1
" Util {{{1
fu s:error(msg) abort "{{{2
    echohl ErrorMsg
    echom a:msg
    echohl NONE
endfu
