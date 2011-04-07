" tag source for unite.vim
" Version:     0.1.0
" Last Change: 28 Feb 2011
" Author:      tsukkee <takayuki0510 at gmail.com>
"              thinca <thinca+vim@gmail.com>
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
function! unite#sources#tag#define()
    return [s:source, s:source_files]
endfunction


" cache
let s:cache = {}

" source
let s:source = {
\   'name': 'tag',
\   'description': 'candidates from tag file',
\   'max_candidates': 30,
\   'action_table': {},
\   'hooks': {},
\   'syntax': 'uniteSource__Tag',
\}

function! s:source.hooks.on_syntax(args, context)
  syntax match uniteSource__Tag_File /  @.\{-}  /ms=s+2,me=e-2 containedin=uniteSource__Tag contained nextgroup=uniteSource__Tag_Pat,uniteSource__Tag_Line skipwhite
  syntax match uniteSource__Tag_Pat /pat:.\{-}\ze\s*$/ contained
  syntax match uniteSource__Tag_Line /line:.\{-}\ze\s*$/ contained
  highlight default link uniteSource__Tag_File Type
  highlight default link uniteSource__Tag_Pat Special
  highlight default link uniteSource__Tag_Line Constant
endfunction

function! s:source.hooks.on_init(args, context)
    let a:context.source__tagfiles = tagfiles()
endfunction

function! s:source.gather_candidates(args, context)
    let a:context.source__continuation = []
    let result = []
    for tagfile in a:context.source__tagfiles
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

    let is_file = self.name ==# 'tag/file'
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

    call unite#clear_message()

    if empty(tags.cont.lines)
        call unite#print_message(
        \      printf('[tag] Caching of "%s"...done.', tags.cont.tagfile))
        call remove(tags, 'cont')
        call remove(a:context.source__continuation, 0)
        let a:context.is_async = 0
    else
        let len = tags.cont.lnum
        let progress = (len - len(tags.cont.lines)) * 100 / len
        call unite#print_message(
        \    printf('[tag] Caching of "%s"...%d%%',
        \           tags.cont.tagfile, progress))
    endif

    return s:pre_filter(result, a:args)
endfunction


" source tag/file
let s:source_files = {
\   'name': 'tag/file',
\   'description': 'candidates from files contained in tag file',
\   'max_candidates': 30,
\   'action_table': {},
\   'hooks': {'on_init': s:source.hooks.on_init},
\   'async_gather_candidates': s:source.async_gather_candidates,
\}

function! s:source_files.gather_candidates(args, context)
    let a:context.source__continuation = []
    let files = {}
    for tagfile in a:context.source__tagfiles
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
        let lines = readfile(tagfile)
        let s:cache[tagfile] = {
        \   'time': getftime(tagfile),
        \   'tags': [],
        \   'files': {},
        \   'cont': {
        \     'lines': lines,
        \     'lnum': len(lines),
        \     'basedir': fnamemodify(tagfile, ':p:h'),
        \     'encoding': '',
        \     'tagfile': tagfile,
        \   },
        \}
    endif
    return s:cache[tagfile]
endfunction

function! s:next(tags, line, is_file)
    let cont = a:tags.cont
    " parsing tag files is faster than using taglist()
    let [name, filename, pattern, extensions] = s:parse_tag_line(
    \    cont.encoding != '' ? iconv(a:line, cont.encoding, &encoding)
    \                        : a:line)

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

    let path = filename =~ '^\%(/\|\a\+:[/\\]\)' ? filename : cont.basedir . '/' . filename

    let tag = {
    \   'word':    name,
    \   'abbr':    printf('%s  @%s %s%s',
    \                  name,
    \                  fnamemodify(path, ':.'),
    \                  !empty(pattern) ? ' pat:/' . pattern . '/' : '',
    \                  !empty(linenr)  ? ' line:' . linenr : ''),
    \   'kind':    'jump_list',
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
