" multiline_lambda.vim - Extract multiline lambda to function definition
" Place this file in ~/.vim/plugin/ or source it in your .vimrc

function! ExtractMultilineLambda()
    " Save current position
    let l:original_line = line('.')
    let l:original_col = col('.')
    
    " Get the current line
    let l:current_line = getline('.')
    
    " Check if current line contains 'lamdef'
    if l:current_line !~ 'lamdef'
        echohl ErrorMsg
        echo "No 'lamdef' found on current line"
        echohl None
        return
    endif
    
    " Extract the base indentation of the current line
    let l:base_indent = matchstr(l:current_line, '^\s*')
    let l:indent_size = len(l:base_indent)
    
    " Extract parameter from lamdef
    let l:param_match = matchstr(l:current_line, 'lamdef\s*(\s*\zs[^)]*\ze\s*)')
    if empty(l:param_match)
        echohl ErrorMsg
        echo "Could not parse lamdef parameters"
        echohl None
        return
    endif
    
    " Determine the function name and whether we need closing paren
    " Case 1: Direct assignment (f = lamdef(x):)
    let l:direct_assign = matchstr(l:current_line, '^\s*\zs\w\+\ze\s*=\s*lamdef')
    
    " Case 2: Inside function call (filter(lamdef(x):, ...))
    let l:has_open_paren_before = l:current_line =~ '(\s*lamdef'
    
    " Extract variable name for function naming
    let l:var_name = matchstr(l:current_line, '^\s*\zs\w\+\ze\s*=')
    if empty(l:var_name)
        let l:var_name = 'result'
    endif
    
    " Determine function name and closing paren logic
    if !empty(l:direct_assign)
        " Direct assignment: use the variable name as function name
        let l:func_name = l:direct_assign
        let l:new_call_line = l:base_indent . l:direct_assign . ' = ' . l:func_name
        let l:needs_closing_paren = 0
    else
        " Generate function name based on variable
        if l:var_name =~ '^sorted_'
            let l:func_name = '_key_for_' . substitute(l:var_name, '^sorted_', '', '')
        elseif l:var_name =~ 's$'
            let l:func_name = '_' . substitute(l:var_name, 's$', '', '') . '_key'
        else
            let l:func_name = '_' . l:var_name . '_key'
        endif
        
        " Build new call line
        let l:before_lamdef = matchstr(l:current_line, '^.\{-}\ze\s*lamdef')
        let l:new_call_line = l:before_lamdef . l:func_name
        
        " If lamdef is inside a function call, don't add closing paren
        if l:has_open_paren_before
            let l:needs_closing_paren = 0
        else
            let l:needs_closing_paren = 1
        endif
    endif
    
    " Find the end of the lamdef block
    let l:start_line = l:original_line
    let l:end_line = l:start_line
    
    " Determine the lamdef body indentation
    if l:start_line + 1 > line('$')
        echohl ErrorMsg
        echo "No lambda body found"
        echohl None
        return
    endif
    
    let l:body_line = getline(l:start_line + 1)
    let l:body_indent = matchstr(l:body_line, '^\s*')
    let l:body_indent_size = len(l:body_indent)
    
    " Find all lines that belong to the lambda body
    let l:next_line = l:start_line + 1
    while l:next_line <= line('$')
        let l:check_line = getline(l:next_line)
        let l:check_indent = matchstr(l:check_line, '^\s*')
        let l:check_indent_size = len(l:check_indent)
        
        " Empty lines are part of the block
        if l:check_line =~ '^\s*$'
            let l:end_line = l:next_line
            let l:next_line += 1
            continue
        endif
        
        " If indentation is greater than base, it's part of the lambda
        if l:check_indent_size > l:indent_size
            let l:end_line = l:next_line
            let l:next_line += 1
        else
            break
        endif
    endwhile
    
    " Look for closing parenthesis on the next line after lambda body
    let l:closing_paren_line = 0
    let l:closing_paren_content = ''
    if l:end_line + 1 <= line('$')
        let l:potential_closing = getline(l:end_line + 1)
        let l:potential_indent = matchstr(l:potential_closing, '^\s*')
        let l:potential_indent_size = len(l:potential_indent)
        
        " Check if it's a closing paren at the same indentation as the lamdef line
        if l:potential_indent_size == l:indent_size && l:potential_closing =~ '^\s*)'
            let l:closing_paren_line = l:end_line + 1
            let l:closing_paren_content = l:potential_closing
        endif
    endif
    
    " Extract lambda body lines
    let l:body_lines = []
    for l:line_num in range(l:start_line + 1, l:end_line)
        let l:line_content = getline(l:line_num)
        " Remove the extra indentation (keep relative indentation)
        if l:line_content =~ '^\s*$'
            call add(l:body_lines, '')
        else
            let l:line_indent_size = len(matchstr(l:line_content, '^\s*'))
            let l:relative_indent = l:line_indent_size - l:body_indent_size
            let l:new_indent = repeat(' ', l:indent_size + 4 + l:relative_indent)
            let l:stripped = substitute(l:line_content, '^\s*', '', '')
            call add(l:body_lines, l:new_indent . l:stripped)
        endif
    endfor
    
    " Create the function definition
    let l:func_def = []
    call add(l:func_def, l:base_indent . 'def ' . l:func_name . '(' . l:param_match . '):')
    call extend(l:func_def, l:body_lines)
    
    " Add closing parenthesis if found on separate line
    if l:closing_paren_line > 0
        let l:new_call_line = l:new_call_line . trim(l:closing_paren_content)
    elseif l:needs_closing_paren
        " Only add closing paren if it's not inside a function call
        let l:new_call_line = l:new_call_line . ')'
    endif
    
    " Calculate how many lines to delete
    let l:lines_to_delete = l:end_line - l:start_line + 1
    if l:closing_paren_line > 0
        let l:lines_to_delete = l:closing_paren_line - l:start_line + 1
    endif
    
    " Delete the original lamdef block
    execute l:start_line . ',' . (l:start_line + l:lines_to_delete - 1) . 'delete'
    
    " Insert function definition and new call line above
    let l:all_lines = l:func_def + [l:new_call_line]
    call append(l:start_line - 1, l:all_lines)
    
    " Move cursor to the new call line
    let l:new_call_line_num = l:start_line + len(l:func_def)
    call cursor(l:new_call_line_num, l:original_col)
    
    echohl MoreMsg
    echo "Lambda extracted to function: " . l:func_name
    echohl None
endfunction

" Map Ctrl+E to extract multiline lambda
nnoremap <C-e> :call ExtractMultilineLambda()<CR>

" Optional: Add a command for manual invocation
command! ExtractLambda call ExtractMultilineLambda()
