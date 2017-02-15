xquery version "3.0";

import module namespace proj = "http://expath.org/ns/ml/console/project" at "proj-lib.xql";
import module namespace a    = "http://expath.org/ns/ml/console/admin"   at "../lib/admin.xql";
import module namespace v    = "http://expath.org/ns/ml/console/view"    at "../lib/view.xql";

import module namespace g = "http://expath.org/ns/ml/console/project/global" at "global-lib.xql";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace mlc  = "http://expath.org/ns/ml/console";
declare namespace xp   = "http://expath.org/ns/project";
declare namespace xdmp = "http://marklogic.com/xdmp";

declare function local:page() as element()+
{
   <p>The projects on this system:</p>,
   let $projects := proj:projects()
   return
      if ( fn:empty($projects) ) then
         <li><em>no project yet</em></li>
      else
         <table class="table table-bordered datatable" id="prof-detail">
            <thead>
               <th>Name</th>
               <th>Title</th>
               <th>Type</th>
               <th>Info</th>
            </thead>
            <tbody> {
               for $proj in $projects
               let $id   := xs:string($proj/@id)
               return
                  <tr>
                     <td>{ v:proj-link('project/' || $id, $id) }</td>
                     <td>{ g:title($proj) }</td>
                     <td>{ xs:string($proj/@type) }</td>
                     <td>{ g:info($proj) }</td>
                  </tr>
            }
            </tbody>
         </table>,
   <p>Projects let you handle applications and libraries source files.  For now, they allow you
      to browse project XQuery and JavaScript source files, and display their documentation.
      The documentation must be embedded in the source files as xqDoc comments in XQuery, and
      as the equivalent in JavaScript (only using <code>/*~ ... */</code> instead of
      <code>(:~ ... :)</code>.)</p>,
   <p>The Console supports 3 types of projects:</p>,
   <ul>
      <li><b><a href="http://expath.org/modules/xproject/">XProject</a></b> - on the filesystem,
         must conform to some conventions (conventions are enforced by the Console, to some
         extent)</li>
      <li><b>source directories</b> - plug to existing source files directories on the
         filesystem</li>
      <li><b>database directories</b> - plug to source files directories on a database (ideal for
         inspecting code of an installed application)</li>
   </ul>,
   <p>The forms below let you create new projects in the Console.</p>,

   <h3>XProject</h3>,
   <p>XProject is a simple project structure for XQuery- and XSLT-based projects.  It is based on
      simple conventions, like a directory <code>src/</code>, a directory <code>xproject/</code>,
      and a project descriptor in <code>xproject/project.xml</code>.  You can find everything
      about XProject on <a href="http://expath.org/modules/xproject/">this page</a>.  You can
      either plug to an existing project (use "add"), or create a brand-new one (use "create").</p>,
   <p>Add an existing XProject project from the filesystem:</p>,
   v:form('project/_/add-xproject', (
      v:input-text('id',  'ID',        'The ID of the project (default to the project abbrev)'),
      v:input-text('dir', 'Directory', 'Absolute path to the project directory'),
      v:submit('Add'))),
   <p>Create a new XProject project on the filesystem:</p>,
   v:form('project/_/create-xproject', (
      v:input-text('id',      'ID',        'The ID of the project (default to the project abbrev)'),
      v:input-text('dir',     'Directory', 'Absolute path where to create the project directory'),
      v:input-text('name',    'Name',      'Project full name (a unique URI)'),
      v:input-text('abbrev',  'Abbrev',    'Project abbreviation'),
      v:input-text('version', 'Version',   'Version number (using SemVer)'),
      v:input-text('title',   'Title',     'Project title'),
      v:submit('Create'))),
(:
   <p>Add an XProject descriptor to an existing project on the filesystem (the directory must
      contain an <code>src/</code> subdirectory):</p>,
   v:form('project/_/init-xproject', (
      v:input-text('id',      'ID',        'The ID of the project (default to the project abbrev)'),
      v:input-text('dir',     'Directory', 'Absolute path where to create the project directory'),
      v:input-text('name',    'Name',      'Project full name (a unique URI)'),
      v:input-text('abbrev',  'Abbrev',    'Project abbreviation'),
      v:input-text('version', 'Version',   'Version number (using SemVer)'),
      v:input-text('title',   'Title',     'Project title'),
      v:submit('Init'))),
:)

   <h3>Source directories</h3>,
   <p>The projects based on XProject are fully supported in the Console.  But if you projects
      are not following the same conventions, you can still add their source directories here.
      This will allow you to use simplest features, like browsing and displaying their XQDoc
      comments.</p>,
   <p>Add an existing source directory from the filesystem:</p>,
   v:form('project/_/add-srcdir', (
      v:input-text('id',    'ID',        'The ID of the project'),
      v:input-text('dir',   'Directory', 'Absolute path to the source directory'),
      v:input-text('title', 'Title',     'Project title'),
      v:submit('Add'))),

   <h3>DB directories</h3>,
   <p>Modules stored in a database (like a database used as the module database for an appserver)
      can be browsed the same way <code>Source directories</code> allows to browse modules on a
      file system.</p>,
   <p>Add a directory from an existing database:</p>,
   v:form('project/_/add-dbdir', (
      v:input-select-databases('database', 'Database'),
      v:input-text('id',    'ID',    'The ID of the project'),
      v:input-text('root',  'Root',  'Absolute path to the source directory (optional)'),
      v:input-text('title', 'Title', 'Project title'),
      v:submit('Add')))
};

v:console-page('./', 'project', 'Projects', local:page#0)
