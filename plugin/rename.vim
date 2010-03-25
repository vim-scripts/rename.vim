" rename.vim: functions to rename files and C symbols under the cursor.
" (Heavily inspired from renamec.vim)
"
" @maintainer       : <chm.duquesne@gmail.com>
" @license          : GPL (see http://www.gnu.org/licenses/gpl.txt)
" @last modified    : 2010-03-21
" @todo             : find a way to allow the user to undo changes (using
"                     diff and patch?)
"
" @Features:
" :call Renamec(): renames the symbol under the cursor
" :call Renamef(): renames the file under the cursor and updates references
" to this file (like includes directives) in the given files
"
" Comparison with renamec:
" bugs fixed
" - the regular expression now matches entire words and is less likely to
"   provoke errors.
" - when used presses escape, the action is aborted.
" features added:
" - can now rename files
" - puts the renamed lines in the quickfix list (to check the changes and
"   update the commentaries)
"

function! Renamec()

    " catch incompatible options
    if &hidden == 0
        echoerr "You need hidden to be set for renaming to work"
        return
    endif
    if &autowrite == 1
        echoerr "You need autowrite to be unset for renaming to work"
        return
    endif

    " save current position
    let save_buffer = bufnr("%")
    let save_cursor = getpos(".")

    " get the word to replace
    let word_to_rename = expand("<cword>")

    " get the new_name, abort the function if nothing was provided
    let new_name = input("new name: ", word_to_rename)
    if new_name == ""
        return
    endif

    " get the places to modify
    let places_to_modify_raw = system("cscope -L -d -F cscope.out -0 " . word_to_rename)
    let places_to_modify = split(places_to_modify_raw,'\n')

    for place_raw in places_to_modify

        " get the file and line to modify
        let place = split(place_raw,' ')
        let file = place[0]
        let line = place[2]

        " reach the file where to proceed the replacement
        let subs_buffer = bufnr(file)
        if subs_buffer == -1
            exe "edit ".file
            let subs_buffer = bufnr(file)
        endif
        exe "buffer " . subs_buffer

        let subs_command = line . "," . line
        let subs_command = subs_command . "smagic/\\C\\<" . word_to_rename . "\\>"
        let subs_command = subs_command . "/" . new_name . "/g"

        " applies the replacement
        try
            " try to join replacements (to cancel them in one shot)
            undojoin
            " try to proceed replacement
            exe subs_command
            " feed the quickfix list
            caddexpr file . ":" . line . ": changed " . word_to_rename . "to" . new_name
        catch " catch everything
            " do not throw errors (they come from duplicate entries)
        endtry
    endfor

    " restore position
    exe "buffer " . save_buffer
    call setpos('.', save_cursor)
    echo "******************************************************"
    echo "Word renamed everywhere!"
    echo ":bufdo undo -- to cancel the changes"
    echo ":wall       -- to write all buffers"
    echo ":copen      -- to see the changes in the quickfix list"

endfunction



function! Renamef()
    " catch incompatible options
    if &hidden == 0
        echoerr "You need hidden to be set for renaming to work"
        return
    endif
    if &autowrite == 1
        echoerr "You need autowrite to be unset for renaming to work"
        return
    endif

    " save current position
    let save_buffer = bufnr("%")
    let save_cursor = getpos(".")

    " gets the reference to rename
    let word_to_rename = expand("<cfile>")

    let new_name = input("new file name: ", word_to_rename)
    " abort action if nothing was provided
    if new_name == ""
        return
    endif

    let on_files = input("replace refs in files: ", "**/*.cpp")
    " abort action if nothing was provided
    if on_files == ""
        return
    endif

    exec "vimgrep! '" . word_to_rename . "' " . on_files

    for place in getqflist()
        let file = bufname(place.bufnr)
        let line = place.lnum

        " reach the file where to proceed the replacement
        let subs_buffer = place.bufnr
        if subs_buffer == -1
            exe "edit ".file
            let subs_buffer = bufnr(file)
        endif
        exe "buffer " . subs_buffer

        let subs_command = line . "," . line
        let subs_command = subs_command . "smagic~\\C\\<" . word_to_rename . "\\>"
        let subs_command = subs_command . "~" . new_name . "~g"

        " applies the replacement
        try
            " try to join replacements (to cancel them in one shot)
            undojoin
            " try to proceed replacement
            exe subs_command
        catch " catch everything
            " do not throw errors (they come from duplicate entries)
        endtry
    endfor

    " restore position
    exe "buffer " . save_buffer
    call setpos('.', save_cursor)

    " saves the file as the new name, but do not remove the former one
    silent execute "!cp " . word_to_rename . " " . new_name

    echo "******************************************************"
    echo "Word renamed everywhere!"
    echo ":bufdo undo -- to cancel the changes"
    echo ":wall       -- to write all buffers"
    echo ":copen      -- to see the changes in the quickfix list"

endfunction

