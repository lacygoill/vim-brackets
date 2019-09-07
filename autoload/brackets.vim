fu! brackets#di_list(cmd, search_cur_word, start_at_cursor, search_in_comments, ...) abort "{{{1
    " Derive the commands used below from the first argument.
    let excmd   = a:cmd.'list'.(a:search_in_comments ? '!' : '')
    let normcmd = toupper(a:cmd)

    " if we call the function from a normal mode mapping, the pattern is the
    " word under the cursor
    if a:search_cur_word
        let output = execute('norm! '.(a:start_at_cursor ? ']' : '[').normcmd, 'silent!')
        let title  = (a:start_at_cursor ? ']' : '[').normcmd

    else
        " otherwise if the function was called with a fifth optional argument,
        " by one of our custom Ex command, use it as the pattern
        if a:0 > 0
            let pat = a:1
        else
            " otherwise the function must have been called from visual mode
            " (visual mapping): use the visual selection as the pattern
            let cb_save  = &cb
            let sel_save = &sel
            let reg_save = ['"', getreg('"'), getregtype('"')]
            try
                set cb-=unnamed cb-=unnamedplus
                set sel=inclusive
                norm! gvy
                let pat = substitute('\V'.escape(getreg('"'), '\/'), '\\n', '\\n', 'g')
                "                     │                               │{{{
                "                     │                               └ make sure newlines are not
                "                     │                                 converted into NULs
                "                     │                                 on the search command-line
                "                     │
                "                     └ make sure the contents of the pattern is interpreted literally
                "}}}
            finally
                let &cb  = cb_save
                let &sel = sel_save
                call call('setreg', reg_save)
            endtry
        endif

        let output = execute((a:start_at_cursor ? '+,$' : '').excmd.' /'.pat, 'silent!')
        let title  = excmd.' /'.pat
    endif

    let lines = split(output, '\n')
    " Bail out on errors. (bail out = se désister)
    if get(lines, 0, '') =~ '^Error detected\|^$'
        echom 'Could not find '.string(a:search_cur_word ? expand('<cword>') : pat)
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

            let col  = match(text, a:search_cur_word ? '\C\<'.expand('<cword>').'\>' : pat) + 1
            call add(ll_entries,
            \ { 'filename' : filename,
            \   'lnum'     : lnum,
            \   'col'      : col,
            \   'text'     : text,
            \ })
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
    do <nomodeline> QuickFixCmdPost lwindow
    if &bt isnot# 'quickfix'
        return
    endif

    " hide location
    call qf#set_matches('brackets:di_list', 'Conceal', 'location')
    call qf#create_matches()
endfu

fu! brackets#mv_line(type) abort "{{{1
    let cnt = v:count1

    let where = s:mv_line_dir is# 'up'
            \ ?     '-1-'
            \ :     '+'

    let where .= cnt

    " I'm not sure, but disabling the folds may alter the view, so save it first
    let view = winsaveview()

    let z_save = getpos("'z")

    " Why do we disable folding?{{{
    " We're going to do 2 things:
    "
    "    1. move a / several line(s)
    "    2. update its / their indentation
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
    " MWE:
    "         echo "fold\nfoo\nbar\nbaz\n" >file
    "         vim -Nu NONE file
    "         :set fdm=marker
    "         VGzf
    "         zv
    "         j
    "         :m + | norm! ==
    "         5 lines indented ✘ it should be just one~
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
        if &ft isnot# 'markdown'
            sil norm! ==
        endif
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
        " MWE:
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

fu! brackets#mv_line_save_dir(dir) abort
    let s:mv_line_dir = a:dir
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
    "    - the outer loop    to climb up    the tree
    "    - the inner loop    to go down     the tree
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
            call sort(filter(entries,{_,v -> v ># here}))
        else
            " remove the entries whose names come AFTER the one of the current
            " entry, sort the resulting list, and reverse the order
            " (so that the previous entry comes first instead of last)
            call reverse(sort(filter(entries, {_,v -> v <# here})))
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
    call filter(entries, {_,v -> v !~# '/\.\.\?$'})

    return entries
endfu

fu! brackets#put(type) abort "{{{1
    let cnt = v:count1

    if s:put_register =~# '[/:%#.]'
        " The type of the register we put needs to be linewise.
        " But, some registers are special: we can't change their type.
        " So, we'll temporarily duplicate their contents into `z` instead.
        let reg_save  = [getreg('z'), getregtype('z')]
    else
        let reg_save  = [getreg(s:put_register), getregtype(s:put_register)]
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
        if s:put_register =~# '[/:%#.]'
            let reg_to_use = 'z'
            call setreg('z', getreg(s:put_register), 'l')
        else
            let reg_to_use = s:put_register
        endif
        let reg_save = [reg_to_use] + reg_save

        " If  we've just  sourced some  line of  code in  a markdown  file, with
        " `+s{text-object}`, the register `o` contains its output.
        " We want it to be highlighted as a code output, so we append `~` at the
        " end of every non-empty line.
        if reg_to_use is# 'o'
            \ && &ft is# 'markdown'
            \ && synIDattr(synID(line('.'), col('.'), 0), 'name') =~# '^markdown.*CodeBlock$'
            let @o = join(map(split(@o, '\n'), {_,v -> v !~ '^$' ? v.'~' : v}), "\n")
        endif

        " force the type of the register to be linewise
        call setreg(reg_to_use, getreg(reg_to_use), 'l')

        " put the register (`s:put_where` can be `]p` or `[p`)
        exe 'norm! "'.reg_to_use . cnt . s:put_where . s:put_how_to_indent
    catch
        return lg#catch_error()
    finally
        " restore the type of the register
        call call('setreg', reg_save)
    endtry
endfu

fu! brackets#put_save_param(where, how_to_indent) abort "{{{1
    let s:put_where = a:where
    let s:put_how_to_indent = a:how_to_indent
    let s:put_register = v:register
endfu

fu! brackets#put_empty_line(_) abort "{{{1
    let cnt = v:count1

    let is_diagram_around = 1
    if getline(line('.')+(s:put_empty_line_below ? 1 : -1)) !~# '[│┌┐└┘├┤]'
        let is_diagram_around = 0
    endif

    " could fail if the buffer is unmodifiable
    try
        let lines = repeat([''], cnt)
        let lnum  = line('.') + (s:put_empty_line_below ? 0 : -1)

        " if we're in a closed fold, we don't want to simply add an empty line,
        " we want to create a visual separation between folds
        let fold_begin = foldclosed('.')
        let fold_end = foldclosedend('.')
        if fold_begin !=# -1 && &ft is# 'markdown'
            " for  a  markdown  buffer,  where  we  use  a  foldexpr,  a  visual
            " separation means an empty fold
            let prefix = matchstr(getline(fold_begin), '^#\+')
            if prefix =~# '#'
                if prefix is# '#'
                    let prefix = '##'
                endif
                let lines = repeat([prefix], cnt)
            elseif matchstr(getline(fold_begin+1), '^===\|^---') isnot# ''
                let lines = repeat(['---', '---'], cnt)
            endif
            let lnum = s:put_empty_line_below
                \ ? fold_end
                \ : fold_begin - 1
        endif

        call append(lnum, lines)
    catch
        return lg#catch_error()
    endtry

    " We've just put (an) empty line(s) below/above the current one.
    " But if we were inside a diagram, there's a risk that now the latter
    " is filled with “holes“. We need to complete the diagram when needed.

    if getline('.') =~# '[│┌┐└┘├┤]' && is_diagram_around
        " If we're in a commented diagram, the lines we've just put are not commented.
        " They should be. So, we undo, then use  the `o` or `O` command, so that
        " Vim adds the comment leader for each line.
        let z_save = getpos("'z")
        sil undo
        norm! mz
        exe 'norm! '.cnt.(s:put_empty_line_below ? 'o' : 'O')."\e".'g`z'
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
        let l:Is_diagram_around = { dir, vcol ->
            \ matchstr(getline(line('.')+dir*(cnt+1)), '\%'.vcol.'v.''\@!') =~# '[│┌┐└┘├┤├┤]' }
        "                                                           └───┤
        "          if a diagram character is followed by a single quote ┘
        "          it's probably used  in some code (like  in this code
        "          for example) ignore it
        let vcol = 1
        let vcols = []
        for char in split(getline('.'), '\zs')
            if   char is# '│' && l:Is_diagram_around(s:put_empty_line_below ? 1 : -1, vcol)
            \ || index(['┌', '┐', '├', '┤'], char) >= 0 && s:put_empty_line_below  && l:Is_diagram_around(1, vcol)
            \ || index(['└', '┘', '├', '┤'], char) >= 0 && !s:put_empty_line_below && l:Is_diagram_around(-1, vcol)
                let vcols += [vcol]
            endif
            let vcol += 1
        endfor

        let line = getline(line('.')+(s:put_empty_line_below ? 1 : -1)).repeat(' ', &columns)
        let pat = join(map(vcols, {_,v -> '\%'.v.'v.'}), '\|')
        let line = substitute(substitute(line, pat, '│', 'g'), '\s*$', '', '')

        let text = repeat([line], cnt)
        let lnum = line('.') + (s:put_empty_line_below ? 1 : -cnt)
        call setline(lnum, text)
    endif
endfu

fu! brackets#put_empty_line_save_dir(below) abort "{{{1
    let s:put_empty_line_below = a:below
endfu

fu! brackets#put_empty_lines_around(_) abort "{{{1
    " above
    call brackets#put_empty_line_save_dir(0)
    call brackets#put_empty_line('')

    " below
    call brackets#put_empty_line_save_dir(1)
    call brackets#put_empty_line('')
endfu

