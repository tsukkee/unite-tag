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
let s:source = {
\   'name': 'tags',
\   'max_candidates': 30
\}
function! s:source.gather_candidates(args, context)
    " parsing tag files is faster than using taglist()
    let result = []
    for tagfile in s:last_tagfiles
        for line in readfile(tagfile)
            let tokens = split(line, "\t")
            if len(tokens) > 4
                let [name, filename, cmd, kind, linenr] = tokens[0:4]
                " ex) line:123 -> 123
                let linenr = linenr[5:]

                " if not comment line
                if stridx(name, "!") != 0
                    call add(result, {
                    \   'word':   filename,
                    \   'abbr':   printf('[tags] %s @%s', name, filename),
                    \   'kind':   'tag',
                    \   'source': 'tags',
                    \   'line':    linenr,
                    \   'pattern': cmd,
                    \   'tagname': name
                    \})
                endif
            endif
        endfor
    endfor

    return result
endfunction
