(* Ocsimore
 * Copyright (C) 2008
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

   @author Piero Furiesi
   @author Jaap Boender
   @author Vincent Balat
*)

(** Abstract type for a wiki *)
type wiki

(** Conversions from a wiki index *)
val wiki_id_s : wiki -> string
val s_wiki_id : string -> wiki

(** Direct reading of wikis from eliom *)
val eliom_wiki :
  string -> (wiki, [`WithoutSuffix], [`One of wiki] Eliom_parameters.param_name) Eliom_parameters.params_type


(** inserts a new wiki container *)
val new_wiki : 
  title:string -> 
  descr:string -> 
  pages:bool ->
  boxrights:bool ->
  staticdir:string option ->
  unit ->
  wiki Lwt.t

(** Inserts a new wikipage in an existing wiki and return the id of the 
    wikibox. *)
val new_wikibox :
  wiki:wiki ->
  ?box:int32 ->
  author:User_sql.userid ->
  comment:string ->
  content:string ->
  ?rights:User_sql.userid list * User_sql.userid list * User_sql.userid list * User_sql.userid list ->
  unit ->
  int32 Lwt.t

(** return the history of a wikibox. *)
val get_history : 
  wiki:wiki -> 
  id:int32 ->
  (int32 * string * User_sql.userid * CalendarLib.Calendar.t) list Lwt.t




(*
(** inserts a new wikipage in an existing wiki; returns [None] if
    insertion failed due to [~suffix] already in use; [Some id] otherwise. *) 
val new_wikipage : wik_id:int32 -> suffix:string -> author:string ->
  subject:string -> txt:string -> int32 option Lwt.t

(** updates or inserts a wikipage. *) 
val add_or_change_wikipage : wik_id:int32 -> suffix:string -> author:string ->
  subject:string -> txt:string -> unit Lwt.t

(** returns title, description, number of wikipages of a wiki. *)
val wiki_get_data : wik_id:int32 -> (string * string * int) Lwt.t

(** returns the list of subject, suffix, author, datetime of wikipages, sorted by subject *)
val wiki_get_pages_list : wik_id:int32 -> 
  (string * string * string * Calendar.t) list Lwt.t
*)


(**/**)
(* DO NOT USE THE FOLLOWING BUT THOSE IN WIKI_CACHE.ML *)

(** return the box corresponding to a wikipage *)
val get_box_for_page : wiki:wiki -> page:string -> int32 Lwt.t

(** sets the box corresponding to a wikipage *)
val set_box_for_page : wiki:wiki -> id:int32 -> page:string -> unit Lwt.t

(** returns the css for a page or fails with [Not_found] if it does not exist *)
val get_css_for_page : wiki:wiki -> page:string -> string Lwt.t

(** Sets the css for a wikipage *)
val set_css_for_page : wiki:wiki -> page:string -> string -> unit Lwt.t

(** returns the global css for a wiki 
    or fails with [Not_found] if it does not exist *)
val get_css_for_wiki : wiki:wiki -> string Lwt.t

(** Sets the global css for a wiki *)
val set_css_for_wiki : wiki:wiki -> string -> unit Lwt.t

(** Find wiki information for a wiki, given its id *)
val find_wiki : id:wiki -> 
  (string * string * bool * bool * int32 ref * int32 option * 
     string option) Lwt.t

(** Find wiki information for a wiki, given its name *)
val find_wiki_id_by_name : name:string -> wiki Lwt.t

(** looks for a wikibox and returns [Some (subject, text, author,
    datetime)], or [None] if the page doesn't exist. *)
val get_wikibox_data : 
  ?version:int32 ->
  wikibox:(wiki * int32) ->
  unit ->
  (string * User_sql.userid * string * CalendarLib.Calendar.t) option Lwt.t

(** Inserts a new version of an existing wikibox in a wiki 
    and return its version number. *)
val update_wikibox :
  wiki:wiki ->
  wikibox:int32 ->
  author:User_sql.userid ->
  comment:string ->
  content:string ->
  int32 Lwt.t

(** Update container_id (only, for now). *)
val update_wiki :
  wiki_id:wiki ->
  container_id:int32 ->
  unit ->
  unit Lwt.t

val populate_readers :
  wiki -> int32 -> int32 list -> unit Lwt.t
val populate_writers :
  wiki -> int32 -> int32 list -> unit Lwt.t
val populate_rights_adm :
  wiki -> int32 -> int32 list -> unit Lwt.t
val populate_wikiboxes_creators :
  wiki -> int32 -> int32 list -> unit Lwt.t

val remove_readers :
  wiki -> int32 -> int32 list -> unit Lwt.t
val remove_writers :
  wiki -> int32 -> int32 list -> unit Lwt.t
val remove_rights_adm :
  wiki -> int32 -> int32 list -> unit Lwt.t
val remove_wikiboxes_creators :
  wiki -> int32 -> int32 list -> unit Lwt.t


val get_readers_ : (wiki * int32) -> User_sql.userid list Lwt.t
val get_writers_ : (wiki * int32) -> User_sql.userid list Lwt.t
val get_rights_adm_ : (wiki * int32) -> User_sql.userid list Lwt.t
val get_wikiboxes_creators_ : (wiki * int32) -> User_sql.userid list Lwt.t

