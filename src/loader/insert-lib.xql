xquery version "3.0";

module namespace i = "http://expath.org/ns/ml/console/insert";

import module namespace a = "http://expath.org/ns/ml/console/admin"  at "../lib/admin.xql";
import module namespace b = "http://expath.org/ns/ml/console/binary" at "../lib/binary.xql";
import module namespace t = "http://expath.org/ns/ml/console/tools"  at "../lib/tools.xql";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace xdmp = "http://marklogic.com/xdmp";

(:~
 : Insert a document.
 :
 : Return the URI of the newly inserted document, or the empty sequence if a
 : document already exists for that URI and `$override` is false..
 :)
declare function i:handle-file(
   $db       as item(), (: element(a:database) | xs:unsidnedLong :)
   $content  as item(),
   $format   as xs:string,
   $uri      as xs:string,
   $prefix   as xs:string?,
   $override as xs:boolean
) as xs:string?
{
               
   let $prefix   := fn:string-join(fn:tokenize($prefix, '/') ! fn:encode-for-uri(.), '/')
   let $uri      := fn:string-join(fn:tokenize($uri, '/') ! fn:encode-for-uri(.), '/')
   let $doc-uri  :=
         if ( fn:starts-with($uri, '/') or fn:starts-with($uri, 'http://') ) then
            $uri
         else if ( fn:exists($prefix) ) then
            $prefix || '/'[fn:not(fn:ends-with($prefix, '/'))] || $uri
         else
            $uri
   return
      if ( fn:doc-available($doc-uri) and fn:not($override) ) then
         ()
      else
         a:insert-into-database($db, $doc-uri, i:get-node($content, $format))
};

(:~
 : Check the type of $file, accordingly to $format, and possibly transform it.
 :
 : If $format is 'text', $file must be a text node within a doc node, or it
 :   must be a binary node, in which case it is decoded (TODO: Still TBD.)
 : If $format is 'binary', $file must be a binary node.
 : If $format is 'xml', $file must be an element node within a doc node (which
 :   seems is never the case with MarkLogic), or it must be a text node within
 :   a doc node, in which case it is parsed. (TODO: What if it is binary?
 :   Probably decode it then parse it...)
 :)
declare function i:get-node($file as item(), $format as xs:string)
   as node()
{
   if ( $format eq 'text' ) then
      if ( $file instance of xs:string ) then
         text { $file }
      else if ( $file instance of document-node() and fn:exists($file/text()) ) then
         $file
      else if ( b:is-binary($file) ) then
         text { xdmp:binary-decode($file, 'utf-8') }
      else
         t:error('INSERT001', 'Text file is not a text node, please report this to the mailing list')
   else if ( $format eq 'binary' ) then
      if ( b:is-binary($file) ) then
         $file
      else
         t:error('INSERT002', 'Binary file is not a binary node, please report this to the mailing list')
   else if ( $format eq 'xml' ) then
      if ( $file instance of xs:string ) then
         xdmp:unquote($file)
      else if ( $file instance of document-node() and fn:exists($file/*) ) then
         $file
      else if ( $file instance of document-node() and fn:exists($file/text()) ) then
         xdmp:unquote($file)
      else if ( b:is-binary($file) ) then
         (: TODO: Decode the binary... :)
         t:error('INSERT102', 'XML file is a binary node, please report this to the mailing list')
      else
         t:error('INSERT003', 'XML file is neither parsed nor a document node with an element, '
            || 'please report this to the mailing list')
   else
      t:error('INSERT004', 'Format not known: "' || $format || '"')
};
