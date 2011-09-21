(*
 * uTop_lexer.mll
 * --------------
 * Copyright : (c) 2011, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of utop.
 *)

(* Lexer for the OCaml language. *)

{
  open UTop_token
}

let uchar = ['\x00' - '\x7f'] | _ [ '\x80' - '\xbf' ]*

let blank = [' ' '\009' '\012']
let lowercase = ['a'-'z' '_']
let uppercase = ['A'-'Z']
let identchar = ['A'-'Z' 'a'-'z' '_' '\'' '0'-'9']
let ident = (lowercase|uppercase) identchar*
let locname = ident
let not_star_symbolchar =
  ['$' '!' '%' '&' '+' '-' '.' '/' ':' '<' '=' '>' '?' '@' '^' '|' '~' '\\']
let symbolchar = '*' | not_star_symbolchar
let quotchar =
  ['!' '%' '&' '+' '-' '.' '/' ':' '=' '?' '@' '^' '|' '~' '\\' '*']
let hexa_char = ['0'-'9' 'A'-'F' 'a'-'f']
let decimal_literal =
  ['0'-'9'] ['0'-'9' '_']*
let hex_literal =
  '0' ['x' 'X'] hexa_char ['0'-'9' 'A'-'F' 'a'-'f' '_']*
let oct_literal =
  '0' ['o' 'O'] ['0'-'7'] ['0'-'7' '_']*
let bin_literal =
  '0' ['b' 'B'] ['0'-'1'] ['0'-'1' '_']*
let int_literal =
  decimal_literal | hex_literal | oct_literal | bin_literal
let float_literal =
  ['0'-'9'] ['0'-'9' '_']*
  ('.' ['0'-'9' '_']* )?
  (['e' 'E'] ['+' '-']? ['0'-'9'] ['0'-'9' '_']*)?

let safe_delimchars = ['%' '&' '/' '@' '^']

let delimchars = safe_delimchars | ['|' '<' '>' ':' '=' '.']

let left_delims  = ['(' '[' '{']
let right_delims = [')' ']' '}']

let left_delimitor =
  left_delims delimchars* safe_delimchars (delimchars|left_delims)*
  | '(' (['|' ':'] delimchars*)?
  | '[' ['|' ':']?
  | ['[' '{'] delimchars* '<'
  | '{' (['|' ':'] delimchars*)?

let right_delimitor =
  (delimchars|right_delims)* safe_delimchars (delimchars|right_delims)* right_delims
  | (delimchars* ['|' ':'])? ')'
  | ['|' ':']? ']'
  | '>' delimchars* [']' '}']
  | (delimchars* ['|' ':'])? '}'

rule token = parse
  | ('\n' | blank)+
      { Blanks }
  | "true"
      { Constant }
  | "false"
      { Constant }
  | lowercase identchar*
      { Lident }
  | uppercase identchar*
      { Uident }
  | int_literal "l"
      { Constant }
  | int_literal "L"
      { Constant }
  | int_literal "n"
      { Constant }
  | int_literal
      { Constant }
  | float_literal
      { Constant }
  | '"'
      { String (string lexbuf) }
  | "'" [^'\'' '\\'] "'"
      { Char }
  | "'\\" ['\\' '"' 'n' 't' 'b' 'r' ' ' '\'' 'x' '0'-'9'] eof
      { Char }
  | "'\\" ['\\' '"' 'n' 't' 'b' 'r' ' ' '\''] "'"
      { Char }
  | "'\\" (['0'-'9'] ['0'-'9'] | 'x' hexa_char) eof
      { Char }
  | "'\\" (['0'-'9'] ['0'-'9'] ['0'-'9'] | 'x' hexa_char hexa_char) eof
      { Char }
  | "'\\" (['0'-'9'] ['0'-'9'] ['0'-'9'] | 'x' hexa_char hexa_char) "'"
      { Char }
  | "'\\" uchar
      { Error }
  | "(**"
      { Doc (comment 0 lexbuf) }
  | "(*"
      { Comment (comment 0 lexbuf) }
  | '<' (':' ident)? ('@' locname)? '<'
      { Quotation (quotation lexbuf) }
  | ( "#"  | "`"  | "'"  | ","  | "."  | ".." | ":"  | "::"
    | ":=" | ":>" | ";"  | ";;" | "_"
    | left_delimitor | right_delimitor )
      { Symbol }
  | ['~' '?' '!' '=' '<' '>' '|' '&' '@' '^' '+' '-' '*' '/' '%' '\\' '$'] symbolchar*
      { Symbol }
  | uchar
      { Error }
  | eof
      { raise End_of_file }

and comment depth = parse
  | "(*"
      { comment (depth + 1) lexbuf }
  | "*)"
      { if depth > 0 then comment (depth - 1) lexbuf else true }
  | uchar
      { comment depth lexbuf }
  | eof
      { false }

and string = parse
  | '"'
      { true }
  | "\\\""
      { string lexbuf }
  | uchar
      { string lexbuf }
  | eof
      { false }

and quotation = parse
  | ">>"
      { true }
  | uchar
      { quotation lexbuf }
  | eof
      { false }

{
  let lex_string str =
    let lexbuf = Lexing.from_string str in
    let rec loop idx ofs_a =
      match try Some (token lexbuf) with End_of_file -> None with
        | Some token ->
            let ofs_b = Lexing.lexeme_end lexbuf in
            let src = String.sub str ofs_a (ofs_b - ofs_a) in
            let idx' = idx + Zed_utf8.length src in
            (token, idx, idx', src) :: loop idx' ofs_b
        | None ->
            []
    in
    loop 0 0
}