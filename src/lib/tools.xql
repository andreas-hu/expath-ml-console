xquery version "3.0";

module namespace t = "http://expath.org/ns/ml/console/tools";

declare namespace c    = "http://expath.org/ns/ml/console";
declare namespace xdmp = "http://marklogic.com/xdmp";

(: ==== Simple tools ======================================================== :)

(:~
 : If $pred is true, return $content, if not, return the empty sequence.
 :)
declare function t:cond($pred as xs:boolean, $content as item()*)
   as item()*
{
   if ( $pred ) then
      $content
   else
      ()
};

(:~
 : Ignore its parameter and always return the empty sequence.
 :)
declare function t:ignore($seq as item()*)
   as empty-sequence()
{
   ()
};

(: ==== Error handling ======================================================== :)

(:~
 : TODO: Return an HTTP error instead... (or rather create a proper error handler?)
 :)
declare function t:error($code as xs:string, $msg as xs:string)
   as empty-sequence()
{
   fn:error(
      fn:QName('http://expath.org/ns/ml/console', 'c:' || $code),
      $msg)
};

(:~
 : TODO: Return an HTTP error instead... (or rather create a proper error handler?)
 :)
declare function t:error($code as xs:string, $msg as xs:string, $info as item()*)
   as empty-sequence()
{
   fn:error(
      fn:QName('http://expath.org/ns/ml/console', 'c:' || $code),
      $msg,
      $info)
};

(: ==== HTTP request fields ======================================================== :)

(:~
 : Return a request field, or a default value if it has not been passed.
 :)
declare function t:optional-field($name as xs:string, $default as item()?)
   as item()?
{
   ( xdmp:get-request-field($name), $default )[1]
};

(:~
 : Return a request field, or throw an error if it has not been passed.
 :)
declare function t:mandatory-field($name as xs:string)
   as item()
{
   let $f := xdmp:get-request-field($name)
   return
      if ( fn:exists($f) ) then
         $f
      else
         t:error('TOOLS001', 'Mandatory field not passed: ' || $name)
};

(:~
 : Return a request field filename, or a default value if it has not been passed.
 :)
declare function t:optional-field-filename($name as xs:string, $default as item()?)
   as item()
{
   ( xdmp:get-request-field-filename($name), $default )[1]
};

(:~
 : Return a request field filename, or throw an error if it has not been passed.
 :)
declare function t:mandatory-field-filename($name as xs:string)
   as item()
{
   let $f := xdmp:get-request-field-filename($name)
   return
      if ( fn:exists($f) ) then
         $f
      else
         t:error('TOOLS001', 'Mandatory field filename not passed: ' || $name)
};

(:~
 : Return a request field content-type, or a default value if it has not been passed.
 :)
declare function t:optional-field-content-type($name as xs:string, $default as item()?)
   as item()
{
   ( xdmp:get-request-field-content-type($name), $default )[1]
};

(:~
 : Return a request field content-type, or throw an error if it has not been passed.
 :)
declare function t:mandatory-field-content-type($name as xs:string)
   as item()
{
   let $f := xdmp:get-request-field-content-type($name)
   return
      if ( fn:exists($f) ) then
         $f
      else
         t:error('TOOLS001', 'Mandatory field content-type not passed: ' || $name)
};

(: ==== XML tools ======================================================== :)

(:~
 : Add an element as last child of a parent element. Return the modified parent.
 :)
declare function t:add-last-child($parent as element(), $new-child as element())
   as node()
{
   element { fn:node-name($parent) } {
      $parent/@*,
      $parent/node(),
      $new-child
   }
};

(:~
 : Remove an element from its parent element. Return the modified parent.
 :
 : Throw 'c:child-not-exist' if $child is not a child of $parent.
 :)
declare function t:remove-child($parent as element(), $child as element())
   as node()
{
   if ( fn:empty($parent/*[. is $child]) ) then
      t:error(
         'child-not-exist',
         'The child ' || fn:name($child) || ' does not exist in ' || fn:name($parent))
   else
      element { fn:node-name($parent) } {
         $parent/@*,
         $parent/node() except $child
      }
};

(: ==== String tools ======================================================== :)

(:~
 : Build a string by repeating `$str`, `$n` times.
 :)
declare function t:make-string($str as xs:string, $n as xs:integer)
   as xs:string?
{
   if ( $n gt 0 ) then
      $str || t:make-string($str, $n - 1)
   else
      ()
};

(: ==== File and URI tools ======================================================== :)

(:~
 : Given a path, strip the last component unless it ends with a slash.
 :)
declare function t:dirname($path as xs:string)
   as xs:string
{
   fn:replace($path, '/[^/]+$', '/')
};

(:~
 : Ensure a directory exists on the filesystem (if not it is created).
 :)
declare function t:ensure-dir($dir as xs:string)
   as empty-sequence()
{
   (: TODO: This is an undocumented function. :)
   (: See http://markmail.org/thread/a4d6puu3n5dpmkkw :)
   (: It does not harm if dir already exists, but look at xdmp:filesystem-directory() to detect it... :)
   xdmp:filesystem-directory-create(
      $dir,
      <options xmlns="xdmp:filesystem-directory-create">
         <create-parents>true</create-parents>
      </options>)
};

(:~
 : Ensure `$file` is a relative path (does not start with a '/').
 :)
declare function t:ensure-relative($file as xs:string)
   as xs:string
{
   if ( fn:starts-with($file, '/') ) then
      fn:substring($file, 2)
   else
      $file
};

(: ==== HTTP Content-Type parsing ======================================================== :)

(:~
 : Parse a HTTP Content-Type value.
 :
 : $ctype must conform to RFC 2616 grammar for Content-Type.  The returned
 : element looks like the following:
 :
 : <!-- result of parsing "text/plain;charset=windows-1250" -->
 : <content-type type="text" subtype="plain">
 :    <param name="charset" value="windows-1250"/>
 : </content-type>
 : 
 : From https://tools.ietf.org/html/rfc2616#section-3.7:
 :
 : media-type     = type "/" subtype *( ";" parameter )
 : type           = token
 : subtype        = token
 :
 : The rule `parameter` is defined as `attribute "=" value`.  This function
 : allows space characters between ";", `attribute`, "=", and `value`, and
 : simply ignore them.
 :)
declare function t:parse-content-type($ctype as xs:string)
   as element(content-type)
{
   if ( fn:contains($ctype, '/') ) then
      <content-type type="{ fn:substring-before($ctype, '/') }"> {
         t:parse-content-type-1(
            fn:substring-after($ctype, '/'))
      }
      </content-type>
   else
      t:error('content-type-no-slash', 'invalid content-type, no slash: ' || $ctype)
};

(:~
 : Private helper for `t:parse-content-type()`.
 :)
declare %private function t:parse-content-type-1($input as xs:string)
   as node()+
{
   if ( fn:contains($input, ';') ) then (
      attribute { 'subtype' } { fn:substring-before($input, ';') },
      t:parse-content-type-2(
         fn:string-to-codepoints(
            fn:substring-after($input, ';')),
         (), (), 0)
   )
   else (
      attribute { 'subtype' } { $input }
   )
};

(:~
 : Private helper for `t:parse-content-type-1()`.
 :
 : # https://tools.ietf.org/html/rfc2616#section-3.6
 :
 : parameter               = attribute "=" value
 : attribute               = token
 : value                   = token | quoted-string
 :
 : # https://tools.ietf.org/html/rfc2616#section-2.2
 :
 : token          = 1*<any CHAR except CTLs or separators>
 : separators     = "(" | ")" | "<" | ">" | "@"
 :                | "," | ";" | ":" | "\" | <">
 :                | "/" | "[" | "]" | "?" | "="
 :                | "{" | "}" | SP | HT
 :
 : quoted-string  = ( <"> *(qdtext | quoted-pair ) <"> )
 : qdtext         = <any TEXT except <">>
 : quoted-pair    = "\" CHAR
 :
 : # Some char codes
 :
 : space=32
 : double quote=34
 : semi colon=59
 : equals=61
 : backslash=92
 :
 : # States (values for $state)
 :
 : 0: initial state, after a ';' has been seen, looking for a name
 : 1: scanning a name
 : 2: scanning a token
 : 3: scanning the content of a quoted string
 : 4: after the closing '"' of a quoted string
 : 5: after a '=' has been seen, looking for a value
 : 6: scanning spaces (before and after name, before and after value)
 :)
declare %private function t:parse-content-type-2(
   $input as xs:integer*,
   $name  as xs:integer*,
   $value as xs:integer*,
   $state as xs:integer
) as element(param)+
{
   let $head := fn:head($input)
   let $tail := fn:tail($input)
   return
      if ( fn:empty($input) ) then (
         t:parse-content-type-3($name, $value, $state)
      )
      else if ( $head eq 32 and $state = (0, 5, 6) ) then (
         t:parse-content-type-2($tail, $name, $value, $state)
      )
      else if ( $head eq 32 and $state = (1, 2, 4) ) then (
         t:parse-content-type-2($tail, $name, $value, 6)
      )
      else if ( $state eq 6 ) then (
         t:error('content-type-invalid-char', 'invalid char whilst consuming spaces: ' || $head)
      )
      else if ( $head eq 61 and $state ne 3 ) then (
         if ( fn:empty($name) ) then
            t:error('content-type-empty-name', 'empty name when encountering equals: ' || $state)
         else
            t:parse-content-type-2($tail, $name, $value, 5)
      )
      else if ( $head eq 59 and $state ne 3 ) then (
            t:parse-content-type-3($name, $value, $state),
            t:parse-content-type-2($tail, (), (), 1)
      )
      else if ( $state eq 4 ) then (
         t:error('content-type-invalid-char', 'invalid char after quoted string ended: ' || $head)
      )
      else if ( $state = (0, 1) ) then (
         t:parse-content-type-2($tail, ($name, $head), $value, 1)
      )
      else if ( $state eq 5 and $head eq 34 ) then (
         t:parse-content-type-2($tail, $name, $value, 3)
      )
      else if ( $state eq 5 ) then (
         t:parse-content-type-2($tail, $name, ($value, $head), 2)
      )
      else if ( $state eq 3 and $head eq 92 ) then (
         t:parse-content-type-2(fn:tail($tail), $name, ($value, $input[2]), $state)
      )
      else if ( $state eq 3 and $head eq 34 ) then (
         t:parse-content-type-2($tail, $name, $value, 4)
      )
      else if ( $head eq 34 ) then (
         t:error('content-type-invalid-char', 'double quote in invalid state: ' || $state)
      )
      else (
         t:parse-content-type-2($tail, $name, ($value, $head), $state)
      )
};

(:~
 : Private helper for `t:parse-content-type-2()`.
 :)
declare %private function t:parse-content-type-3(
   $name  as xs:integer*,
   $value as xs:integer*,
   $state as xs:integer
) as element(param)
{
   if ( $state = (2, 4) ) then
      <param name="{ fn:codepoints-to-string($name) }" value="{ fn:codepoints-to-string($value) }"/>
   else
      t:error('content-type-invalid-state', 'invalid state when semi-colon or <eof>: ' || $state)
};
