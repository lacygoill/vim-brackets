vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

import {
    Catch,
    GetSelectionText,
    IsVim9,
} from 'lg.vim'

# Interface {{{1
def brackets#diList( #{{{2
    cmd: string,
    search_cur_word: bool,
    start_at_cursor: bool,
    search_in_comments: bool,
    pattern = ''
)
    # Derive the commands used below from the first argument.
    var excmd: string = cmd .. 'list' .. (search_in_comments ? '!' : '')
    var normcmd: string = toupper(cmd)

    var pat: any
    var output: string
    var title: string
    # if we call the function from a normal mode mapping, the pattern is the
    # word under the cursor
    if search_cur_word
        # `silent!` because pressing `]I` on a unique word raises `E389`
        output = execute('norm! ' .. (start_at_cursor ? ']' : '[') .. normcmd, 'silent!')
        title = (start_at_cursor ? ']' : '[') .. normcmd

    # the function was called by a custom Ex command
    else
        if pattern != ''
            pat = pattern
        elseif pattern == ''
            # otherwise the function must have been called from visual mode
            # (visual mapping): use the visual selection as the pattern
            pat = GetSelectionText()

            # `:ilist` can't find a multiline pattern
            if len(pat) != 1
                Error('E389: Couldn''t find pattern')
                return
            endif
            pat = pat[0]

            # make sure the pattern is interpreted literally
            pat = '\V' .. escape(pat, '\/')
        endif

        output = execute(
            (start_at_cursor ? '+,$' : '') .. excmd .. ' /' .. pat,
            'silent!')
        title = excmd .. ' /' .. pat
    endif

    var lines: list<string> = split(output, '\n')
    # bail out on errors
    if get(lines, 0, '') =~ '^Error detected\|^$'
        var msg: string = 'Could not find '
            .. string(search_cur_word ? expand('<cword>') : pat)
        Error(msg)
        return
    endif

    # Our results may span multiple files so we need to build a relatively
    # complex list based on filenames.
    var filename: string = ''
    var ll_entries: list<dict<any>>
    for line in lines
        # A line in the output of `:ilist` and `dlist` can be a filename.
        # It happens when there are matches in other included files.
        # It's how `:ilist` / `:dlist`tells us in which files are the
        # following entries.
        #
        # When we find such a line, we don't parse its text to add an entry
        # in the ll, as we would do for any other line.
        # We use it to update the variable `filename`, which in turn is used
        # to generate valid entries in the ll.
        if line !~ '^\s*\d\+:'
            filename = line->fnamemodify(':p:.')
            #                              │ │{{{
            #                              │ └ relative to current working directory
            #                              └ full path
        #}}}
        else
            var lnum: number = split(line)[1]->str2nr()

            # remove noise from the text output:
            #
            #    1:   48   line containing pattern
            # ^__________^
            #     noise

            var text: string = line->substitute('^\s*\d\{-}\s*:\s*\d\{-}\s', '', '')

            var col: number = match(text,
                search_cur_word ? '\C\<' .. expand('<cword>') .. '\>' : pat
                ) + 1
            ll_entries->add({
                filename: filename,
                lnum: lnum,
                col: col,
                text: text,
            })
        endif
    endfor

    setloclist(0, [], ' ', {items: ll_entries, title: title})

    # Populating the location list doesn't fire any event.
    # Fire `QuickFixCmdPost`, with the right pattern (*), to open the ll window.
    #
    # (*) `lvimgrep`  is a  valid pattern (`:h  QuickFixCmdPre`), and  it begins
    # with a `l`.   The autocmd that we  use to automatically open  a qf window,
    # relies on  the name  of the  command (how its  name begins),  to determine
    # whether it must open the ll or qfl window.
    do <nomodeline> QuickFixCmdPost lwindow
    if &buftype != 'quickfix'
        return
    endif

    # hide location
    qf#setMatches('brackets:di_list', 'Conceal', 'location')
    qf#createMatches()
enddef

def brackets#mvLineSetup(dir: string): string #{{{2
    mv_line_dir = dir
    &operatorfunc = expand('<SID>') .. 'MvLine'
    return 'g@l'
enddef
var mv_line_dir: string

def brackets#nextFileToEdit(arg_cnt: number): string #{{{2
    var here: string = expand('%:p')
    var cnt: number = arg_cnt

    # If we start Vim without any file argument, `here` is empty.
    # It doesn't cause any pb to move forward (`]f`), but it does if we try
    # to move backward (`[f`), because we end up stuck in a loop with:   here  =  .
    #
    # To fix this, we reset `here` by giving it the path to the working directory.
    if empty(here)
        here = getcwd() .. '/'
    endif

    # The main code of this function is a double nested loop.
    # We use both to move in the tree:
    #
    #    - the outer loop    to climb up    the tree
    #    - the inner loop    to go down     the tree
    #
    # We also use the outer loop to determine when to stop:
    # once `cnt` reaches 0.
    # Indeed, at the end of each iteration, we get a previous/next file.
    # It needs to be done exactly `cnt` times (by default 1).
    # So, at the end of each iteration, we update `cnt`, by [in|de]crementing it.
    while cnt != 0
        var entries: list<string> = here->fnamemodify(':h')->WhatIsAround()

        # We use `arg_cnt` instead of `cnt` in our test, because `cnt` is going
        # to be [in|de]cremented during the execution of the outer loop.
        if arg_cnt > 0
            # remove the entries whose names come BEFORE the one of the current
            # entry, and sort the resulting list
            entries
                ->filter((_, v: string): bool => v > here)
                ->sort()
        else
            # remove the entries whose names come AFTER the one of the current
            # entry, sort the resulting list, and reverse the order
            # (so that the previous entry comes first instead of last)
            entries
                ->filter((_, v: string): bool => v < here)
                ->sort()
                ->reverse()
        endif
        var next_entry: string = get(entries, 0, '')

        # If inside the current directory, there's no other entry before/after
        # the current one (depends in which direction we're looking)
        # then we update `here`, by replacing it with its parent directory.
        # We don't update `cnt` (because we haven't found a valid file), and get
        # right back to the beginning of the main loop.
        # If we end up in an empty directory, deep inside the tree, this will
        # allow us to climb up as far as needed.
        if empty(next_entry)
            here = here->fnamemodify(':h')

        else
            # If there IS another entry before/after the current one, store it
            # inside `here`, to correctly set up the next iteration of the main loop.
            here = next_entry

            # We're only interested in a file, not a directory.
            # And if it's a directory, we don't know how far is the next file.
            # It could be right inside, or inside a sub-sub-directory ...
            # So, we need to check whether what we found is a directory, and go on
            # until we find an entry which is a file.  Thus a 2nd loop.
            #
            # Each time we find an entry which is a directory, we look at its
            # contents.
            # If at some point, we end up in an empty directory, we simply break
            # the inner loop, and get right back at the beginning of the outer
            # loop.
            # The latter will make us climb up as far as needed to find a new
            # file entry.
            #
            # OTOH, if there's something inside a directory entry, we update
            # `here`, by storing the first/last entry of its contents.
            var found_a_file: bool = true

            while isdirectory(here)
                entries = WhatIsAround(here)
                if empty(entries)
                    found_a_file = false
                    break
                endif
                here = entries[cnt > 0 ? 0 : -1]
            endwhile

            # Now  that `here`  has been  updated, we  also need  to update  the
            # counter.  For  example, if we've  hit `3]f`, we need  to decrement
            # `cnt` by one.
            # But, we only update it if we didn't ended up in an empty directory
            # during the inner loop.
            # Because in this case, the value of `here` is this empty directory.
            # And that's not a valid entry for us, we're only interested in
            # files.
            if found_a_file
                cnt += cnt > 0 ? -1 : 1
            endif
        endif
    endwhile
    return here
enddef

def WhatIsAround(arg_dir: string): list<string>
    return readdir(arg_dir)
        ->map((_, v: string): string => arg_dir .. '/' .. v)
enddef

def brackets#putSetup(where: string, how_to_indent: string): string #{{{2
    put_info = {
        where: where,
        how_to_indent: how_to_indent,
        register: v:register,
    }
    &operatorfunc = expand('<SID>') .. 'Put'
    return 'g@l'
enddef
var put_info: dict<string>

def brackets#putLineSetup(dir: string): string #{{{2
    put_line_below = dir == ']'
    &operatorfunc = expand('<SID>') .. 'PutLine'
    return 'g@l'
enddef
var put_line_below: bool

def brackets#putLinesAround(type = ''): string #{{{2
    if type == ''
        &operatorfunc = 'brackets#putLinesAround'
        return 'g@l'
    endif
    # above
    put_line_below = false
    PutLine('')

    # below
    put_line_below = true
    PutLine('')

    return ''
enddef

def brackets#ruleMotion(below = true) #{{{2
    var cnt: number = v:count1
    var cml: string = IsVim9()
        ? '#'
        : '\V' .. &l:commentstring->matchstr('\S*\ze\s*%s')->escape('\') .. '\m'
    var flags: string = (below ? '' : 'b') .. 'W'
    var pat: string
    var stopline: number
    for i in range(1, cnt)
        if &filetype == 'markdown'
            pat = '^---$'
            stopline = search('^#', flags .. 'n')
        else
            pat = '^\s*' .. cml .. ' ---$'
            var foldmarker: string = '\%(' .. split(&l:foldmarker, ',')->join('\|') .. '\)\d*'
            stopline = search('^\s*' .. cml .. '.*' .. foldmarker .. '$', flags .. 'n')
        endif
        var lnum: number = search(pat, flags .. 'n')
        if stopline == 0 || (below && lnum < stopline || !below && lnum > stopline)
            search(pat, flags, stopline)
        endif
    endfor
enddef

def brackets#rulePut(below = true) #{{{2
    append('.', ["\x01", '---', "\x01", "\x01"])
    if &filetype != 'markdown'
        :+,+4CommentToggle
    endif
    sil keepj keepp :+,+4s/\s*\%x01$//e
    if &filetype != 'markdown'
        exe 'sil norm! V3k=3jA '
    endif
    if !below
        :-4m .
        exe 'norm! ' .. (&filetype == 'markdown' ? '' : '==') .. 'k'
    endif
    startinsert!
enddef
#}}}1
# Core {{{1
def MvLine(_) #{{{2
    var cnt: number = v:count1

    # disabling the folds may alter the view, so save it first
    var view: dict<number> = winsaveview()

    # Why do you disable folding?{{{
    #
    # We're going to do 2 things:
    #
    #    1. move a / several line(s)
    #    2. update its / their indentation
    #
    # If we're inside a fold, the `:move` command will close it.
    # Why?
    # Because of patch  `7.4.700`.  It solves one problem related  to folds, and
    # creates a new one:
    # https://github.com/vim/vim/commit/d5f6933d5c57ea6f79bbdeab6c426cf66a393f33
    #
    # Then, it gets worse: because the fold is now closed, the indentation
    # command will indent the whole fold, instead of the line(s) on which we
    # were operating.
    #
    # MWE:
    #
    #     $ echo "fold\nfoo\nbar\nbaz\n" >/tmp/file && vim -Nu NONE /tmp/file
    #     :set foldmethod=marker
    #     VGzf
    #     zv
    #     j
    #     :m + | norm! ==
    #     5 lines indented ✘ it should be just one˜
    #
    # Maybe we could use  `norm! zv` to open the folds, but  it would be tedious
    # and error-prone in the future.  Every time  we would add a new command, we
    # would have  to remember  to use  `norm! zv`.   It's better  to temporarily
    # disable folding entirely.
    #
    # Remember:
    # Because of a quirk of Vim's implementation, always temporarily disable
    # 'foldenable' before moving lines which could be in a fold.
    #}}}
    var foldenable_save: bool = &l:foldenable
    var winid: number = win_getid()
    var bufnr: number = bufnr('%')
    &l:foldenable = false
    # TODO: Save and restore all possible text properties on a moved line.
    # Use `prop_list()` to get the list.
    try
        # Why do we mark the line since we already saved the view?{{{
        #
        # Because,  after  the restoration  of  the  view,  the cursor  will  be
        # positioned on the old address of the line we moved.
        # We don't want that.
        # We want  the cursor to be  positioned on the same  line, whose address
        # has changed.   We can't  rely on an  address, so we  need to  mark the
        # current line.  The mark will follow the moved line, not an address.
        #}}}
        # Vim doesn't provide the concept of extended mark; use a dummy text property instead
        prop_type_add('tempmark', {bufnr: bufnr('%')})
        prop_add(line('.'), col('.'), {type: 'tempmark'})

        # move the line
        if mv_line_dir == '['
            # Why this convoluted `:move` just to move a line?  Why don't you simply move the line itself?{{{
            #
            # To preserve the text property.
            #
            # To move a line, internally, Vim  first copies it at some other
            # location, then removes the original.
            # The copy  does not inherit the  text property, so in  the end,
            # the latter  is lost.   But we  need it  to restore  the cursor
            # position.
            #
            # As a workaround, we don't move the line itself, but its direct
            # neighbor.
            #}}}
            exe ':-' .. cnt .. ',-m . | :-' .. cnt
        else
            # `sil!` suppresses `E16` when reaching the end of the buffer
            exe 'sil! :+,+1+' .. (cnt - 1) .. 'm - | :+'
        endif

        # indent the line
        if &filetype != 'markdown' && &filetype != ''
            sil norm! ==
        endif
    catch
        Catch()
        return
    finally
        # restoration and cleaning
        if winbufnr(winid) == bufnr
            var tabnr: number
            var winnr: number
            [tabnr, winnr] = win_id2tabwin(winid)
            settabwinvar(tabnr, winnr, '&foldenable', foldenable_save)
        endif
        # restore the view *after* re-enabling folding, because the latter may alter the view
        winrestview(view)
        # restore cursor position
        # use the text property to restore the cursor position
        var info: list<dict<any>> = [
            prop_find({type: 'tempmark'}, 'f'),
            prop_find({type: 'tempmark'}, 'b')
        ]->filter((_, v: dict<any>): bool => !empty(v))

        if !empty(info)
            cursor(info[0]['lnum'], info[0]['col'])
        endif

        # remove the text property
        prop_remove({type: 'tempmark', all: true})
        prop_type_delete('tempmark', {bufnr: bufnr('%')})
    endtry
enddef

def Put(_) #{{{2
    var cnt: number = v:count1

    # If the register is empty, an error should be raised.{{{
    #
    # And we want the exact message we would  have, if we were to try to put the
    # register without our mapping.
    #
    # That's the whole purpose of the next `:norm`:
    #
    #     Vim(normal):E353: Nothing in register "˜
    #     Vim(normal):E32: No file name˜
    #     Vim(normal):E30: No previous command line˜
    #     ...˜
    #}}}
    if getreg(put_info.register, true, true) == []
        try
            exe 'norm! "' .. put_info.register .. 'p'
        catch
            Catch()
            return
        endtry
    endif

    var reg_save: dict<any> = getreginfo('z')
    if put_info.register =~ '[/:%#.]'
        # The type of the register we put needs to be linewise.
        # But some registers are special: we can't change their type.
        # So, we'll temporarily duplicate their contents into `z` instead.
        reg_save = getreginfo('z')
    else
        reg_save = getreginfo(put_info.register)
    endif

    var reg_to_use: string
    # Warning: about folding interference{{{
    #
    # If one of  the lines you paste  is recognized as the beginning  of a fold,
    # and you  paste using  `<p` or  `>p`, the  folding mechanism  may interfere
    # unexpectedly, causing too many lines to be indented.
    #
    # You could prevent that by temporarily disabling 'foldenable'.
    # But doing so will sometimes make the view change.
    # So, you would also need to save/restore the view.
    # But doing so  will position the cursor right back  where you were, instead
    # of the first line of the pasted text.
    #
    # All in all, trying to fix this rare issue seems to cause too much trouble.
    # So, we don't.
    #}}}
    try
        if put_info.register =~ '[/:%#.]'
            reg_to_use = 'z'
            getreginfo(put_info.register)->extend({regtype: 'l'})->setreg('z')
        else
            reg_to_use = put_info.register
        endif

        # If  we've just  sourced some  line of  code in  a markdown  file, with
        # `+s{text-object}`, the register `o` contains its output.
        # We want it to be highlighted as a code output, so we append `~` at the
        # end of every non-empty line.
        if reg_to_use == 'o'
            && &filetype == 'markdown'
            && synID('.', col('.'), true)->synIDattr('name') =~ '^markdown.*CodeBlock$'
            getreg('o', true, true)
                ->map((_, v: string): string => v != '' ? v .. '~' : v)
                ->setreg('o', 'l')
        endif

        # force the type of the register to be linewise
        getreginfo(reg_to_use)->extend({regtype: 'l'})->setreg(reg_to_use)

        # put the register (`put_info.where` can be `]p` or `[p`)
        exe 'norm! "' .. reg_to_use .. cnt .. put_info.where .. put_info.how_to_indent

        # make sure the cursor is on the first non-whitespace
        search('\S', 'cW')
    catch
        Catch()
        return
    finally
        setreg(reg_to_use, reg_save)
    endtry
enddef

def PutLine(_) #{{{2
    var cnt: number = v:count1
    var line: string = getline('.')
    var cml: string = IsVim9()
        ? '#'
        : '\V' .. &l:commentstring->matchstr('\S*\ze\s*%s')->escape('\') .. '\m'

    var is_first_line_in_diagram: bool = line =~ '^\s*\%(' .. cml .. '\)\=├[─┐┘ ├]*$'
    var is_in_diagram: bool = line =~ '^\s*\%(' .. cml .. '\)\=\s*[│┌┐└┘├┤]'
    if is_first_line_in_diagram
        if put_line_below && line =~ '┐' || !put_line_below && line =~ '┘'
            line = ''
        else
            line = line
                    ->substitute('[^├]', ' ', 'g')
                    ->substitute('├', '│', 'g')
        endif
    elseif is_in_diagram
        line = line->substitute('\%([│┌┐└┘├┤].*\)\@<=[^│┌┐└┘├┤]', ' ', 'g')
        var Rep: func = (m: list<string>): string =>
               m[0] == '└' && put_line_below
            || m[0] == '┌' && !put_line_below
            ? '' : '│'
        line = line->substitute('[└┌]', Rep, 'g')
    else
        line = ''
    endif
    line = line->substitute('\s*$', '', '')
    var lines: list<string> = repeat([line], cnt)

    var lnum: number = line('.') + (put_line_below ? 0 : -1)
    # if we're in a closed fold, we don't want to simply add an empty line,
    # we want to create a visual separation between folds
    var fold_begin: number = foldclosed('.')
    var fold_end: number = foldclosedend('.')
    var is_in_closed_fold: bool = fold_begin >= 0

    if is_in_closed_fold && &filetype == 'markdown'
        # for  a  markdown  buffer,  where  we  use  a  foldexpr,  a  visual
        # separation means an empty fold
        var prefix: string = getline(fold_begin)->matchstr('^#\+')
        # fold marked by a line starting with `#`
        if prefix =~ '#'
            if prefix == '#'
                prefix = '##'
            endif
            lines = repeat([prefix], cnt)
        # fold marked by a line starting with `===` or `---`
        elseif getline(fold_begin + 1)->match('^===\|^---') != -1
            lines = repeat(['---', '---'], cnt)
        endif
        lnum = put_line_below ? fold_end : fold_begin - 1
    endif

    # could fail if the buffer is unmodifiable
    try
        append(lnum, lines)
        # Why?{{{
        #
        # By default, we  set the foldmethod to `manual`, because  `expr` can be
        # much more expensive.
        # As a  consequence, when you  insert a  new fold, it's  not immediately
        # detected as such; not until you've temporarily switched to `expr`.
        # That's what `#compute()` does.
        #}}}
        if &filetype == 'markdown' && lines[0] =~ '^[#=-]'
            sil! fold#lazy#compute()
        endif
    catch
        Catch()
        return
    endtry
enddef
#}}}1
# Util {{{1
def Error(msg: string) #{{{2
    echohl ErrorMsg
    echom msg
    echohl NONE
enddef
