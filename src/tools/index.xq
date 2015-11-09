xquery version "3.0";

(:~
 : Aimed at providing general tools for MarkLogic.
 :)

import module namespace a = "http://expath.org/ns/ml/console/admin" at "../lib/admin.xql";
import module namespace v = "http://expath.org/ns/ml/console/view"  at "../lib/view.xql";

declare default element namespace "http://www.w3.org/1999/xhtml";

(:~
 : The overall page function.
 :)
declare function local:page()
   as element()+
{
   <wrapper>
      <p>Some generic tools for MarkLogic.</p>
      <h3>Browse a database</h3>
      <p>Browse the documents within a database, in a hierarchical kind of way
         (based on the directory "structure").</p>
      {
         v:form('tools/browse-db', (
            v:input-select-databases('database', 'Database'),
            v:submit('Documents')))
      }
      <p>Browse the RDF resources within a database.  Only available for the databases
         with the triple index enabled.</p>
      {
         v:form('tools/browse-triples', (
            v:input-select-databases(
               'database',
               'Database',
               function($db) { $db/xs:boolean(a:triple-index) }),
            v:submit('Resources')))
      }
      <h3>Convert triples</h3>
      <p>Convert triples from a file, in a supported format, to the MarkLogic
         sem:triples format.</p>
      {
         (: TODO: Use a piece of JS to set the input format based on the file
            extension, when the user selects a file. :)
         v:form('tools/convert-triples', (
            v:input-file('file', 'File to convert'),
            v:input-select('input', 'Input format', (
               v:input-option('triplexml', 'MarkLogic sem:triples'),
               v:input-option('ntriple',   'N-Triples'),
               v:input-option('nquad',     'N-Quads'),
               v:input-option('turtle',    'Turtle'),
               v:input-option('rdfxml',    'RDF/XML'),
               v:input-option('n3',        'N3'),
               v:input-option('trig',      'TriG'),
               v:input-option('rdfjson',   'RDF/JSON'))),
            v:input-select('output', 'Output format', (
               v:input-option('triplexml', 'MarkLogic sem:triples'),
               v:input-option('ntriple',   'N-Triples'),
               v:input-option('nquad',     'N-Quads'),
               v:input-option('turtle',    'Turtle'),
               v:input-option('rdfxml',    'RDF/XML'),
               v:input-option('n3',        'N3'),
               v:input-option('trig',      'TriG'),
               v:input-option('rdfjson',   'RDF/JSON'))),
            v:submit('Convert')))
      }
      <h3>Admin entities</h3>
      <p>You can have a look at various MarkLogic objects, as they are
         represented within the code of the Console using XML elements at:
         <a href="tools/config">config</a>.</p>
      <!--h4>Other tools</h4>
      <p><b>TODO</b>: Other tools to provide: providing a way to set the owner
         and permissions when inserting files, editing a document in place,
         generating xqdoc documentation, running test suites, checking a repo
         integrity (like no duplicates in packages.xml, check that packages.xml
         is in synch with the directories...), etc.</p-->
   </wrapper>/*
};

v:console-page('', 'tools', 'Tools', local:page#0)