xquery version "3.0";

(:~
 : Project information retrieval and manipulation.
 :)
module namespace proj = "http://expath.org/ns/ml/console/project";

import module namespace a = "http://expath.org/ns/ml/console/admin" at "../lib/admin.xql";
import module namespace t = "http://expath.org/ns/ml/console/tools" at "../lib/tools.xql";

declare namespace mlc  = "http://expath.org/ns/ml/console";
declare namespace xdmp = "http://marklogic.com/xdmp";

(:~
 : The Console config file URI.
 : 
 : @todo Move to a Console-global library.
 :)
declare variable $proj:config-uri := 'http://expath.org/ml/console/config.xml';

(:~
 : Return true if the Console config file exists.
 : 
 : @todo Move to a Console-global library.
 :)
declare function proj:is-console-init()
   as xs:boolean
{
   fn:doc-available($proj:config-uri)
};

(:~
 : Create the Console config file.
 : 
 : @todo Move to a Console-global library.
 :
 : @todo Is it still used, shouldn't I delete them...?
 :)
declare function proj:init-console()
   as empty-sequence()
{
   if ( proj:is-console-init() ) then
      t:error('already-init', 'The config file already exists')
   else
      xdmp:document-insert(
         $proj:config-uri,
         <console xmlns="http://expath.org/ns/ml/console">
            <projects/>
         </console>)
};

(:~
 : The collection for project descriptors.
 :)
declare variable $proj:projects-coll := 'http://expath.org/ml/console/projects';

(:~
 : All project descriptors.
 : 
 : @return A sequence of project elements.
 :)
declare function proj:projects()
   as element(mlc:project)*
{
   fn:collection($proj:projects-coll)/mlc:project
};

(:~
 : The ID of all projects.
 : 
 : @return A sequence of IDs.
 :)
declare function proj:project-ids()
   as xs:string*
{
   proj:projects()/@id
};

(:~
 : The config of the project with `$id`.
 : 
 : @param id The ID of the project to return the config for.
 :)
declare function proj:project($id as xs:string)
   as element(mlc:project)?
{
   proj:projects()[@id eq $id]
};

(:~
 : Add a config for an existing project with `$id` and `$dir`.
 : 
 : @param id The ID of the project to add a new config for.
 : 
 : @param dir The directory of the existing project.  It must contain a sub-directory
 : `xproject`, itself containing a file `project.xml`.
 : 
 : @todo Make more checks (does the dir exist, etc.)
 : 
 : @todo Specific to XProject projects now, to generalize.
 :)
declare function proj:add-config($id as xs:string, $type as xs:string, $info as element()*)
   as empty-sequence()
{
   let $uri := 'http://expath.org/ml/console/project/' || $id || '.xml'
   return
      if ( fn:exists(proj:project($id)) ) then
         t:error('project-exists', 'There is already a project with the ID: ' || $id)
      else if ( fn:doc-available($uri) ) then
         t:error('inconsistent',
            'No project with the ID: ' || $id || ', but the project file exists at: ' || $uri)
      else
         xdmp:document-insert(
            $uri,
            <project id="{ $id }" type="{ $type }" xmlns="http://expath.org/ns/ml/console"> {
               $info
            }
            </project>,
            ( (:permissions:) ),
            $proj:projects-coll)
};

(:~
 : A key/value pair to be added to a project config file.
 : 
 : @param name The key, used to construct an element with that name.  Must be a valid NCName.
 : 
 : @param value The value, used as the text content of the new element.
 :)
declare function proj:config-key-value($name as xs:string, $value as xs:string)
   as element()
{
   element { fn:QName('http://expath.org/ns/ml/console', $name) } { $value }
};

declare function proj:directory($proj as element(mlc:project))
   as xs:string
{
   $proj/mlc:dir
};
