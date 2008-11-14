open Lwt

let container ?css content =
  let css = match css with
    | None -> {{ [] }}
    | Some c -> c
  in
  {{
     <html>[
       <head>[
         <title>"Ocsimore"
           !css
       ]
       <body>content
     ]
   }}


class creole_wikibox ?sp () adminwikiinfo = object
  inherit Wiki_widgets.editable_wikibox ?sp () adminwikiinfo

  method pretty_print_wikisyntax ?subbox ~ancestors ~sp ~sd w content =
    Wiki_syntax.xml_of_wiki ?subbox ~ancestors ~sp ~sd w content

  method container = container

end