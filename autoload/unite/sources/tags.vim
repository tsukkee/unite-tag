" tags source for unite.vim
" Version:     0.0.1
" Last Change: 21 Oct 2010
" Author:      tsukkee <takayuki0510 at gmail.com>
" Licence:     The MIT License {{{
"     Permission is hereby granted, free of charge, to any person obtaining a copy
"     of this software and associated documentation files (the "Software"), to deal
"     in the Software without restriction, including without limitation the rights
"     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"     copies of the Software, and to permit persons to whom the Software is
"     furnished to do so, subject to the following conditions:
"
"     The above copyright notice and this permission notice shall be included in
"     all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
"     THE SOFTWARE.
" }}}

" define source
function! unite#sources#tags#define()
    return s:source
endfunction


" save taglist
let s:last_taglist = []
function! unite#sources#tags#_save_last_taglist()
    if &filetype != 'unite'
        let s:last_taglist = taglist('.')
    endif
endfunction

" for debug
function! unite#sources#tags#_get_last_tagfiles()
    return s:last_taglist
endfunction


" source
let s:source = {
\   'name': 'tags',
\   'max_candidates': 30,
\   'action_table': {}
\}
function! s:source.gather_candidates(args, context)
    " parsing tag files is faster than using taglist()
    let result = []

    for t in s:last_taglist
        " remove /^ at the head and $/ at the end
        let pattern = substitute(substitute(t.cmd, '^\/\^\?', '', ''), '\$\?\/$', '', '')
        " unescape /
        let pattern = substitute(pattern, '\\\/', '/', 'g')

        " linenr
        let linenr = ""
        if pattern =~ '^\d\+$'
            let linenr = pattern
            let pattern = ''
        elseif has_key(t, 'line')
            let linenr = t.line
            let pattern = ''
        endif

        let pattern_str = !empty(pattern) ? ' pat:[' . pattern . ']' : ''
        let linenr_str = !empty(linenr) ? ' line:' . linenr : ''
        call add(result, {
        \   'word':    t.filename,
        \   'abbr':    printf('[tags] %s%s%s @%s',
        \        t.name, pattern_str, linenr_str, t.filename),
        \   'kind':    'jump_list',
        \   'source':  'tags',
        \   'line':    linenr,
        \   'pattern': pattern,
        \   'tagname': t.name
        \})
    endfor

    return result
endfunction


" action
let s:action_table = {}

let s:action_table.jump = {
\   'is_selectable': 1
\}
function! s:action_table.jump.func(candidate)
    execute "tjump" a:candidate.tagname
endfunction

let s:action_table.select = {
\   'is_selectable': 1
\}
function! s:action_table.select.func(candidate)
    execute "tselect" a:candidate.tagname
endfunction

let s:action_table.jsplit = {
\   'is_selectable': 1
\}
function! s:action_table.jsplit.func(candidate)
    execute "stjump" a:candidate.tagname
endfunction

let s:source.action_table.jump_list = s:action_table
