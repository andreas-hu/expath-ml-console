xquery version "3.0";

import module namespace a = "http://expath.org/ns/ml/console/admin" at "../lib/admin.xql";
import module namespace t = "http://expath.org/ns/ml/console/tools" at "../lib/tools.xql";
import module namespace v = "http://expath.org/ns/ml/console/view"  at "../lib/view.xql";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace c   = "http://expath.org/ns/ml/console";
declare namespace err = "http://www.w3.org/2005/xqt-errors";

declare function local:page()
   as element()+
{
   (: the app server :)
   let $id-str  := t:mandatory-field('id')
   let $id      := xs:unsignedLong($id-str)
   let $as      := a:get-appserver($id)
   (: the package :)
   let $pkgdir  := t:mandatory-field('pkg')
   let $pkg     := a:appserver-get-package-by-pkgdir($pkgdir, $as)
   (: confirmed? :)
   let $confirm := t:optional-field('confirm', 'false')
   return (
      (: TODO: In those first few cases, we should NOT return "200 OK". :)
      if ( fn:empty($as) ) then
         <p><b>Error</b>: The app server "<code>{ $id-str }</code>" does not exist.</p>
      else if ( fn:empty($pkg) ) then
         <p><b>Error</b>: The package with directory "<code>{ $pkgdir }</code>" does not exist.</p>
      else if ( fn:not($confirm castable as xs:boolean) ) then
         <p><b>Error</b>: The parameter "<code>confirm</code>" is not a valid boolean:
            "<code>{ $confirm }</code>".</p>
      else
         try {
            a:appserver-delete-package($as, $pkg, xs:boolean($confirm)),
            <p>The package "<code>{ $pkg/xs:string(@dir) }</code>" has been deleted.</p>
         }
         catch c:not-confirmed {
            <p>{ $err:description }</p>,
            <form method="post" action="delete" enctype="multipart/form-data">
               <input type="hidden" name="confirm" value="true"/>
               <input type="submit" value="Confirm"/>
               <a href="../../../{ $as/@id }">Cancel</a>
            </form>
         }
      ,
      <p>Back to the app server <a href="../../../{ $as/@id }">{ $as/xs:string(a:name) }</a>.</p>
   )
};

v:console-page('../../../../', 'pkg', 'Delete package', local:page#0)
