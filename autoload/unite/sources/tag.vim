" tag source for unite.vim
" Version:     0.2.0
" Author:      tsukkee <takayuki0510 at gmail.com>
"              thinca <thinca+vim@gmail.com>
"              Shougo <ShougoMatsu at gmail.com>
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
function! unite#sources#tag#define() abort
    return [s:source, s:source_files, s:source_include]
endfunction

let g:unite_source_tag_max_name_length =
    \ get(g:, 'unite_source_tag_max_name_length', 25)
let g:unite_source_tag_max_kind_length =
    \ get(g:, 'unite_source_tag_max_kind_length', 8)
let g:unite_source_tag_max_fname_length =
    \ get(g:, 'unite_source_tag_max_fname_length', 20)

let g:unite_source_tag_name_footer_length =
    \ get(g:, 'unite_source_tag_name_footer_length', 10)
let g:unite_source_tag_fname_footer_length =
    \ get(g:, 'unite_source_tag_fname_footer_length', 15)

" When enabled, use multi-byte aware string truncate method
let g:unite_source_tag_strict_truncate_string =
    \ get(g:, 'unite_source_tag_strict_truncate_string', 1)

let g:unite_source_tag_show_fname =
    \ get(g:, 'unite_source_tag_show_fname', 1)

let g:unite_source_tag_show_kind =
    \ get(g:, 'unite_source_tag_show_kind', 1)

let g:unite_source_tag_relative_fname =
    \ get(g:, 'unite_source_tag_relative_fname', 1)

let g:unite_source_tag_show_location =
    \ get(g:, 'unite_source_tag_show_location', 1)

" cache
let s:tagfile_cache = {}
let s:input_cache = {}

" cache directory
let s:cache_dir = unite#get_data_directory() . '/tag'
if !isdirectory(s:cache_dir)
    call mkdir(s:cache_dir, 'p')
endif

" use vital
let s:C = unite#util#get_vital_cache()

" source
let s:source = {
\   'name': 'tag',
\   'description': 'candidates from tag file',
\   'max_candidates': 200,
\   'action_table': {},
\   'hooks': {},
\   'syntax': 'uniteSource__Tag',
\}

function! s:source.hooks.on_syntax(args, context) abort
  syntax match uniteSource__Tag_File /  @.\{-}  /ms=s+2,me=e-2
              \ containedin=uniteSource__Tag contained
              \ nextgroup=uniteSource__Tag_Kind,
              \uniteSource__Tag_Pat,uniteSource__Tag_Line skipwhite
  syntax match uniteSource__Tag_Kind /k:\h\w*\s\+/ contained
              \ nextgroup=uniteSource__Tag_Pat,uniteSource__Tag_Line
  syntax match uniteSource__Tag_Pat /pat:.\{-}\ze\s*$/ contained
  syntax match uniteSource__Tag_Line /line:.\{-}\ze\s*$/ contained
  highlight default link uniteSource__Tag_File Constant
  highlight default link uniteSource__Tag_Kind Type
  highlight default link uniteSource__Tag_Pat Comment
  highlight default link uniteSource__Tag_Line LineNr
  if has('conceal')
      syntax match uniteSource__Tag_Ignore /pat:/
                  \ containedin=uniteSource__Tag_Pat conceal
  else
      syntax match uniteSource__Tag_Ignore /pat:/
                  \ containedin=uniteSource__Tag_Pat
      highlight default link uniteSource__Tag_Ignore Ignore
  endif
endfunction

function! s:source.hooks.on_init(args, context) abort
    let a:context.source__tagfiles = tagfiles()
    let a:context.source__name = 'tag'
endfunction

function! s:source.gather_candidates(args, context) abort
    let a:context.source__continuation = []
    if a:context.input != ''
        return s:taglist_filter(a:context.input, self.name)
    endif

    let result = []
    for tagfile in a:context.source__tagfiles
        let tagdata = s:get_tagdata(tagfile, a:context)
        if empty(tagdata)
            continue
        endif
        let result += tagdata.tags
        if has_key(tagdata, 'cont')
            let a:context.is_async = 1
            call add(a:context.source__continuation, tagdata)
        endif
    endfor

    let a:context.source__cont_number = 1
    let a:context.source__cont_max = len(a:context.source__continuation)

    return s:pre_filter(result, a:args)
endfunction

function! s:source.async_gather_candidates(args, context) abort
    " caching has done
    if empty(a:context.source__continuation)
        let a:context.is_async = 0
        call unite#print_message(
        \    printf('[%s] Caching Done!', a:context.source__name))
        return []
    endif

    let result = []
    let tagdata = a:context.source__continuation[0]
    if !has_key(tagdata, 'cont')
        return []
    endif

    let is_file = self.name ==# 'tag/file'
    " gather all candidates if 'immediately' flag is set
    if a:context.immediately
        while !empty(tagdata.cont.lines)
            let result += s:next(tagdata, remove(tagdata.cont.lines, 0), self.name)
        endwhile
    " gather candidates per 0.05s if 'reltime' and 'float' are enable
    elseif has('reltime') && has('float')
        let time = reltime()
        while str2float(reltimestr(reltime(time))) < 1.0
        \       && !empty(tagdata.cont.lines)
            let result += s:next(tagdata, remove(tagdata.cont.lines, 0), self.name)
        endwhile
    " otherwise, gather candidates per 100 items
    else
        let i = 1000
        while 0 < i && !empty(tagdata.cont.lines)
            let result += s:next(tagdata, remove(tagdata.cont.lines, 0), self.name)
            let i -= 1
        endwhile
    endif

    " show progress
    call unite#clear_message()
    let len = tagdata.cont.lnum
    let progress = (len - len(tagdata.cont.lines)) * 100 / len
    call unite#print_message(
                \    printf('[%s] [%2d/%2d] Caching of "%s"...%d%%',
                \           a:context.source__name,
                \           a:context.source__cont_number, a:context.source__cont_max,
                \           tagdata.cont.tagfile, progress))

    " when caching has done
    if empty(tagdata.cont.lines)
        let tagfile = tagdata.cont.tagfile

        call remove(tagdata, 'cont')
        call remove(a:context.source__continuation, 0)
        let a:context.source__cont_number += 1

        " output parse results to file
        call s:write_cache(tagfile)
    endif

    return s:pre_filter(result, a:args)
endfunction


" source tag/file
let s:source_files = {
\   'name': 'tag/file',
\   'description': 'candidates from files contained in tag file',
\   'action_table': {},
\   'hooks': {'on_init': s:source.hooks.on_init},
\   'async_gather_candidates': s:source.async_gather_candidates,
\}

function! s:source_files.gather_candidates(args, context) abort
    let a:context.source__continuation = []
    let files = {}
    for tagfile in a:context.source__tagfiles
        let tagdata = s:get_tagdata(tagfile, a:context)
        if empty(tagdata)
            continue
        endif
        call extend(files, tagdata.files)
        if has_key(tagdata, 'cont')
            let a:context.is_async = 1
            call add(a:context.source__continuation, tagdata)
        endif
    endfor

    let a:context.source__cont_number = 1
    let a:context.source__cont_max = len(a:context.source__continuation)

    return map(sort(keys(files)), 'files[v:val]')
endfunction


" source tag/include
let s:source_include = deepcopy(s:source)
let s:source_include.name = 'tag/include'
let s:source_include.description =
            \ 'candidates from files contained in include tag file'
let s:source_include.max_candidates = 0

function! s:source_include.hooks.on_init(args, context) abort
    if get(g:, 'loaded_neoinclude', 0)
        if empty(neoinclude#include#get_tag_files())
            NeoIncludeMakeCache
        endif
        let a:context.source__tagfiles = neoinclude#include#get_tag_files()
    else
        let a:context.source__tagfiles = []
    endif
    let a:context.source__name = 'tag/include'
endfunction

function! s:source_include.gather_candidates(args, context) abort
    if empty(a:context.source__tagfiles)
        call unite#print_message(
        \    printf('[%s] Nothing include files.', a:context.source__name))
    endif

    let a:context.source__continuation = []
    let result = []
    for tagfile in a:context.source__tagfiles
        let tagdata = s:get_tagdata(tagfile, a:context)
        if empty(tagdata)
            continue
        endif
        let result += tagdata.tags
        if has_key(tagdata, 'cont')
            let a:context.is_async = 1
            call add(a:context.source__continuation, tagdata)
        endif
    endfor

    let a:context.source__cont_number = 1
    let a:context.source__cont_max = len(a:context.source__continuation)

    return s:pre_filter(result, a:args)
endfunction

" filter defined by unite's parameter (e.g. Unite tag:filter)
function! s:pre_filter(result, args) abort
    if empty(a:args)
        return unite#util#uniq_by(a:result, 'v:val.abbr')
    endif

    for arg in a:args
        if arg ==# ''
            continue
        endif
        if arg ==# '%'
            " Current buffer tags
            let bufname = (&ft==#'unite' ?
                        \ bufname(b:unite.prev_bufnr) : expand('%:p'))
            call filter(a:result, 'v:val.action__path ==# bufname')
        elseif arg =~# '/'
            " Pattern matching name
            let pat = arg[1 : ]
            call filter(a:result, 'v:val.word =~? pat')
        else
            " Normal matching name
            call filter(a:result, 'v:val.word ==# arg')
        endif
    endfor
    return unite#util#uniq_by(a:result, 'v:val.abbr')
endfunction

function! s:get_tagdata(tagfile, context) abort
    let tagfile = fnamemodify(a:tagfile, ':p')
    if !filereadable(tagfile)
        return {}
    endif

    " try to read date from cache file
    call s:read_cache(tagfile)

    " set cache structure when:
    " - cache file is not available
    " - cache data is expired
    if !has_key(s:tagfile_cache, tagfile)
                \ || s:tagfile_cache[tagfile].time != getftime(tagfile)
                \ || a:context.is_redraw
        let lines = readfile(tagfile)
        let s:tagfile_cache[tagfile] = {
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
    return s:tagfile_cache[tagfile]
endfunction

function! s:taglist_filter(input, name) abort
    let key = string(tagfiles()).a:input
    if has_key(s:input_cache, key)
        return s:input_cache[key]
    endif

    let taglist = map(taglist(a:input), "{
    \   'word':    v:val.name,
    \   'abbr':    printf('%s%s%s%s',
    \                  s:truncate(v:val.name,
    \                     g:unite_source_tag_max_name_length,
    \                     g:unite_source_tag_name_footer_length, '..'),
    \                  (!g:unite_source_tag_show_fname ? '' :
    \                    '  ' . s:truncate('@'.fnamemodify(
    \                     v:val.filename, (a:name ==# 'tag/include'
    \                          || !g:unite_source_tag_relative_fname ?
    \                     ':t' : ':~:.')),
    \                     g:unite_source_tag_max_fname_length,
    \                     g:unite_source_tag_fname_footer_length, '..')),
    \                  (!g:unite_source_tag_show_kind ? '' :
    \                    '  k:' . s:truncate(v:val.kind,
    \                     g:unite_source_tag_max_kind_length, 2, '..')),
    \                  (!g:unite_source_tag_show_location ? '' :
    \                    '  pat:' .  matchstr(v:val.cmd,
    \                         '^[?/]\\^\\?\\zs.\\{-1,}\\ze\\$\\?[?/]$'))
    \                  ),
    \   'kind':    'jump_list',
    \   'action__path':    unite#util#substitute_path_separator(
    \                   fnamemodify(v:val.filename, ':p')),
    \   'action__tagname': v:val.name,
    \   'source__cmd': v:val.cmd,
    \}")

    " Uniq
    let taglist = s:pre_filter(taglist, {})

    " Set search pattern.
    for tag in taglist
        let cmd = tag.source__cmd

        if cmd =~ '^\d\+$'
            let linenr = cmd - 0
            let tag.action__line = linenr
        else
            " remove / or ? at the head and the end
            let pattern = matchstr(cmd, '^\([/?]\)\?\zs.*\ze\1$')
            " unescape /
            let pattern = substitute(pattern, '\\\/', '/', 'g')
            " use 'nomagic'
            let pattern = '\M' . pattern

            let tag.action__pattern = pattern
        endif
    endfor

    let s:input_cache[key] = taglist
    return taglist
endfunction

function! s:truncate(str, max, footer_width, sep) abort
    if g:unite_source_tag_strict_truncate_string
        return unite#util#truncate_smart(a:str, a:max, a:footer_width, a:sep)
    else
        let l = len(a:str)
        if l <= a:max
            return a:str . repeat(' ', a:max - l)
        else
            return a:str[0 : (l - a:footer_width-len(a:sep))]
                        \ .a:sep.a:str[-a:footer_width : -1]
        endif
    endif
endfunction

function! s:next(tagdata, line, name) abort
    let is_file = a:name ==# 'tag/file'
    let cont = a:tagdata.cont
    " parsing tag files is faster than using taglist()
    let line = cont.encoding != '' ? iconv(a:line, cont.encoding, &encoding)
    \                        : a:line
    let [name, filename, cmd] = s:parse_tag_line(line)

    " check comment line
    if empty(name)
        if filename != ''
            let cont.encoding = filename
        endif
        return []
    endif

    " when cmd shows line number
    let linenr = 0
    if cmd =~ '^\d\+$'
        let linenr = cmd - 0
    else
        " remove / or ? at the head and the end
        if cmd =~ '^[/?]'
            let pattern = cmd[1:-2]
        else
            let pattern = cmd
        endif
        " unescape /
        let pattern = substitute(pattern, '\\\/', '/', 'g')
        " use 'nomagic'
        let pattern = '\M' . pattern
    endif

    let path = filename =~ '^\%(/\|\a\+:[/\\]\)' ?
                \ filename :
                \ unite#util#substitute_path_separator(
                \   fnamemodify(cont.basedir . '/' . filename, ':p:.'))

    let option = s:parse_option(line)

    let abbr = s:truncate(name, g:unite_source_tag_max_name_length,
                \ g:unite_source_tag_name_footer_length, '..')
    if g:unite_source_tag_show_fname
        let abbr .= '  '
        let abbr .= s:truncate('@'.
                    \  fnamemodify(path, (
                    \   (a:name ==# 'tag/include'
                    \    || !g:unite_source_tag_relative_fname) ?
                    \    ':t' : ':~:.')),
                    \  g:unite_source_tag_max_fname_length,
                    \  g:unite_source_tag_fname_footer_length, '..')
    endif
    if g:unite_source_tag_show_kind && option.kind != ''
        let abbr .= '  k:' . s:truncate(option.kind,
                    \  g:unite_source_tag_max_kind_length, 2, '..')
    endif
    if g:unite_source_tag_show_location
        let abbr .= linenr ? '  line:' . linenr
                    \      : '  pat:' .
                    \        matchstr(cmd, '^[?/]\^\?\zs.\{-1,}\ze\$\?[?/]$')
    endif

    let fullpath = unite#util#substitute_path_separator(
                \ fnamemodify(path, ':p'))
    let tag = {
    \   'word':    name,
    \   'abbr':    abbr,
    \   'kind':    'jump_list',
    \   'action__path':    fullpath,
    \   'action__tagname': name
    \}
    if linenr
        let tag.action__line = linenr
    else
        let tag.action__pattern = pattern
    endif
    call add(a:tagdata.tags, tag)

    let result = is_file ? [] : [tag]

    if !has_key(a:tagdata.files, fullpath)
        let file = {
        \   'word': fullpath,
        \   'abbr': fnamemodify(fullpath, ':.'),
        \   'kind': 'jump_list',
        \   'action__path': fullpath,
        \   'action__directory': unite#util#path2directory(fullpath),
        \ }
        let a:tagdata.files[fullpath] = file
        if is_file
            let result = [file]
        endif
    endif

    return result
endfunction


" Tag file format
"   tag_name<TAB>file_name<TAB>ex_cmd
"   tag_name<TAB>file_name<TAB>ex_cmd;"<TAB>extension_fields
" Parse
" 0. a line starting with ! is comment line
" 1. split extension_fields and others by separating the string at the last ;"
" 2. parse the former half by spliting it by <TAB>
" 3. the first part is tag_name, the second part is file_name
"    and ex_cmd is taken by joining remain parts with <TAB>
" 4. parsing extension_fields
function! s:parse_tag_line(line) abort
    " 0.
    if a:line[0] == '!'
        let enc = matchstr(a:line, '\C^!_TAG_FILE_ENCODING\t\zs\S\+\ze\t')
        return ['', enc, '']
    endif

    " 1.
    let tokens = split(a:line, ';"')
    let tokens_len = len(tokens)
    if tokens_len > 2
        let former = join(tokens[0:-2], ';"')
    elseif tokens_len == 2
        let former = tokens[0]
    else
        let former = a:line
    endif

    " 2.
    let fields = split(former, "\t")
    if len(fields) < 3
        return ['', '', '']
    endif

    " 3.
    let name = fields[0]
    let file = fields[1]
    let cmd = len(fields) == 3 ? fields[2] : join(fields[2:-1], "\t")

    " 4. TODO

    return [name, file, cmd]
endfunction
" " test case
" let s:test = 'Hoge	test.php	/^function! Hoge()\/*$\/;"	f	test:*\/ {$/;"	f'
" echomsg string(s:parse_tag_line(s:test))
" let s:test = 'Hoge	Hoge/Fuga.php	/^class Hoge$/;"	c	line:15'
" echomsg string(s:parse_tag_line(s:test))

" cache to file
function! s:filename_to_cachename(filename) abort
    return s:cache_dir . '/' . substitute(a:filename, '[\/]', '+=', 'g')
endfunction

function! s:write_cache(filename) abort
    call s:C.writefile(s:cache_dir, a:filename,
                \ [string(s:tagfile_cache[a:filename])])
endfunction

function! s:read_cache(filename) abort
    if !s:C.check_old_cache(s:cache_dir, a:filename)
        let data = s:C.readfile(s:cache_dir, a:filename)
        sandbox let s:tagfile_cache[a:filename] = eval(data[0])
    endif
endfunction

function! s:parse_option(line) abort
    let option = {}
    let option.kind = ''

    for opt in split(a:line[len(matchstr(a:line, '.*/;"')):], '\t', 1)
      let key = matchstr(opt, '^\h\w*\ze:')
      if key == ''
        let option.kind = opt
      else
        let option[key] = matchstr(opt, '^\h\w*:\zs.*')
      endif
    endfor

    return option
endfunction

" action
let s:action_table = {}

let s:action_table.jump = {
\   'description': 'jump to the selected tag'
\}
function! s:action_table.jump.func(candidate) abort
    execute "tjump" a:candidate.action__tagname
endfunction

let s:action_table.select = {
\   'description': 'list the tags matching the selected tag pattern'
\}
function! s:action_table.select.func(candidate) abort
    execute "tselect" a:candidate.action__tagname
endfunction

let s:action_table.jsplit = {
\   'description': 'split window and jump to the selected tag',
\   'is_selectable': 1
\}
function! s:action_table.jsplit.func(candidates) abort
    for c in a:candidates
        execute "stjump" c.action__tagname
    endfor
endfunction

let s:source.action_table = s:action_table
let s:source_include.action_table = s:action_table

" vim:foldmethod=marker:fen:sw=4:sts=4
