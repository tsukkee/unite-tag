" tags source for unite.vim
" Version:     0.0.3
" Last Change: 15 Nov 2010
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
    return [s:source, s:source_files]
endfunction


" cache
let s:cache = {}

" source
let s:source = {
\   'name': 'tags',
\   'max_candidates': 30,
\   'action_table': {},
\   'hooks': {}
\}

function! s:source.hooks.on_init(args, context)
    let s:last_tagfiles = tagfiles()
endfunction

function! s:source.gather_candidates(args, context)
    let a:context.source__continuation = []
    let result = []
    for tagfile in s:last_tagfiles
        let tags = s:get_tags(tagfile)
        if empty(tags)
            continue
        endif
        let result += tags.tags
        if has_key(tags, 'cont')
            call add(a:context.source__continuation, tags)
        endif
    endfor

    return s:pre_filter(result, a:args)
endfunction

function! s:source.async_gather_candidates(args, context)
    if empty(a:context.source__continuation)
        return []
    endif
    let result = []
    let tags = a:context.source__continuation[0]

    let is_file = self.name ==# 'tags/file'
    if has('reltime') && has('float')
        let time = reltime()
        while str2float(reltimestr(reltime(time))) < 0.05
        \       && !empty(tags.cont.lines)
            let result += s:next(tags, remove(tags.cont.lines, 0), is_file)
        endwhile
    else
        let i = 100
        while 0 < i && !empty(tags.cont.lines)
            let result += s:next(tags, remove(tags.cont.lines, 0), is_file)
            let i -= 1
        endwhile
    endif

    if empty(tags.cont.lines)
        call remove(tags, 'cont')
        call remove(a:context.source__continuation, 0)
    endif

    return s:pre_filter(result, a:args)
endfunction


" source tags/file
let s:source_files = {
\   'name': 'tags/file',
\   'max_candidates': 30,
\   'action_table': {},
\   'hooks': {'on_init': s:source.hooks.on_init},
\   'async_gather_candidates': s:source.async_gather_candidates,
\}

function! s:source_files.gather_candidates(args, context)
    let a:context.source__continuation = []
    let files = {}
    for tagfile in s:last_tagfiles
        let tags = s:get_tags(tagfile)
        if empty(tags)
            continue
        endif
        call extend(files, tags.files)
        if has_key(tags, 'cont')
            call add(a:context.source__continuation, tags)
        endif
    endfor

    return map(sort(keys(files)), 'files[v:val]')
endfunction


function! s:pre_filter(result, args)
    if !empty(a:args)
        let arg = a:args[0]
        if arg == '/'
            let pat = arg[1 : ]
            call filter(a:result, 'v:val.word =~? pat')
        else
            call filter(a:result, 'v:val.word == arg')
        endif
    endif
    return a:result
endfunction

function! s:get_tags(tagfile)
    let tagfile = fnamemodify(a:tagfile, ':p')
    if !filereadable(tagfile)
        return {}
    endif
    if !has_key(s:cache, tagfile) || s:cache[tagfile].time != getftime(tagfile)
        let s:cache[tagfile] = {
        \   'time': getftime(tagfile),
        \   'tags': [],
        \   'files': {},
        \   'cont': {
        \     'lines': readfile(tagfile),
        \     'basedir': fnamemodify(tagfile, ':p:h'),
        \     'encoding': '',
        \   },
        \}
    endif
    return s:cache[tagfile]
endfunction

function! s:next(tags, line, is_file)
    let cont = a:tags.cont
    if cont.encoding != ''
        let line = iconv(line, cont.encoding, &encoding)
    endif
    " parsing tag files is faster than using taglist()
    let [name, filename, pattern, extensions] = s:parse_tag_line(a:line)

    " check comment line
    if empty(name)
        if filename != ''
            let cont.encoding = filename
        endif
        return []
    endif

    " when pattern shows line number
    let linenr = ""
    if pattern =~ '^\d\+$'
        let linenr = pattern
        let pattern = ''
    endif

    " FIXME: It works only on Unix.
    let path = filename =~ '^/' ? filename : cont.basedir . '/' . filename

    let tag = {
    \   'word':    name,
    \   'abbr':    printf('%s @%s %s%s',
    \                  name,
    \                  fnamemodify(path, ':.'),
    \                  !empty(pattern) ? ' pat:/' . pattern . '/' : '',
    \                  !empty(linenr)  ? ' line:' . linenr : ''),
    \   'kind':    'jump_list',
    \   'source':  'tags',
    \   'action__path':    path,
    \   'action__line':    linenr,
    \   'action__pattern': pattern,
    \   'action__tagname': name
    \}
    call add(a:tags.tags, tag)

    let result = a:is_file ? [] : [tag]

    let fullpath = fnamemodify(path, ':p')
    if !has_key(a:tags.files, fullpath)
        let file = {
        \   "word": fullpath,
        \   "abbr": fnamemodify(fullpath, ":."),
        \   "kind": "file",
        \   "source": "tags/file",
        \   "action__path": fullpath,
        \   "action__directory": unite#path2directory(fullpath),
        \ }
        let a:tags.files[fullpath] = file
        if a:is_file
            let result = [file]
        endif
    endif

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
        let enc = matchstr(a:line, '\C^!_TAG_FILE_ENCODING\t\zs\S\+\ze\t')
        return ['', enc, '', []]
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
    let pattern = substitute(pattern, '[\[\]$*^~\/]', '\\\0', 'g')

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
\   'description': 'jump to the selected tag'
\}
function! s:action_table.jump.func(candidate)
    execute "tjump" a:candidate.action__tagname
endfunction

let s:action_table.select = {
\   'description': 'list the tags matching the selected tag pattern'
\}
function! s:action_table.select.func(candidate)
    execute "tselect" a:candidate.action__tagname
endfunction

let s:action_table.jsplit = {
\   'description': 'split window and jump to the selected tag',
\   'is_selectable': 1
\}
function! s:action_table.jsplit.func(candidates)
    for c in a:candidates
        execute "stjump" c.action__tagname
    endfor
endfunction

let s:source.action_table.jump_list = s:action_table
