fu brackets#util#open_fold(lhs) abort
    " If an entry is located inside a fold, we want it to be opened to see the text immediately.
    if foldclosed('.') == -1 | return | endif
    if (a:lhs is? ']l' || a:lhs is? '[l')
       \ && maparg('j', 'n', 0, 1)->get('rhs', '') =~# 'move_and_open_fold'
        norm! zM
    endif
    norm! zv
endfu

