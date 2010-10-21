" tags, tags/help sources for unite.vim
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
    return [s:source_tags, s:source_tags_help]
endfunction


" save tag files
let s:last_tagfiles = []
function! unite#sources#tags#_save_last_tagfiles()
    if &filetype != 'unite'
        let s:last_tagfiles = tagfiles()
    endif
endfunction

" for debug
function! unite#sources#tags#_get_last_tagfiles()
    return s:last_tagfiles
endfunction


" tags
let s:source_tags = {
\   'name': 'tags',
\   'max_candidates': 30
\}
function! s:source_tags.gather_candidates(args, candidate)
    return s:gather_candidates(0, a:args, a:candidate)
endfunction


" tags/help
let s:source_tags_help = {
\   'name': 'tags/help',
\   'max_candidates': 30,
\   'action_table': {},
\   'default_action': {'word': 'lookup'}
\}
function! s:source_tags_help.gather_candidates(args, candidate)
    return s:gather_candidates(1, a:args, a:candidate)
endfunction

let s:action_table_tags_help = {}
let s:action_table_tags_help.lookup = {
\   'is_selectable': 1
\}
function! s:action_table_tags_help.lookup.func(candidate)
    execute "help" a:candidate.word
endfunction

let s:source_tags_help.action_table.word = s:action_table_tags_help


" gather
function! s:gather_candidates(is_help, args, context)
    let saved_buftype = &l:buftype
    if a:is_help
        let &l:buftype = "help"
    endif

    let abbr_prefix = a:is_help ? '[help] '   : '[tag] '
    let source_kind = a:is_help ? 'word'      : 'tag'
    let source_name = a:is_help ? 'tags/help' : 'tags'

    let result = []

    " parsing tagfiles() is faster than using taglist()
    for tagfile in s:unique(tagfiles())
        for line in readfile(tagfile)
            let [word, file] = split(line, "\t")[0:1]
            if stridx(word, "!") != 0
                call add(result, {
                \   'word': word,
                \   'abbr': abbr_prefix . word . (a:is_help ? '' : ' @' . file),
                \   'kind': source_kind,
                \   'source': source_name,
                \   'is_insert': a:context.is_insert
                \})
            endif
        endfor
    endfor
    " this is accurate but slow
    " for t in taglist('.')
        " call add(result, {
        " \   'word': t.name,
        " \   'abbr': abbr_prefix . t.name . (a:is_help ? '' : ' @' . t.filename),
        " \   'kind': source_kind,
        " \   'source': source_name,
        " \   'is_insert': a:context.is_insert
        " \})
    " endfor

    let &l:buftype = saved_buftype

    return result
endfunction


" unique
function! s:unique(array)
    if len(a:array) <= 1
        return a:array
    endif

    let sorted = sort(a:array)
    let result = [sorted[0]]
    for item in sorted
        if item != result[-1]
            call add(result, item)
        endif
    endfor
    return result
endfunction

