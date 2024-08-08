
command! -nargs=+ ZFDocs :call ZFDocs(ZFDocs_argParse(<f-args>))
function! ZFDocs(params)
    try
        return s:ZFDocs(a:params)
    catch
        redraw
        echo v:exception
        return {}
    endtry
endfunction

if !exists('*ZFDocs_json_decode')
    function! ZFDocs_json_decode(text)
        if !exists('*json_decode')
            throw 'json_decode not available'
        endif
        return json_decode(a:text)
    endfunction
endif

if !exists('*ZFDocs_download')
    function! ZFDocs_download(to, url)
        if executable('curl')
            let cmd = 'curl -o "%s" -L "%s"'
        elseif executable('wget')
            let cmd = 'wget -P "%s" "%s"'
        else
            throw 'curl or wget not available'
        endif
        call system(printf(cmd, a:to, a:url))
        if v:shell_error != '0'
            throw printf('download failed (%s): %s', v:shell_error, a:url)
        endif
        return 1
    endfunction
endif

if !exists('*ZFDocs_open')
    " result: result of ZFDocs()
    " params: original params passed to ZFDocs()
    function! ZFDocs_open(result, params)
        if exists(':ZFWeb')
            let cmd = 'ZFWeb'
        elseif exists(':W3m')
            let cmd = 'W3m local'
        else
            throw 'yuratomo/w3m.vim not installed'
        endif

        split
        let tmp = tempname() . '.html'
        call writefile([a:result['docHtml']], tmp)
        execute cmd . ' ' . substitute(tmp, ' ', '\\ ', 'g')
        call delete(tmp)
        execute printf('file [%s]\ %s', a:result['slug'], a:result['name'])
        return 1
    endfunction
endif

" ============================================================
function! ZFDocs_argParse(key, ...)
    let key = tolower(a:key)

    let slug = get(a:, 1, '')
    if empty(slug)
        let slug = &filetype
    endif
    if empty(slug)
        let slug = ''
    else
        let slug = tolower(slug)
    endif

    return {
                \   'key' : key,
                \   'slug' : slug,
                \ }
endfunction

function! s:cachePath()
    return get(g:, 'ZFDocs_cachePath', get(g:, 'zf_vim_cache_path', $HOME . '/.vim_cache') . '/zfdocs')
endfunction

function! ZFDocs_downloadDocList()
    call mkdir(s:cachePath(), 'p')
    let path = s:cachePath() . '/docs.json'
    let url = get(g:, 'ZFDocs_docsUrl', 'https://devdocs.io/docs.json')
    redraw
    echo 'downloading... ' . url
    call ZFDocs_download(path, url)
    redraw
    echo 'download finished: ' . url
endfunction
function! s:loadDocList(params)
    let path = s:cachePath() . '/docs.json'
    if !filereadable(path)
        if !get(a:params, 'autoDownload', get(g:, 'ZFDocs_autoDownload', 1))
            throw 'doc list not downloaded, use ZFDocs_downloadDocList() to download'
        endif
        call ZFDocs_downloadDocList()
    endif
    let ret = ZFDocs_json_decode(join(readfile(path)))
    if empty(ret)
        throw 'unable to load doc list'
    endif
    return ret
endfunction

function! ZFDocs_downloadDocIndex(slug)
    let path = printf('%s/%s.index.json', s:cachePath(), a:slug)
    let url = printf(get(g:, 'ZFDocs_docSlugIndexUrl', 'https://documents.devdocs.io/%s/index.json'), a:slug)
    redraw
    echo 'downloading... ' . url
    call ZFDocs_download(path, url)
    redraw
    echo 'download finished: ' . url
endfunction
function! s:loadDocIndex(params, slug)
    let path = printf('%s/%s.index.json', s:cachePath(), a:slug)
    if !filereadable(path)
        if !get(a:params, 'autoDownload', get(g:, 'ZFDocs_autoDownload', 1))
            throw 'doc index not downloaded, use ZFDocs_downloadDocIndex(slug) to download'
        endif
        call ZFDocs_downloadDocIndex(a:slug)
    endif
    let ret = ZFDocs_json_decode(join(readfile(path)))
    if empty(ret)
        throw 'unable to load doc index: ' . a:slug
    endif
    return ret
endfunction

function! ZFDocs_downloadDocDb(slug)
    let path = printf('%s/%s.db.json', s:cachePath(), a:slug)
    let url = printf(get(g:, 'ZFDocs_docSlugDbUrl', 'https://documents.devdocs.io/%s/db.json'), a:slug)
    redraw
    echo 'downloading... ' . url
    call ZFDocs_download(path, url)
    redraw
    echo 'download finished: ' . url
endfunction
function! s:loadDocDb(params, slug)
    let path = printf('%s/%s.db.json', s:cachePath(), a:slug)
    if !filereadable(path)
        if !get(a:params, 'autoDownload', get(g:, 'ZFDocs_autoDownload', 1))
            throw 'doc db not downloaded, use ZFDocs_downloadDocDb(slug) to download'
        endif
        call ZFDocs_downloadDocDb(a:slug)
    endif
    let ret = ZFDocs_json_decode(join(readfile(path)))
    if empty(ret)
        throw 'unable to load doc db: ' . a:slug
    endif
    return ret
endfunction

" return a list of doc slug
" exact match always at first
function! s:findSlug(docList, slug)
    let slugList = []
    for item in a:docList
        if tolower(item['slug']) == a:slug
                    \ || tolower(item['name']) == a:slug
            if index(slugList, item['slug']) < 0
                call insert(slugList, item['slug'], 0)
            endif
        elseif match(item['slug'], a:slug) >= 0
                    \ || match(item['name'], a:slug) >= 0
            if index(slugList, item['slug']) < 0
                call add(slugList, item['slug'])
            endif
        endif
    endfor
    return slugList
endfunction

" return: [
"   {
"     'name' : 'index name',
"     'path' : 'index path',
"   },
"   ...
" ]
" exact match always at first
function! s:findIndex(docIndex, key)
    let entries = a:docIndex['entries']
    let indexDataList = []
    for item in entries
        if a:key == item['name']
            call insert(indexDataList, item, 0)
        elseif match(item['name'], a:key) >= 0
            call add(indexDataList, item)
        endif
    endfor
    return indexDataList
endfunction

" return doc html string
function! s:findDocHtml(slug, docDb, indexData)
    let docHtml = get(a:docDb, a:indexData['path'], '')
    if empty(docHtml)
        throw printf('path "%s" not found in slug "%s", try clean cache: %s'
                    \ , a:indexData['path']
                    \ , a:slug
                    \ , s:cachePath()
                    \ )
    endif
    return docHtml
endfunction

function! s:choice_default(title, hints)
    let hint = []
    call add(hint, a:title)
    call add(hint, '')
    for i in range(len(a:hints))
        call add(hint, printf('  %2s: %s', i + 1, a:hints[i]))
    endfor
    call add(hint, '')
    let choice = inputlist(hint)
    redraw
    if choice >= 1 && choice < len(a:hints) + 1
        return choice - 1
    else
        return -1
    endif
endfunction
function! s:choice_ZFVimCmdMenu(title, hints)
    let index = 0
    for item in a:hints
        call ZF_VimCmdMenuAdd({
                    \   'showKeyHint' : 1,
                    \   'text' : item,
                    \   '_itemIndex' : index,
                    \ })
        let index += 1
    endfor
    let choice = ZF_VimCmdMenuShow({
                \   'headerText' : a:title,
                \ })
    redraw
    return get(choice, '_itemIndex', -1)
endfunction
function! s:choice(title, hints)
    if exists('*ZF_VimCmdMenuShow')
        return s:choice_ZFVimCmdMenu(a:title, a:hints)
    else
        return s:choice_default(a:title, a:hints)
    endif
endfunction

" params: {
"   'key' : 'key pattern to search',
"   'slug' : 'doc slug pattern to search',
"   'autoDownload' : '1/0, whether auto download if missing',
"   'autoChooseSlug' : '0/1, when more than one doc slug match, whether auto choose first',
"   'autoChooseIndex' : '0/1, when more than one doc index match, whether auto choose first',
"   'findOnly' : '0/1, when on, only find doc, do not open doc',
" }
" return empty if not exist, or: {
"   'slug' : 'matched doc slug',
"   'name' : 'matched index name',
"   'path' : 'matched index path',
"   'docHtml' : 'doc html string',
" }
function! s:ZFDocs(params)
    let slugToFind = a:params['slug']
    let slugMapped = get(get(g:, 'ZFDocs_slugMap', {}), slugToFind, '')
    if !empty(slugMapped)
        let slugToFind = slugMapped
    endif

    let docList = s:loadDocList(a:params)
    let slugList = s:findSlug(docList, slugToFind)
    if empty(slugList)
        throw printf('no doc slug found: %s', slugToFind)
    endif
    if len(slugList) > 1
                \ && slugList[0] != slugToFind
                \ && !get(a:params, 'autoChooseSlug', get(g:, 'ZFDocs_autoChooseSlug', 0))
        let choice = s:choice('choose doc slug to search:', slugList)
        if choice < 0
            redraw
            echo 'canceled'
            return {}
        endif
        let slug = slugList[choice]
    else
        let slug = slugList[0]
    endif

    let docIndex = s:loadDocIndex(a:params, slug)
    let docDb = s:loadDocDb(a:params, slug)

    let indexDataList = s:findIndex(docIndex, a:params['key'])
    if empty(indexDataList)
        throw printf('no doc found for key: %s, slug: %s', a:params['key'], slug)
    endif
    if len(indexDataList) > 1
                \ && indexDataList[0]['name'] != a:params['key']
                \ && !get(a:params, 'autoChooseIndex', get(g:, 'ZFDocs_autoChooseIndex', 0))
        let hints = []
        for item in indexDataList
            call add(hints, item['name'])
        endfor
        let choice = s:choice('choose doc to show:', hints)
        if choice < 0
            redraw
            echo 'canceled'
            return {}
        endif
        let indexData = indexDataList[choice]
    else
        let indexData = indexDataList[0]
    endif

    let docHtml = s:findDocHtml(slug, docDb, indexData)
    let result = {
                \   'slug' : slug,
                \   'name' : indexData['name'],
                \   'path' : indexData['path'],
                \   'docHtml' : docHtml,
                \ }
    if !get(a:params, 'findOnly', 0)
        call ZFDocs_open(result, a:params)
    endif
    redraw
    echo printf('[%s] %s', slug, indexData['name'])
    return result
endfunction

