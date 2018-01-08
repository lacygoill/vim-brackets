fu! brackets#di_list(cmd, search_cur_word, start_at_cursor, search_in_comments, ...) abort "{{{1
    " Derive the commands used below from the first argument.
    let excmd   = a:cmd.'list'.(a:search_in_comments ? '!' : '')
    let normcmd = toupper(a:cmd)

    " if we call the function from a normal mode mapping, the pattern is the
    " word under the cursor
    if a:search_cur_word
        let output = execute('norm! '.(a:start_at_cursor ? ']' : '[').normcmd, 'silent!')
        let title       = (a:start_at_cursor ? ']' : '[').normcmd

    else
        " otherwise if the function was called with a fifth optional argument,
        " by one of our custom Ex command, use it as the pattern
        if a:0 > 0
            let search_pattern = a:1
        else
        " otherwise the function must have been called from visual mode
        " (visual mapping): use the visual selection as the pattern
            call lg#reg#save(['"', '+'])

            norm! gvy
            let search_pattern = substitute('\V'.escape(getreg('"'), '\/'), '\\n', '\\n', 'g')
            "                                │                               │
            "                                │                               └── make sure newlines are not
            "                                │                                   converted into NULs
            "                                │                                   on the search command line
            "                                │
            "                                └── make sure the contents of the pattern is interpreted literally

            call lg#reg#restore(['"', '+'])
        endif

        let output = execute((a:start_at_cursor ? '+,$' : '').excmd.' /'.search_pattern, 'silent!')
        let title  = excmd.' /'.search_pattern
    endif

    let lines = split(output, '\n')
    " Bail out on errors. (bail out = se désister)
    if get(lines, 0, '') =~ '^Error detected\|^$'
        echom 'Could not find '.string(a:search_cur_word ? expand('<cword>') : search_pattern)
        return
    endif

    " Our results may span multiple files so we need to build a relatively
    " complex list based on filenames.
    let filename   = ''
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
        "                                      │ │
        "                                      │ └── relative to current working directory
        "                                      └── full path
        else
            let l:lnum = split(line)[1]

            " remove noise from the text output:
            "
            "    1:   48   line containing pattern
            " ^__________^
            "     noise

            let text = substitute(line, '^\s*\d\{-}\s*:\s*\d\{-}\s', '', '')

            let col  = match(text, a:search_cur_word ? expand('<cword>') : search_pattern) + 1
            call add(ll_entries,
            \                    { 'filename' : filename,
            \                      'lnum'     : l:lnum,
            \                      'col'      : col,
            \                      'text'     : text, })
        endif
    endfor

    call setloclist(0, ll_entries)
    call setloclist(0, [], 'a', {'title': title})

    " Populating the location list doesn't fire any event.
    " Fire `QuickFixCmdPost`, with the right pattern (!), to open the ll window.
    "
    " (!) lvimgrep is a valid pattern  (`:h QuickFixCmdPre`), and it begins with
    " a `l`.  The autocmd that we use  to automatically open a qf window, relies
    " on the name of the command (how  its name begins), to determine whether it
    " must open the ll or qfl window.
    doautocmd <nomodeline> QuickFixCmdPost lgrep

    if &bt !=# 'quickfix'
        return
    endif

    " hide location
    call qf#set_matches('brackets:di_list', 'Conceal', 'location')
    call qf#create_matches()
endfu

fu! s:getchar() "{{{1
    let c = getchar()
    if c =~ '^\d\+$'
        let c = nr2char(c,1)
    endif
    return c =~ "\e\|\<c-c>"
    \?         ''
    \:         c
endfu

fu! brackets#mv_line(what) abort "{{{1
    let cnt   = v:count1

    let where = a:what ==# 'line_up'
    \?              '-1-'
    \:              '+'

    let where .= cnt

    " I'm not sure, but disabling the folds may alter the view, so save it first
    let view = winsaveview()

    let z_save = getpos("'z")

    " Why do we disable folding?{{{
    " We're going to do 2 things:
    "
    "         1. move a / several line(s)
    "         2. update its / their indentation
    "
    " If we're inside a fold, the `:move` command will close it.
    " Why?
    " Because of patch `7.4.700`. It solves one problem related to folds, and
    " creates a new one:
    " https://github.com/vim/vim/commit/d5f6933d5c57ea6f79bbdeab6c426cf66a393f33
    "
    " Then, it gets worse: because the fold is now closed, the indentation
    " command will indent the whole fold, instead of the line(s) on which we
    " were operating.
    "
    " Watch:
    "         echo "fold\nfoo\nbar\nbaz\n" >file
    "         vim -Nu NONE file
    "         :set fdm=marker
    "         VGzf
    "         zv
    "         j
    "         :m + | norm! ==
    "
    "             → 5 lines indented
    "               │
    "               └─ ✘ it should be just one
    "
    " Maybe we could use `norm! zv` to open the folds, but it would be tedious
    " and error-prone in the future. Every time we would add a new command, we
    " would have to remember to use `norm! zv`. It's better to temporarily disable
    " folding entirely.
    "
    " Remember:
    " Because of a quirk of Vim's implementation, always temporarily disable
    " 'fen' before moving lines which could be in a fold.
"}}}
    let fen_save = &l:fen
    let &l:fen   = 0

    try
        " Why do we mark the line since we already saved the view?{{{
        " Because, after the restoration of the view, the cursor will be
        " positioned on the old address of the line we moved.
        " We don't want that.
        " We want the cursor to be positioned on the same line, whose address has
        " changed. We can't rely on an address, so we need to mark the current
        " line. The mark will follow the moved line, not an address.
        "
        " And why do we use a named mark? Why not m'?
        " Probably because we could be using '' to go back and forth between
        " 2 positions, and we don't want this function to disrupt these jumps.
"}}}
        norm! mz

        " move the line
        sil exe 'move '.where

        " indent it
        if &ft !=# 'markdown'
            sil norm! ==
        endif

        sil! call repeat#set("\<plug>(mv_".a:what.')', cnt)
    catch
        return lg#catch_error()
    finally
        " Restoration and cleaning
        let &l:fen = fen_save
        " restore the view AFTER re-enabling folding,
        " because the latter may alter the view
        call winrestview(view)
        norm! `z

        " FIXME: The next line restores the position of the mark `z`. {{{
        " It works. But when we undo (u, :undo), `z` is put on the line which was
        " moved.
        " Watch:
        "         nno cd :call Func()<cr>
        "         fu! Func() abort
        "             let z_save = getpos("'z")
        "             norm! mz
        "             m -1-
        "             norm! `z
        "             call setpos("'z", z_save)
        "         endfu
        "
        "         put the mark `z` somewhere, hit `cd` somewhere else, undo,
        "         then hit `z (the `z` mark has moved; we don't want that)
        "
        " The issue comes from the fact that Vim saves the state of the buffer right
        " before a change. Here the change is caused by the `:move` command. So, Vim
        " saves the state of the buffer right before `:m`, and thus with the `z` mark
        " in the wrong and temporary position.
        "
        " Solution:
        " Try to break the undo sequence before setting the `z` mark, and use `:undojoin`
        " before `:m`:
        "
        "         nno cd :call Func()<cr>
        "         fu! Func() abort
        "             let z_save = getpos("'z")
        "             " isn't there a better way to break undo sequence?
        "             exe "norm! i\<c-g>u"
        "             norm! mz
        "             undoj | m -1-
        "             norm! `z
        "             call setpos("'z", z_save)
        "         endfu
        "
        " Doesn't work well. When we undo, some undesired edit is restored.
        " }}}
        call setpos("'z", z_save)
    endtry
endfu

fu! brackets#next_file_to_edit(cnt) abort "{{{1
    let here = expand('%:p')
    let cnt  = a:cnt

    " If we start Vim without any file argument, `here` is empty.
    " It doesn't cause any pb to move forward (`]f`), but it does if we try
    " to move backward (`[f`), because we end up stuck in a loop with:   here  =  .
    "
    " To fix this, we reset `here` by giving it the path to the working directory.
    if empty(here)
        let here = getcwd().'/'
    endif

    " The main code of this function is a double nested loop.
    " We use both to move in the tree:
    "
    "         • the outer loop    to climb up    the tree
    "         • the inner loop    to go down     the tree
    "
    " We also use the outer loop to determine when to stop:
    " once `cnt` reaches 0.
    " Indeed, at the end of each iteration, we get a previous/next file.
    " It needs to be done exactly `cnt` times (by default 1).
    " So, at the end of each iteration, we update `cnt`, by [in|de]crementing it.
    while cnt != 0
        let entries = s:what_is_around(fnamemodify(here, ':h'))

        " We use `a:cnt` instead of `cnt` in our test, because `cnt` is going
        " to be [in|de]cremented during the execution of the outer loop.
        if a:cnt > 0
            " remove the entries whose names come BEFORE the one of the current
            " entry, and sort the resulting list
            call sort(filter(entries,{ i,v -> v ># here }))
        else
            " remove the entries whose names come AFTER the one of the current
            " entry, sort the resulting list, and reverse the order
            " (so that the previous entry comes first instead of last)
            call reverse(sort(filter(entries, { i,v -> v <# here })))
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
            " until we find an entry which is a file. Thus a 2nd loop.
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

            " Now that `here` has been updated, we also need to update the
            " counter. For example, if we've hit `3]f`, we need to decrement
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

fu! s:what_is_around(dir) abort
    " If `dir` is the root of the tree, we need to get rid of the
    " slash, because we're going to add a slash when calling `glob('/*')`.
    let dir = substitute(a:dir, '/$', '', '')
    let entries  = glob(dir.'/.*', 0, 1)
    let entries += glob(dir.'/*', 0, 1)

    " The first call to `glob()` was meant to include the hidden entries,
    " but it produces 2 garbage entries which do not exist.
    " For example, if `a:dir` is `/tmp`, the 1st command will
    " produce, among other valid entries:
    "
    "         /tmp/.
    "         /tmp/..
    "
    " We need to get rid of them.
    call filter(entries, { i,v -> v !~# '/\.\.\?$' })

    return entries
endfu

fu! brackets#put(where, post_indent_cmd, lhs) abort "{{{1
    let cnt = v:count1
    " make sure the dot command will repeat the register we're using
    sil! call repeat#setreg(a:lhs, v:register)

    if v:register =~# '[/:%#.]'
        " The type of the register we put needs to be linewise.
        " But, some registers are special: we can't change their type.
        " So, we'll temporarily duplicate their contents into `z` instead.
        let reg_save  = [ getreg('z'), getregtype('z') ]
    else
        let reg_save  = [ getreg(v:register), getregtype(v:register) ]
    endif

    try
        if v:register =~# '[/:%#.]'
            let reg_to_use = 'z'
            call setreg('z', getreg(v:register), 'l')
        else
            let reg_to_use = v:register
        endif

        " force the type of the register to be linewise
        call setreg(reg_to_use, getreg(reg_to_use), 'l')

        " put the register (a:where can be ]p or [p)
        exe 'norm! "'.reg_to_use.cnt.a:where.a:post_indent_cmd

        " make the edit dot repeatable
        sil! call repeat#set(a:lhs, cnt)
    catch
        return lg#catch_error()
    finally
        " restore the type of the register
        call setreg(reg_to_use, reg_save[0], reg_save[1])
    endtry
endfu

fu! brackets#put_empty_line(below) abort "{{{1
    let cnt = v:count1

    call append(line('.')+(a:below ? 0 : -1), repeat([''], cnt))

    " We've just put (an) empty line(s) below/above the current one.
    " But if we were inside a diagram, there's a risk that now the latter
    " is filled with “holes“. We need to complete the diagram when needed.

    "                                                               ┌ diagram characters
    "                    ┌──────────────────────────────────────────┤
    if getline('.') =~# '[\u2502\u250c\u2510\u2514\u2518\u251c\u2524]'

        " If we're in a commented diagram, the lines we've just put are not commented.
        " They should be. So, we undo, then use  the `o` or `O` command, so that
        " Vim adds the comment leader for each line.
        let z_save = getpos("'z")
        sil undo
        norm! mz
        exe 'norm! '.cnt.(a:below ? 'o' : 'O')."\e".'g`z'
        call setpos("'z", z_save)

        " What is this lambda for?{{{
        "
        " This lambda will be invoked every  time there's a diagram character on
        " the line where we pressed our mapping.
        "
        " It will  be used to  check if  there's another diagram  character just
        " above/below.   This is  some  kind of  heuristics  to eliminate  false
        " positive.  We want  to expand a diagram only when  we're really inside
        " one.
        "}}}
        let l:Diagram_around = { dir, vcol ->
        \                        matchstr(getline(line('.')+dir*(cnt+1)), '\%'.vcol.'v.''\@!') =~# '[\u2502\u250c\u2510\u2514\u2518\u251c\u2524\u251c\u2524]' }
        "                                                                              └───┤
        "                             if a diagram character is followed by a single quote ┘
        "                             it's probably used  in some code (like  in this code
        "                             for example) ignore it
        let ve_save = &ve
        try
            set ve=all
            let vcol = 1
            for char in split(getline('.'), '\zs')
                if  char ==# "\u2502" && l:Diagram_around(a:below ? 1 : -1, vcol)
                \|| index(["\u250c", "\u2510", "\u251c", "\u2524"], char) >= 0 && a:below  && l:Diagram_around(1, vcol)
                \|| index(["\u2514", "\u2518", "\u251c", "\u2524"], char) >= 0 && !a:below && l:Diagram_around(-1, vcol)
                    norm! mz
                    "                                                                ┌ if a:below = 1 and cnt = 3:
                    "                                                                │     jr|jr|jr|
                    "                     ┌──────────────────────────────────────────┤
                    exe 'norm! '.vcol.'|'.repeat((a:below ? 'j' : 'k')."r\u2502", cnt).'g`z'
                endif
                let vcol += 1
            endfor

        catch
            return lg#catch_error()
        finally
            let &ve = ve_save
            call setpos("'z", z_save)
        endtry
    endif
    sil! call repeat#set("\<plug>(put_empty_line_".(a:below ? 'below' : 'above').')', cnt)
    " FIXME:{{{
    "         ] space
    "         dd
    "         .          ✘
    "
    " The issue doesn't affect `[ space`.
    " It affects `] space` in the original unimpaired plugin.
    " To fix this, we have to trigger `CursorMoved` manually, AFTER invoking
    " `repeat#set()`.
    "
    " Understand why this fix is needed.
    " Find whether it's needed somewhere else.
    " Document it.
    "}}}
    doautocmd <nomodeline> CursorMoved
endfu
