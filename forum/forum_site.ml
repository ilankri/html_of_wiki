(* Ocsimore
 * Copyright (C) 2009
 * Laboratoire PPS - Université Paris Diderot - CNRS
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)
(**
   @author Vincent Balat
   @author Boris Yakobowski
*)


let forum_wiki_model = Ocsisite.wikicreole_model (* pour l'instant *)

let _ =
  let wiki_widgets = Wiki_models.get_widgets forum_wiki_model in
  let services = Forum_services.register_services () in
  let widget_err = new Widget.widget_with_error_box in
  let add_message_widget = new Forum_widgets.add_message_widget services in 
  let message_widget = 
    new Forum_widgets.message_widget 
      widget_err wiki_widgets services 
  in 
  let thread_widget = 
    new Forum_widgets.thread_widget
      widget_err message_widget add_message_widget services
  in
  let message_list_widget = 
    new Forum_widgets.message_list_widget
      widget_err message_widget add_message_widget
  in
  Forum_wikiext.register_wikiext
    Wiki_syntax.wikicreole_parser 
    (message_widget, thread_widget, message_list_widget)


(** We register the css headers for forums (that are, for now,
    inconditionnaly added) *)

let () =
  Ocsimore_page.add_html_header_hook
    (fun sp ->
       {{ [ {: Eliom_duce.Xhtml.css_link
               (Ocsimore_page.static_file_uri sp ["ocsiforumstyle.css"]) () :}
          ] }}
    )
