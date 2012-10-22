xquery version "1.0";

import module namespace cfg = "http://expath.org/ns/ml/console/config" at "lib/config.xql";
import module namespace r   = "http://expath.org/ns/ml/console/repo"   at "lib/repo.xql";
import module namespace t   = "http://expath.org/ns/ml/console/tools"  at "lib/tools.xql";
import module namespace v   = "http://expath.org/ns/ml/console/view"   at "lib/view.xql";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace c    = "http://expath.org/ns/ml/console";
declare namespace http = "xdmp:http";
declare namespace xdmp = "http://marklogic.com/xdmp";
declare namespace zip  = "xdmp:zip";

declare function local:install(
   $repo as element(c:repo),
   $uri  as xs:string
) as element()+
{
   let $result   := xdmp:http-get($uri)
   let $response := $result[1]
   let $xar      := $result[2]
   let $code     := $response/xs:integer(http:code)
   return
      if ( $code eq 404 ) then
         <p><b>Error</b>: There is no package at { $uri }..</p>
      else if ( $code eq 200 ) then
         if ( r:install($xar, $repo) ) then
            <p>Package succesfully installed from { $uri } into { $repo/fn:string(@name) }.</p>
         else
            <p><b>Error</b>: Unknown error installing the package from { $uri }.
               Does it already exist?</p>
      else (
         <p><b>Error</b>: CXAN server did not respond 200 Ok for the package
            (at '{ $uri }'):</p>,
         <pre>{ xdmp:quote($response) }</pre>
      )
};

declare function local:do-it(
   $repo    as element(c:repo),
   $id      as xs:string?,
   $name    as xs:string?,
   $version as xs:string?,
   $site    as xs:string?
) as element()+
{
   if ( fn:exists($id) and fn:exists($name) ) then
      <p><b>Error</b>: Both CXAN ID and package name provided: resp. '{ $id }'
         and '{ $name }'.</p>
   else if ( fn:empty($site) ) then
      <p><b>Error</b>: The console seems to have not been set up yet, please
         <a href="setup.xq">create a repo</a> first.</p>
   else if ( fn:exists($id) ) then
      local:install($repo, fn:concat($site, 'file?id=', $id, '&amp;version=', $version))
   else if ( fn:exists($name) ) then
      local:install($repo, fn:concat($site, 'file?name=', $name, '&amp;version=', $version))
   else
      <p><b>Error</b>: No CXAN ID nor package name provided.</p>
};

(: TODO: Check the params are there, and validate them... :)
let $reponame := t:mandatory-field('repo')
let $repo     := cfg:get-repo($reponame)
let $id       := t:optional-field('id', ())
let $name     := t:optional-field('name', ())
let $version  := t:optional-field('version', ())
let $site     := cfg:get-config()/c:cxan/c:site
return
   v:console-page(
      'cxan',
      'CXAN',
      local:do-it($repo, $id, $name, $version, $site))