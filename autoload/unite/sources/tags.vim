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


" source
let s:source = {
\   'name': 'tags',
\   'max_candidates': 30,
\   'action_table': {}
\}
function! s:source.gather_candidates(args, context)
    " parsing tag files is faster than using taglist()
    let result = []
    for tagfile in s:last_tagfiles
        let basedir = fnamemodify(tagfile, ':p:h')

        for line in readfile(tagfile)
            let [name, filename, pattern, extensions] = s:parse_tag_line(line)

            " check comment line
            if empty(name)
                continue
            endif

            let linenr = ""
            " when pattern shows line number
            if pattern =~ '^\d\+$'
                let linenr = pattern
                let pattern = ''
            " search extension_fields including linenr
            else
                for ext in extensions
                    if stridx(ext, 'line:') == 0
                        let linenr = ext[5:]
                        let pattern = ''
                        break
                    endif
                endfor
            endif

            let pattern_str = !empty(pattern) ? ' pat:[' . pattern . ']' : ''
            let linenr_str = !empty(linenr) ? ' line:' . linenr : ''
            call add(result, {
            \   'word':    basedir . '/' . filename,
            \   'abbr':    printf('[tags] %s%s%s @%s',
            \        name, pattern_str, linenr_str, fnamemodify(basedir . '/' . filename, ':.')),
            \   'kind':    'jump_list',
            \   'source':  'tags',
            \   'action__path':    basedir . '/' . filename,
            \   'action__line':    linenr,
            \   'action__pattern': pattern,
            \   'action__tagname': name
            \})
        endfor
    endfor

    return result
endfunction


" Tag file format
"   tag_name<TAB>file_name<TAB>ex_cmd;"<TAB>extension_fields
" Parse
" 0. a line starting with ! is comment line
" 1. split extension_fields and others by separating the string at the last ;"
" 2. parse the former half by spliting it by <TAB>
" 3. the first part is tag_name, the second part is file_name
"    and ex_cmd is taken by joining remain parts with <TAB>
" 4. parsing extension_fields
function! s:parse_tag_line(line)
    " 0.
    if stridx(a:line, '!') == 0
        return ['', '', '', []]
    endif

    " 1.
    let tokens = split(a:line, ';"')
    let former = join(tokens[0:-2], ';"')
    let extensions = split(tokens[-1], "\t")

    " 2.
    let fields = split(former, "\t")
    if len(fields) < 3
        return ['', '', '', []]
    endif

    " 3.
    let name = remove(fields, 0)
    let file = remove(fields, 0)
    let cmd = join(fields, "\t")

    " remove /^ at the head and $/ at the end
    let pattern = substitute(substitute(cmd, '^\/\^\?', '', ''), '\$\?\/$', '', '')
    " unescape /
    let pattern = substitute(pattern, '\\\/', '/', 'g')
    " escape regexp characters
    let pattern = substitute(pattern, '[\[\]$*^~\/]', '\\\\\0', 'g')

    " 4. TODO

    return [name, file, pattern, extensions]
endfunction

" " test case
" let s:test = 'Hoge	test.php	/^function Hoge()\/*$\/;"	f	test:*\/ {$/;"	f'
" echomsg string(s:parse_tag_line(s:test))
" let s:test = 'Hoge	Hoge/Fuga.php	/^class Hoge$/;"	c	line:15'
" echomsg string(s:parse_tag_line(s:test))

" action
let s:action_table = {}

let s:action_table.jump = {
\   'description': 'jump to the tag'
\}
function! s:action_table.jump.func(candidate)
    execute "tjump" a:candidate.action__tagname
endfunction

let s:action_table.select = {
\   'description': 'select candidates from the tag pattern'
\}
function! s:action_table.select.func(candidate)
    execute "tselect" a:candidate.action__tagname
endfunction

let s:action_table.jsplit = {
\   'description': 'split window and jump to the tag',
\   'is_selectable': 1
\}
function! s:action_table.jsplit.func(candidates)
    for c in a:candidates
        execute "stjump" c.action__tagname
    endfor
endfunction

let s:source.action_table.jump_list = s:action_table
