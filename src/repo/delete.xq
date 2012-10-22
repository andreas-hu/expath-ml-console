xquery version "1.0";

import module namespace v   = "http://expath.org/ns/ml/console/view"   at "lib/view.xql";
import module namespace t   = "http://expath.org/ns/ml/console/tools"  at "lib/tools.xql";
import module namespace a   = "http://expath.org/ns/ml/console/admin"  at "lib/admin.xql";
import module namespace cfg = "http://expath.org/ns/ml/console/config" at "lib/config.xql";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace h    = "http://www.w3.org/1999/xhtml";
declare namespace xdmp = "http://marklogic.com/xdmp";

(:
 : TODO: Maintain a list of deleted repositories (but the content of which has
 : not been removed, either on DB or FS), in order to keep track of them for
 : the user...?  There sould then be a way for the user to ask to forget about
 : one specific such reminder...
 :)

(: TODO: Check the parameter has been passed, to avoid XQuery errors! :)
(: (turn it into a human-friendly error instead...) :)
(: And validate it! (does the repo exist?) :)
let $repo   := t:mandatory-field('repo')
let $remove := xs:boolean(t:optional-field('remove', 'false'))
return
   v:console-page(
      'setup',
      'Setup',
      if ( cfg:forget-repo($repo, $remove) ) then
         <p>The repository '{ $repo }' has been successfully deleted.</p>
      else
         (: TODO: Make the distinction between both cases, so we can display the
            correct error message. :)
         <p><b>Error</b>: Cannot delete the repository '{ $repo }': either there
            is no such repository, or you asked to completely remove the content
            of a repository stored on the filesystem (this is not supported, you
            have to simply remove the repo then delete the corresponding
            directory by hand).</p>)