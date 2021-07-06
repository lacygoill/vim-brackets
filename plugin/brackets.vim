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

nmap <unique> ]a <Plug>(next-file-in-arglist)
nmap <unique> [a <Plug>(prev-file-in-arglist)
nnoremap <Plug>(next-file-in-arglist) <Cmd>call brackets#move#next(']a')<CR>
nnoremap <Plug>(prev-file-in-arglist) <Cmd>call brackets#move#next('[a')<CR>

nnoremap <unique> [A <Cmd>first<CR>
nnoremap <unique> ]A <Cmd>last<CR>

# buffer list {{{3

# `:bnext` wrap around the end of the buffer list by default
nmap <unique> ]b <Plug>(next-buffer)
nmap <unique> [b <Plug>(prev-buffer)
nnoremap <Plug>(next-buffer) <Cmd>execute v:count .. 'bnext'<CR>
nnoremap <Plug>(prev-buffer) <Cmd>execute v:count .. 'bprevious'<CR>

nnoremap <unique> [B <Cmd>bfirst<CR>
nnoremap <unique> ]B <Cmd>blast<CR>

# file list {{{3

nmap <unique> ]f <Plug>(next-file)
nmap <unique> [f <Plug>(prev-file)
nnoremap <Plug>(next-file) <Cmd>execute 'edit ' .. brackets#nextFileToEdit(v:count1)->fnameescape()<CR>
nnoremap <Plug>(prev-file) <Cmd>execute 'edit ' .. brackets#nextFileToEdit(-v:count1)->fnameescape()<CR>

# quickfix list {{{3

nmap <unique> ]q <Plug>(next-entry-in-qfl)
nmap <unique> [q <Plug>(prev-entry-in-qfl)
nnoremap <Plug>(next-entry-in-qfl) <Cmd>call brackets#move#cnext(']q')<CR>
nnoremap <Plug>(prev-entry-in-qfl) <Cmd>call brackets#move#cnext('[q')<CR>

nmap <unique> ]l <Plug>(next-entry-in-loclist)
nmap <unique> [l <Plug>(prev-entry-in-loclist)
nnoremap <Plug>(next-entry-in-loclist) <Cmd>call brackets#move#cnext(']l')<CR>
nnoremap <Plug>(prev-entry-in-loclist) <Cmd>call brackets#move#cnext('[l')<CR>

nnoremap <unique> [Q <Cmd>cfirst<CR>
nnoremap <unique> ]Q <Cmd>clast<CR>

nnoremap <unique> [L <Cmd>lfirst<CR>
nnoremap <unique> ]L <Cmd>llast<CR>

nmap <unique> ]<C-Q> <Plug>(next-file-in-qfl)
nmap <unique> [<C-Q> <Plug>(prev-file-in-qfl)
nnoremap <Plug>(next-file-in-qfl) <Cmd>call brackets#move#cnext('] C-q')<CR>
nnoremap <Plug>(prev-file-in-qfl) <Cmd>call brackets#move#cnext('[ C-q')<CR>

nmap <unique> ]<C-L> <Plug>(next-file-in-loclist)
nmap <unique> [<C-L> <Plug>(prev-file-in-loclist)
nnoremap <Plug>(next-file-in-loclist) <Cmd>call brackets#move#cnext('] C-l')<CR>
nnoremap <Plug>(prev-file-in-loclist) <Cmd>call brackets#move#cnext('[ C-l')<CR>

# quickfix stack {{{3

nmap <unique> >q <Plug>(next-qflist)
nmap <unique> <q <Plug>(prev-qflist)
nnoremap <Plug>(next-qflist) <Cmd>call brackets#move#cnewer('>q')<CR>
nnoremap <Plug>(prev-qflist) <Cmd>call brackets#move#cnewer('<q')<CR>

nmap <unique> >l <Plug>(next-loclist)
nmap <unique> <l <Plug>(prev-loclist)
nnoremap <Plug>(next-loclist) <Cmd>call brackets#move#cnewer('>l')<CR>
nnoremap <Plug>(prev-loclist) <Cmd>call brackets#move#cnewer('<l')<CR>

# tag stack {{{3

nmap <unique> ]t <Plug>(next-tag)
nmap <unique> [t <Plug>(prev-tag)
nnoremap <Plug>(next-tag) <Cmd>call brackets#move#tnext(']t')<CR>
nnoremap <Plug>(prev-tag) <Cmd>call brackets#move#tnext('[t')<CR>

nnoremap <unique> [T <Cmd>tfirst<CR>
nnoremap <unique> ]T <Cmd>tlast<CR>
#}}}2
# Move to text matching regex {{{2

map <unique> ]` <Plug>(next-codespan)
map <unique> [` <Plug>(prev-codespan)
noremap <expr> <Plug>(next-codespan) brackets#move#regex('codespan')
noremap <expr> <Plug>(prev-codespan) brackets#move#regex('codespan', v:false)

map <unique> ]h <Plug>(next-path)
map <unique> [h <Plug>(prev-path)
noremap <expr> <Plug>(next-path) brackets#move#regex('path')
noremap <expr> <Plug>(prev-path) brackets#move#regex('path', v:false)

map <unique> ]r <Plug>(next-reference-link)
map <unique> [r <Plug>(prev-reference-link)
noremap <expr> <Plug>(next-reference-link) brackets#move#regex('ref')
noremap <expr> <Plug>(prev-reference-link) brackets#move#regex('ref', v:false)

map <unique> ]u <Plug>(next-url)
map <unique> [u <Plug>(prev-url)
noremap <expr> <Plug>(next-url) brackets#move#regex('url')
noremap <expr> <Plug>(prev-url) brackets#move#regex('url', v:false)

map <unique> ]U <Plug>(next-concealed-url)
map <unique> [U <Plug>(prev-concealed-url)
noremap <expr> <Plug>(next-concealed-url) brackets#move#regex('concealed-url')
noremap <expr> <Plug>(prev-concealed-url) brackets#move#regex('concealed-url', v:false)

# Miscellaneous {{{2
# ] SPC {{{3

nnoremap <expr><unique> =<Space> brackets#putLinesAround()
nnoremap <expr><unique> [<Space> brackets#putLineSetup('[')
nnoremap <expr><unique> ]<Space> brackets#putLineSetup(']')

# ] - {{{3

map <unique> ]- <Plug>(next-rule)
map <unique> [- <Plug>(prev-rule)
noremap <Plug>(next-rule) <Cmd>call brackets#ruleMotion()<CR>
noremap <Plug>(prev-rule) <Cmd>call brackets#ruleMotion(v:false)<CR>

# can't write `<unique>`; we need to override the operator-pending mode
# installed by the previous `:map`
onoremap [- <Cmd>execute 'normal V' .. v:count1 .. '[-'<CR>
onoremap ]- <Cmd>execute 'normal V' .. v:count1 .. ']-'<CR>

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

nmap <unique> [e <Plug>(mv-line-above)
nmap <unique> ]e <Plug>(mv-line-below)
nnoremap <expr> <Plug>(mv-line-above) brackets#mvLineSetup('[')
nnoremap <expr> <Plug>(mv-line-below) brackets#mvLineSetup(']')

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
# I  don't like  `hjkl` being  used with  a same  prefix (`z`)  for 2  different
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

nmap <unique> [s <Plug>(scroll-line-bwd)
nmap <unique> ]s <Plug>(scroll-line-fwd)
nnoremap <Plug>(scroll-line-bwd) 5zh
nnoremap <Plug>(scroll-line-fwd) 5zl

