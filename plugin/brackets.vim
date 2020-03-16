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
"}}}1
" Mappings {{{1
" Move in lists {{{2
" arglist {{{3

nno <silent><unique> [a :<c-u>call brackets#move#next('[a')<cr>
nno <silent><unique> ]a :<c-u>call brackets#move#next(']a')<cr>

nno <silent><unique> [A :<c-u>first<cr>
nno <silent><unique> ]A :<c-u>last<cr>

" buffer list {{{3

" `:bnext` wrap around the end of the buffer list by default
nno <silent><unique> [b :<c-u>exe v:count..'bprevious'<cr>
nno <silent><unique> ]b :<c-u>exe v:count..'bnext'<cr>

nno <silent><unique> [B :<c-u>bfirst<cr>
nno <silent><unique> ]B :<c-u>blast<cr>

" file list {{{3

nno <silent><unique> ]f :<c-u>e <c-r>=fnameescape(brackets#next_file_to_edit(v:count1))<cr><cr>
nno <silent><unique> [f :<c-u>e <c-r>=fnameescape(brackets#next_file_to_edit(-v:count1))<cr><cr>

" quickfix list {{{3

nno <silent><unique> [q :<c-u>call brackets#move#cnext('[q')<cr>
nno <silent><unique> ]q :<c-u>call brackets#move#cnext(']q')<cr>

nno <silent><unique> [l :<c-u>call brackets#move#cnext('[l')<cr>
nno <silent><unique> ]l :<c-u>call brackets#move#cnext(']l')<cr>

nno <silent><unique> [Q :<c-u>cfirst<cr>
nno <silent><unique> ]Q :<c-u>clast<cr>

nno <silent><unique> [L :<c-u>lfirst<cr>
nno <silent><unique> ]L :<c-u>llast<cr>

nno <silent><unique> [<c-q> :<c-u>call brackets#move#cnext('[ c-q')<cr>
nno <silent><unique> ]<c-q> :<c-u>call brackets#move#cnext('] c-q')<cr>

nno <silent><unique> [<c-l> :<c-u>call brackets#move#cnext('[ c-l')<cr>
nno <silent><unique> ]<c-l> :<c-u>call brackets#move#cnext('] c-l')<cr>

" quickfix stack {{{3

nno <silent><unique> <q :<c-u>call brackets#move#cnewer('<q')<cr>
nno <silent><unique> >q :<c-u>call brackets#move#cnewer('>q')<cr>

nno <silent><unique> <l :<c-u>call brackets#move#cnewer('<l')<cr>
nno <silent><unique> >l :<c-u>call brackets#move#cnewer('>l')<cr>

" tag list {{{3

nno <silent><unique> [t :<c-u>call brackets#move#tnext('[t')<cr>
nno <silent><unique> ]t :<c-u>call brackets#move#tnext(']t')<cr>

nno <silent><unique> [T :<c-u>tfirst<cr>
nno <silent><unique> ]T :<c-u>tlast<cr>
"}}}2
" Move to text matching regex {{{2

noremap <expr><silent><unique> [` brackets#move#regex('codespan', 0)
noremap <expr><silent><unique> ]` brackets#move#regex('codespan', 1)
noremap <expr><silent><unique> [h brackets#move#regex('path', 0)
noremap <expr><silent><unique> ]h brackets#move#regex('path', 1)
noremap <expr><silent><unique> [r brackets#move#regex('ref', 0)
noremap <expr><silent><unique> ]r brackets#move#regex('ref', 1)
noremap <expr><silent><unique> [u brackets#move#regex('url', 0)
noremap <expr><silent><unique> ]u brackets#move#regex('url', 1)
noremap <expr><silent><unique> [U brackets#move#regex('concealed_url', 0)
noremap <expr><silent><unique> ]U brackets#move#regex('concealed_url', 1)

" Miscellaneous {{{2
" ] SPC {{{3

nno <silent><unique> =<space> :<c-u>set opfunc=brackets#put_lines_around<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> [<space> :<c-u>call brackets#put_line_save_param(0)<bar>set opfunc=brackets#put_line<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> ]<space> :<c-u>call brackets#put_line_save_param(1)<bar>set opfunc=brackets#put_line<bar>exe 'norm! '..v:count1..'g@l'<cr>

" ] - {{{3

nno <silent><unique> [- :<c-u>call brackets#rule_motion(0)<cr>
nno <silent><unique> ]- :<c-u>call brackets#rule_motion(1)<cr>

xno <silent><unique> [- :<c-u>call brackets#rule_motion(0, 'vis')<cr>
xno <silent><unique> ]- :<c-u>call brackets#rule_motion(1, 'vis')<cr>

ono <silent><unique> [- :<c-u>norm V[-<cr>
ono <silent><unique> ]- :<c-u>norm V]-<cr>

nno <silent><unique> +[- :<c-u>call brackets#rule_put(0)<cr>
nno <silent><unique> +]- :<c-u>call brackets#rule_put(1)<cr>

" ]I {{{3

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

" ]e {{{3

nno <silent><unique> [e :<c-u>call brackets#mv_line_save_dir('up')<bar>set opfunc=brackets#mv_line<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> ]e :<c-u>call brackets#mv_line_save_dir('down')<bar>set opfunc=brackets#mv_line<bar>exe 'norm! '..v:count1..'g@l'<cr>

" ]p {{{3

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
nno <silent><unique> >P :<c-u>call brackets#put_save_param('[p', ">']")<bar>set opfunc=brackets#put<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> >p :<c-u>call brackets#put_save_param(']p', ">']")<bar>set opfunc=brackets#put<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> <P :<c-u>call brackets#put_save_param('[p', "<']")<bar>set opfunc=brackets#put<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> <p :<c-u>call brackets#put_save_param(']p', "<']")<bar>set opfunc=brackets#put<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> =P :<c-u>call brackets#put_save_param('[p', "=']")<bar>set opfunc=brackets#put<bar>exe 'norm! '..v:count1..'g@l'<cr>
nno <silent><unique> =p :<c-u>call brackets#put_save_param(']p', "=']")<bar>set opfunc=brackets#put<bar>exe 'norm! '..v:count1..'g@l'<cr>

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

" ]s  ]S {{{3

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

