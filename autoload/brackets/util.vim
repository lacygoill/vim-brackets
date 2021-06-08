vim9script noclear

def brackets#util#openFold(lhs: string)
    # If an entry is located inside a fold, we want it to be opened to see the text immediately.
    if foldclosed('.') == -1
        return
    endif
    if lhs =~ '^[[\]][lL]$'
       && maparg('j', 'n', false, true)->get('rhs', '') =~ 'move_and_open_fold'
        norm! zM
    endif
    norm! zv
enddef

