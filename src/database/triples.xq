xquery version "3.0";

import module namespace a   = "http://expath.org/ns/ml/console/admin" at "../lib/admin.xql";
import module namespace t   = "http://expath.org/ns/ml/console/tools" at "../lib/tools.xql";
import module namespace v   = "http://expath.org/ns/ml/console/view"  at "../lib/view.xql";
import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace h      = "http://www.w3.org/1999/xhtml";
declare namespace c      = "http://expath.org/ns/ml/console";
declare namespace err    = "http://www.w3.org/2005/xqt-errors";
declare namespace cts    = "http://marklogic.com/cts";
declare namespace xdmp   = "http://marklogic.com/xdmp";
declare namespace map    = "http://marklogic.com/xdmp/map";
declare namespace sec    = "http://marklogic.com/xdmp/security";
declare namespace sparql = "http://www.w3.org/2005/sparql-results#";

declare variable $path := local:get-param-path();

declare variable $root := local:get-root($path);

(: Fixed page size for now. :)
declare variable $page-size := 100;

(:~
 : The param "path", if any.
 :)
declare function local:get-param-path()
   as xs:string?
{
   let $path := t:optional-field('path', ())[.]
   return
      if ( fn:starts-with($path, '/http://') ) then
         fn:substring($path, 2)
      else
         $path
};

(:~
 : The path to the webapp root, relative to current $path.
 :)
declare function local:get-root($path as xs:string)
   as xs:string
{
   if ( fn:empty($path) ) then
      './'
   else
      let $toks  := fn:tokenize($path, '/')
      let $count := fn:count($toks) + (1[fn:starts-with($path, '/')], 2)[1]
      return
         t:make-string('../', $count)
};

(:~
 : The overall page function.
 :)
declare function local:page(
   $name  as xs:string,
   $start as xs:integer,
   $rsrc  as xs:string?
) as element()+
{
   let $db := a:get-database($name)
   return
      (: TODO: In this case, we should NOT return "200 OK". :)
      if ( fn:empty($db) ) then (
         local:page--no-db($name)
      )
      else if ( fn:empty($rsrc) ) then (
         local:page--browse($db, $start)
      )
      else (
         local:page--rsrc($db, $rsrc)
      )
};

(:~
 : The page content, in case the DB does not exist.
 :)
declare function local:page--no-db($name as xs:string)
   as element(h:p)
{
   <p><b>Error</b>: The database "<code>{ $name }</code>" does not exist.</p>
};

(:~
 : The page content, when browsing resource list.
 :)
declare function local:page--browse($db as element(a:database), $start as xs:integer)
   as element()+
{
   <p>Database: { v:db-link('triples', $db/a:name) }</p>,
   <p> {
      (: TODO: Pass parameters properly, instead of concatenating values. :)
      let $query :=
            'SELECT DISTINCT ?s WHERE {
                ?s ?p ?o .
                # filter out blank nodes, and xs:dateTimes like in the Meters database
                FILTER ( isIRI(?s) )
             }
             ORDER BY ?s
             OFFSET ' || $start - 1 || '
             LIMIT ' || $page-size
      let $res   := sem:sparql($query)
      let $count := fn:count($res)
      let $to    := $start + $count - 1
      return (
         'Results ' || $start || ' to ' || $to,
         t:when($start gt 1,
            (', ', <a href="triples?start={ $start - $page-size }">previous page</a>)),
         t:when($count eq $page-size,
            (', ', <a href="triples?start={ $start + $count }">next page</a>)),
         ':',
         $res ! map:get(., 's')
            ! <li>{ v:rsrc-link('triples?rsrc=' || fn:encode-for-uri(.), .) }</li>
      )
   }
   </p>
};

(:~
 : The page content, when browsing resource list.
 :
 : @todo Configurize the rule sets to use...
 :)
declare function local:page--rsrc($db as element(a:database), $rsrc as xs:string)
   as element()+
{
   <p>Database: { v:db-link('triples', $db/a:name) }</p>,
   <p>Resource: { v:rsrc-link('triples?rsrc=' || fn:encode-for-uri($rsrc), $rsrc) }</p>,
   <h3>Triples</h3>,
   <table class="table table-striped datatable">
      <thead>
         <th>Property</th>
         <th>Object</th>
         <th>Type</th>
      </thead>
      <tbody> {
         (: TODO: Support windowing, in case one single resources has thousands of triples. :)
         for $r in sem:sparql(
                      'SELECT ?p ?o WHERE { ?s ?p ?o } ORDER BY ?p',
                      map:entry('s', sem:iri($rsrc)),
                      (),
                      sem:ruleset-store('rdfs.rules', sem:store()))
         return
            <tr>
               <td>{ local:display-value(map:get($r, 'p'), 'prop') }</td>
               <td>{ local:display-value(map:get($r, 'o'), 'rsrc') }</td>
               <td>{ local:display-type(map:get($r, 'o')) }</td>
            </tr>
      }
      </tbody>
   </table>,
   <h3>Inbound links</h3>,
   <table class="table table-striped datatable">
      <thead>
         <th>Subject</th>
         <th>Property</th>
      </thead>
      <tbody> {
         (: TODO: Support windowing, in case one single resources has thousands of links. :)
         for $r in sem:sparql(
                      'SELECT ?s ?p WHERE { ?s ?p ?o } ORDER BY ?p',
                      map:entry('o', sem:iri($rsrc)),
                      (),
                      sem:ruleset-store('rdfs.rules', sem:store()))
         return
            <tr>
               <td>{ local:display-value(map:get($r, 's'), 'rsrc') }</td>
               <td>{ local:display-value(map:get($r, 'p'), 'prop') }</td>
            </tr>
      }
      </tbody>
   </table>,
   <h3>Documents</h3>,
   <p>The triples with this subject (those stored, not inferred), are stored in the
      following document(s):</p>,
   <ul> {
      let $uris := cts:uris('', (), cts:and-query(cts:triple-range-query(sem:iri($rsrc), (), ())))
      return
         if ( fn:empty($uris) ) then
            <li><em>no triple stored in document</em></li>
         else
            for $uri in $uris
            order by $uri
            return
               (: TODO: To make a link to the docujment browser... :)
               <li>
                  <a href="browse{ '/'[fn:not(fn:starts-with($uri, '/'))] }{ $uri }">{ $uri }</a>
               </li>
   }
   </ul>
};

declare function local:display-value($v as xs:anyAtomicType, $kind as xs:string)
   as element()
{
   if ( sem:isIRI($v) ) then
      (: TODO: Display the link only when the resource exists (that is, there is
         at least one triple with that IRI as subject). :)
      v:component-link(
         'triples?rsrc=' || fn:encode-for-uri($v),
         v:shorten-resource($v),
         $kind)
   else
      <span>{ $v }</span>
};

declare function local:display-type($v as xs:anyAtomicType)
   as element()
{
   (: TODO: Return a different class instead per case, and display it graphically
      rather than using a string. :)
   if ( sem:isIRI($v) ) then
      <span class="glyphicon glyphicon-link" title="Resource"/>
   else if ( sem:isNumeric($v) ) then
      <span class="glyphicon glyphicon-usd"  title="Number"/>
   else if ( sem:lang($v) ) then
      sem:lang($v) ! <span class="glyphicon glyphicon-font" title="String, language: { . }">&#160;{ . }</span>
   else
      (: Assuming a string? :)
      <span class="glyphicon glyphicon-font" title="String"/>
};

let $slashes := if ( fn:empty($path) ) then 0 else fn:count(fn:tokenize($path, '/'))
let $root    := fn:string-join(for $i in 1 to $slashes + 2 return '..', '/') || '/'
let $db      := t:mandatory-field('name')
let $rsrc    := t:optional-field('rsrc', ())
let $start   := xs:integer(t:optional-field('start', 1)[.])
let $params  := 
      map:new((
         map:entry('db',    $db),
         map:entry('rsrc',  $rsrc),
         map:entry('start', $start),
         map:entry('fun',   local:page#3)))
return
   v:console-page($root, 'browser', 'Browse resources', function() {
      a:eval-on-database(
         $db,
         'declare variable $db    external;
          declare variable $start external;
          declare variable $rsrc  external := ();
          declare variable $fun   external;
          $fun($db, $start, $rsrc)',
         $params)
   })
