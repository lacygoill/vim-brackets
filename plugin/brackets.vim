vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

# Commands {{{1
# Ilist {{{2

#                                         ┌ command{{{
#                                         │
#                                         │   ┌ pattern is NOT word under cursor
#                                         │   │
#                                         │   │      ┌ do NOT start searching after current line
#                                         │   │      │  start from beginning of file
#                                         │   │      │
#                                         │   │      │      ┌ search in comments only if a bang is added
#                                         │   │      │      │
#                                         │   │      │      │        ┌ pattern
#                                         │   │      │      │        │}}}
com -bang -nargs=1 Ilist brackets#diList('i', false, false, <bang>0, <q-args>)
com -bang -nargs=1 Dlist brackets#diList('d', false, false, <bang>0, <q-args>)
#}}}1
# Mappings {{{1
# Move in lists {{{2
# arglist {{{3

nno <unique> [a <cmd>call brackets#move#next('[a')<cr>
nno <unique> ]a <cmd>call brackets#move#next(']a')<cr>

nno <unique> [A <cmd>first<cr>
nno <unique> ]A <cmd>last<cr>

# buffer list {{{3

# `:bnext` wrap around the end of the buffer list by default
nno <unique> [b <cmd>exe v:count .. 'bprevious'<cr>
nno <unique> ]b <cmd>exe v:count .. 'bnext'<cr>

nno <unique> [B <cmd>bfirst<cr>
nno <unique> ]B <cmd>blast<cr>

# file list {{{3

nno <unique> ]f <cmd>exe 'e ' .. brackets#nextFileToEdit(v:count1)->fnameescape()<cr>
nno <unique> [f <cmd>exe 'e ' .. brackets#nextFileToEdit(-v:count1)->fnameescape()<cr>

# quickfix list {{{3

nno <unique> [q <cmd>call brackets#move#cnext('[q')<cr>
nno <unique> ]q <cmd>call brackets#move#cnext(']q')<cr>

nno <unique> [l <cmd>call brackets#move#cnext('[l')<cr>
nno <unique> ]l <cmd>call brackets#move#cnext(']l')<cr>

nno <unique> [Q <cmd>cfirst<cr>
nno <unique> ]Q <cmd>clast<cr>

nno <unique> [L <cmd>lfirst<cr>
nno <unique> ]L <cmd>llast<cr>

nno <unique> [<c-q> <cmd>call brackets#move#cnext('[ c-q')<cr>
nno <unique> ]<c-q> <cmd>call brackets#move#cnext('] c-q')<cr>

nno <unique> [<c-l> <cmd>call brackets#move#cnext('[ c-l')<cr>
nno <unique> ]<c-l> <cmd>call brackets#move#cnext('] c-l')<cr>

# quickfix stack {{{3

nno <unique> <q <cmd>call brackets#move#cnewer('<q')<cr>
nno <unique> >q <cmd>call brackets#move#cnewer('>q')<cr>

nno <unique> <l <cmd>call brackets#move#cnewer('<l')<cr>
nno <unique> >l <cmd>call brackets#move#cnewer('>l')<cr>

# tag list {{{3

nno <unique> [t <cmd>call brackets#move#tnext('[t')<cr>
nno <unique> ]t <cmd>call brackets#move#tnext(']t')<cr>

nno <unique> [T <cmd>tfirst<cr>
nno <unique> ]T <cmd>tlast<cr>
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

nno <expr><unique> =<space> brackets#putLinesAround()
nno <expr><unique> [<space> brackets#putLineSetup('[')
nno <expr><unique> ]<space> brackets#putLineSetup(']')

# ] - {{{3

nno <unique> ]- <cmd>call brackets#ruleMotion()<cr>
nno <unique> [- <cmd>call brackets#ruleMotion(v:false)<cr>

xno <unique> ]- <cmd>call brackets#ruleMotion()<cr>
xno <unique> [- <cmd>call brackets#ruleMotion(v:false)<cr>

ono <unique> ]- <cmd>exe 'norm V' .. v:count1 .. ']-'<cr>
ono <unique> [- <cmd>exe 'norm V' .. v:count1 .. '[-'<cr>

nno <unique> +]- <cmd>call brackets#rulePut()<cr>
nno <unique> +[- <cmd>call brackets#rulePut(v:false)<cr>

# ]I {{{3

#                                                      ┌ don't start to search at cursor,
#                                                      │ but at beginning of file
#                                                      │
#                                                      │        ┌ don't pass a bang to the commands
#                                                      │        │ normal commands don't accept one anyway
nno <unique> [I <cmd>call brackets#diList('i', v:true, v:false, v:false)<cr>
#                                          │   │
#                                          │   └ search current word
#                                          └ command to execute (ilist or dlist)

xno <unique> [I <c-\><c-n><cmd>call brackets#diList('i', v:false, v:false, v:true)<cr>
#                                                        │
#                                                        └ don't search current word, but visual selection

nno <unique> ]I <cmd>call brackets#diList('i', v:true, v:true, v:false)<cr>
#                                                      │
#                                                      └ start to search after the line where the cursor is

xno <unique> ]I <c-\><c-n><cmd>call brackets#diList('i', v:false, v:true, v:true)<cr>

nno <unique> [D <cmd>call brackets#diList('d', v:true, v:false, v:false)<cr>
xno <unique> [D <c-\><c-n><cmd>call brackets#diList('d', v:false, v:false, v:true)<cr>

nno <unique> ]D <cmd>call brackets#diList('d', v:true, v:true, v:false)<cr>
xno <unique> ]D <c-\><c-n><cmd>call brackets#diList('d', v:false, v:true, v:true)<cr>

# ]e {{{3

nno <expr><unique> [e brackets#mvLineSetup('[')
nno <expr><unique> ]e brackets#mvLineSetup(']')

# ]p {{{3

# By default `]p` puts a copied line with the indentation of the current line.
# But if the copied text is characterwise, `]p` puts it as a characterwise text.
# We don't want that, we want the text to be put as linewise even if it was
# selected with a characterwise motion.

#                                        ┌ how to put internally{{{
#                                        │
#                                        │    ┌ how to indent afterwards
#                                        │    │}}}
nno <expr><unique> [p brackets#putSetup('[p', '')
nno <expr><unique> ]p brackets#putSetup(']p', '')

# The  following mappings  put  the  unnamed register  after  the current  line,
# treating its contents as linewise  (even if characterwise) AND perform another
# action:
#
#    - >p >P    add a level of indentation
#    - <p <P    remove a level of indentation
#    - =p =P    auto-indentation (respecting our indentation-relative options)
nno <expr><unique> >P brackets#putSetup('[p', ">']")
nno <expr><unique> >p brackets#putSetup(']p', ">']")
nno <expr><unique> <P brackets#putSetup('[p', "<']")
nno <expr><unique> <p brackets#putSetup(']p', "<']")
nno <expr><unique> =P brackets#putSetup('[p', "=']")
nno <expr><unique> =p brackets#putSetup(']p', "=']")

# A simpler version of the same mappings would be:
#
#     nno >P [p>']
#     nno >p ]p>']
#     nno <P [p<']
#     nno <p ]p<']
#     nno =P [p=']
#     nno =p ]p=']
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

nno <unique> [s 5zh
nno <unique> ]s 5zl
#             │
#             └ mnemonic: Scroll

