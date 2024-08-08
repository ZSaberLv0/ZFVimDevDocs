
# Intro

view devdocs.io docs inside vim

similar projects:

* [girishji/devdocs.vim](https://github.com/girishji/devdocs.vim)
* [rhysd/devdocs.vim](https://github.com/rhysd/devdocs.vim)

Pros:

* pure vim script, very low dependency, support both vim and neovim
* open inside vim, no external browser required

Cons:

* no async support

if you like my work, [check here](https://github.com/ZSaberLv0?utf8=%E2%9C%93&tab=repositories&q=ZFVim) for a list of my vim plugins,
or [buy me a coffee](https://github.com/ZSaberLv0/ZSaberLv0)


# Usage

1. requirements

    * `exists('*json_decode')`
    * have [w3m](https://github.com/acg/w3m) installed (or supply your own html viewer, see below)
    * have `curl` or `wget` available

1. use [Vundle](https://github.com/VundleVim/Vundle.vim) or any other plugin manager you like to install

    ```
    Plugin 'ZSaberLv0/ZFVimDevDocs'
    Plugin 'yuratomo/w3m.vim' " required for default html viewer impl
    Plugin 'ZSaberLv0/ZFVimCmdMenu' " optional, for a more convenient doc chooser menu
    ```

1. to use: (see [devdocs Preferences](https://devdocs.io/settings))

    * `:ZFDocs json_encode`

        try to search by current `&filetype` as doc set

    * `:ZFDocs json_encode php`

        try to search with specified doc set

1. necessary doc db would be downloaded when `:ZFDocs` called,
    which may cause much time to download,
    please be patient


# Configs

* `let g:ZFDocs_cachePath = $HOME . '/.vim_cache/zfdocs'` : where to store db cache file
* `let g:ZFDocs_docsUrl = 'https://devdocs.io/docs.json'` : where to download doc set meta data
* `let g:ZFDocs_docSlugIndexUrl = 'https://documents.devdocs.io/%s/index.json'` : where to download doc index data
* `let g:ZFDocs_docSlugDbUrl = 'https://documents.devdocs.io/%s/db.json'` : where to download doc index data
* `let g:ZFDocs_slugMap = {'cpp' : 'qt'}` : map from `&filetype` to devdocs's doc slug


# Advanced

## html viewer

by default, we use [yuratomo/w3m.vim](https://github.com/yuratomo/w3m.vim) to view html docs inside vim,
you may supply your own impl by supply this function:

```
" result: {
"   'slug' : 'matched doc slug',
"   'name' : 'matched index name',
"   'path' : 'matched index path',
"   'docHtml' : 'doc html string',
" }
" params: original params passed to ZFDocs()
function! ZFDocs_open(result, params)
    ...
endfunction
```

## doc downloader

by default, we use `curl` or `wget` to download docs,
you may supply your own impl by:

```
function! ZFDocs_download(to, url)
    ...
endfunction
```

