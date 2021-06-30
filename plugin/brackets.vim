vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Commands {{{1
# Ilist {{{2

#                                             ┌ command{{{
#                                             │
#                                             │   ┌ pattern is NOT word under cursor
#                                             │   │
#                                             │   │      ┌ do NOT start searching after current line
#                                             │   │      │  start from beginning of file
#                                             │   │      │
#                                             │   │      │      ┌ search in comments only if a bang is added
#                                             │   │      │      │
#                                             │   │      │      │        ┌ pattern
#                                             │   │      │      │        │}}}
command -bang -nargs=1 Ilist brackets#diList('i', false, false, <bang>0, <q-args>)
command -bang -nargs=1 Dlist brackets#diList('d', false, false, <bang>0, <q-args>)
#}}}1
# Mappings {{{1
# Move in lists {{{2
# arglist {{{3

nnoremap <unique> [a <Cmd>call brackets#move#next('[a')<CR>
nnoremap <unique> ]a <Cmd>call brackets#move#next(']a')<CR>

nnoremap <unique> [A <Cmd>first<CR>
nnoremap <unique> ]A <Cmd>last<CR>

# buffer list {{{3

# `:bnext` wrap around the end of the buffer list by default
nnoremap <unique> [b <Cmd>execute v:count .. 'bprevious'<CR>
nnoremap <unique> ]b <Cmd>execute v:count .. 'bnext'<CR>

nnoremap <unique> [B <Cmd>bfirst<CR>
nnoremap <unique> ]B <Cmd>blast<CR>

# file list {{{3

nnoremap <unique> ]f <Cmd>execute 'edit ' .. brackets#nextFileToEdit(v:count1)->fnameescape()<CR>
nnoremap <unique> [f <Cmd>execute 'edit ' .. brackets#nextFileToEdit(-v:count1)->fnameescape()<CR>

# quickfix list {{{3

nnoremap <unique> [q <Cmd>call brackets#move#cnext('[q')<CR>
nnoremap <unique> ]q <Cmd>call brackets#move#cnext(']q')<CR>

nnoremap <unique> [l <Cmd>call brackets#move#cnext('[l')<CR>
nnoremap <unique> ]l <Cmd>call brackets#move#cnext(']l')<CR>

nnoremap <unique> [Q <Cmd>cfirst<CR>
nnoremap <unique> ]Q <Cmd>clast<CR>

nnoremap <unique> [L <Cmd>lfirst<CR>
nnoremap <unique> ]L <Cmd>llast<CR>

nnoremap <unique> [<C-Q> <Cmd>call brackets#move#cnext('[ C-q')<CR>
nnoremap <unique> ]<C-Q> <Cmd>call brackets#move#cnext('] C-q')<CR>

nnoremap <unique> [<C-L> <Cmd>call brackets#move#cnext('[ C-l')<CR>
nnoremap <unique> ]<C-L> <Cmd>call brackets#move#cnext('] C-l')<CR>

# quickfix stack {{{3

nnoremap <unique> <q <Cmd>call brackets#move#cnewer('<q')<CR>
nnoremap <unique> >q <Cmd>call brackets#move#cnewer('>q')<CR>

nnoremap <unique> <l <Cmd>call brackets#move#cnewer('<l')<CR>
nnoremap <unique> >l <Cmd>call brackets#move#cnewer('>l')<CR>

# tag list {{{3

nnoremap <unique> [t <Cmd>call brackets#move#tnext('[t')<CR>
nnoremap <unique> ]t <Cmd>call brackets#move#tnext(']t')<CR>

nnoremap <unique> [T <Cmd>tfirst<CR>
nnoremap <unique> ]T <Cmd>tlast<CR>
#}}}2
# Move to text matching regex {{{2

noremap <expr><unique> [` brackets#move#regex('codespan', v:false)
noremap <expr><unique> ]` brackets#move#regex('codespan', v:true)
noremap <expr><unique> [h brackets#move#regex('path', v:false)
noremap <expr><unique> ]h brackets#move#regex('path', v:true)
noremap <expr><unique> [r brackets#move#regex('ref', v:false)
noremap <expr><unique> ]r brackets#move#regex('ref', v:true)
noremap <expr><unique> [u brackets#move#regex('url', v:false)
noremap <expr><unique> ]u brackets#move#regex('url', v:true)
noremap <expr><unique> [U brackets#move#regex('concealed_url', v:false)
noremap <expr><unique> ]U brackets#move#regex('concealed_url', v:true)

# Miscellaneous {{{2
# ] SPC {{{3

nnoremap <expr><unique> =<Space> brackets#putLinesAround()
nnoremap <expr><unique> [<Space> brackets#putLineSetup('[')
nnoremap <expr><unique> ]<Space> brackets#putLineSetup(']')

# ] - {{{3

nnoremap <unique> ]- <Cmd>call brackets#ruleMotion()<CR>
nnoremap <unique> [- <Cmd>call brackets#ruleMotion(v:false)<CR>

xnoremap <unique> ]- <Cmd>call brackets#ruleMotion()<CR>
xnoremap <unique> [- <Cmd>call brackets#ruleMotion(v:false)<CR>

onoremap <unique> ]- <Cmd>execute 'normal V' .. v:count1 .. ']-'<CR>
onoremap <unique> [- <Cmd>execute 'normal V' .. v:count1 .. '[-'<CR>

nnoremap <unique> +]- <Cmd>call brackets#rulePut()<CR>
nnoremap <unique> +[- <Cmd>call brackets#rulePut(v:false)<CR>

# ]I {{{3

#                                                           ┌ don't start to search at cursor,
#                                                           │ but at beginning of file
#                                                           │
#                                                           │        ┌ don't pass a bang to the commands
#                                                           │        │ normal commands don't accept one anyway
nnoremap <unique> [I <Cmd>call brackets#diList('i', v:true, v:false, v:false)<CR>
#                                               │   │
#                                               │   └ search current word
#                                               └ command to execute (ilist or dlist)

xnoremap <unique> [I <C-\><C-N><Cmd>call brackets#diList('i', v:false, v:false, v:true)<CR>
#                                                             │
#                                                             └ don't search current word, but visual selection

nnoremap <unique> ]I <Cmd>call brackets#diList('i', v:true, v:true, v:false)<CR>
#                                                           │
#                                                           └ start to search after the line where the cursor is

xnoremap <unique> ]I <C-\><C-N><Cmd>call brackets#diList('i', v:false, v:true, v:true)<CR>

nnoremap <unique> [D <Cmd>call brackets#diList('d', v:true, v:false, v:false)<CR>
xnoremap <unique> [D <C-\><C-N><Cmd>call brackets#diList('d', v:false, v:false, v:true)<CR>

nnoremap <unique> ]D <Cmd>call brackets#diList('d', v:true, v:true, v:false)<CR>
xnoremap <unique> ]D <C-\><C-N><Cmd>call brackets#diList('d', v:false, v:true, v:true)<CR>

# ]e {{{3

nnoremap <expr><unique> [e brackets#mvLineSetup('[')
nnoremap <expr><unique> ]e brackets#mvLineSetup(']')

# ]p {{{3

# By default `]p` puts a copied line with the indentation of the current line.
# But if the copied text is characterwise, `]p` puts it as a characterwise text.
# We don't want that, we want the text to be put as linewise even if it was
# selected with a characterwise motion.

#                                             ┌ how to put internally{{{
#                                             │
#                                             │    ┌ how to indent afterwards
#                                             │    │}}}
nnoremap <expr><unique> [p brackets#putSetup('[p', '')
nnoremap <expr><unique> ]p brackets#putSetup(']p', '')

# The  following mappings  put  the  unnamed register  after  the current  line,
# treating its contents as linewise  (even if characterwise) AND perform another
# action:
#
#    - >p >P    add a level of indentation
#    - <p <P    remove a level of indentation
#    - =p =P    auto-indentation (respecting our indentation-relative options)
nnoremap <expr><unique> >P brackets#putSetup('[p', ">']")
nnoremap <expr><unique> >p brackets#putSetup(']p', ">']")
nnoremap <expr><unique> <P brackets#putSetup('[p', "<']")
nnoremap <expr><unique> <p brackets#putSetup(']p', "<']")
nnoremap <expr><unique> =P brackets#putSetup('[p', "=']")
nnoremap <expr><unique> =p brackets#putSetup(']p', "=']")

# A simpler version of the same mappings would be:
#
#     nnoremap >P [p>']
#     nnoremap >p ]p>']
#     nnoremap <P [p<']
#     nnoremap <p ]p<']
#     nnoremap =P [p=']
#     nnoremap =p ]p=']
#
# But with these ones, we would lose the linewise conversion.

# ]s  ]S {{{3

# Why? {{{
#
# By default, `zh` and `zl` move the cursor on a long non-wrapped line.
# But at the same time, we use `zj` and `zk` to split the window.
# I don't like  the `hjkl` being used  with a same prefix (`z`)  for 2 different
# purposes.
# So, we'll  use `z[hjkl]` to split  the window, and  `[s` and `]s` to  scroll a
# long non-wrapped line.
#}}}
# Warning: this shadows the default `]s` command{{{
#
# ... which  moves the  cursor to  the next wrongly spelled word.
# It's not a big deal, because you can still use `]S` which does the same thing,
# ignoring rare words and words for other regions (which is what we usually want).
#}}}

nnoremap <unique> [s 5zh
nnoremap <unique> ]s 5zl
#                  │
#                  └ mnemonic: Scroll

