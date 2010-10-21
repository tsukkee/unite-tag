" tag kind for unite.vim
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

" define kind
function! unite#kinds#tag#define()
    return s:kind
endfunction

let s:kind = {
\    'name' : 'tag',
\    'default_action' : 'lookup',
\    'action_table': {},
\}

let s:kind.action_table = deepcopy(unite#kinds#word#define().action_table)

let s:kind.action_table.lookup = {
\   'is_selectable': 1
\}
function! s:kind.action_table.lookup.func(candidate)
    execute "tag" a:candidate.word
endfunction

let s:kind.action_table.jump = {
\   'is_selectable': 1
\}
function! s:kind.action_table.jump.func(candidate)
    execute "tjump" a:candidate.word
endfunction

let s:kind.action_table.select = {
\   'is_selectable': 1
\}
function! s:kind.action_table.select.func(candidate)
    execute "tselect" a:candidate.word
endfunction

let s:kind.action_table.split = {
\   'is_selectable': 1
\}
function! s:kind.action_table.split.func(candidate)
    execute "stjump" a:candidate.word
endfunction

let s:kind.action_table.preview = {
\   'is_selectable': 1,
\   'is_quit': 0
\}
function! s:kind.action_table.preview.func(candidate)
    execute "ptjump" a:candidate.word
endfunction
