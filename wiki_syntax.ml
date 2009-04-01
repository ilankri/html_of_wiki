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
   Pretty print wiki to OcamlDuce
   @author Vincent Balat
   @author Boris Yakobowski
*)

let (>>=) = Lwt.bind

module W = Wikicreole


let block_extension_table = Hashtbl.create 8
let a_content_extension_table = Hashtbl.create 8
let link_extension_table = Hashtbl.create 8


let add_block_extension k f = Hashtbl.add block_extension_table k f

let add_a_content_extension k f = Hashtbl.add a_content_extension_table k f

let add_link_extension k f = Hashtbl.add link_extension_table k f




(***)
let make_string s = Lwt.return (Ocamlduce.Utf8.make s)

let element (c : Xhtmltypes_duce.inlines Lwt.t list) = 
  Lwt_util.map_serial (fun x -> x) c >>= fun c ->
  Lwt.return {{ (map {: c :} with i -> i) }}

let element2 (c : {{ [ Xhtmltypes_duce.a_content* ] }} list) = 
  {{ (map {: c :} with i -> i) }}

let parse_common_attribs attribs =
  let atts = 
    try
      let c = Ocamlduce.Utf8.make (List.assoc "class" attribs) in
      {{ {class=c} }}
    with Not_found -> {{ {} }}
  in
  let atts = 
    try
      let c = Ocamlduce.Utf8.make (List.assoc "id" attribs) in
      {{ {id=c}++atts }}
    with Not_found -> atts
  in
  atts

let list_builder = function
  | [] -> Lwt.return {{ [ <li>[] ] }} (*VVV ??? *)
  | a::l ->
      let f (c, 
             (l : Xhtmltypes_duce.flows Lwt.t option),
             attribs) =
        let atts = parse_common_attribs attribs in
        element c >>= fun r ->
        (match l with
          | Some v -> v >>= fun v -> Lwt.return v
          | None -> Lwt.return {{ [] }}) >>= fun l ->
        Lwt.return
          {{ <li (atts)>[ !r
                   !l ] }}
      in
      f a >>= fun r ->
      Lwt_util.map_serial f l >>= fun l ->
      Lwt.return {{ [ r !{: l :} ] }}

let inline (x : Xhtmltypes_duce.a_content)
    : Xhtmltypes_duce.inlines
    = {{ {: [ x ] :} }}

let absolute_link_regexp = Netstring_pcre.regexp "[a-z|A-Z|0-9]+:"

let is_absolute_link addr = 
  (Netstring_pcre.string_match absolute_link_regexp addr 0) <> None

let builder wiki_id =
  let servpage = Wiki_services.find_servpage wiki_id in
  { W.chars = make_string;
    W.strong_elem = (fun attribs a -> 
                       let atts = parse_common_attribs attribs in
                       element a >>= fun r ->
                       Lwt.return {{ [<strong (atts)>r ] }});
    W.em_elem = (fun attribs a -> 
                   let atts = parse_common_attribs attribs in
                   element a >>= fun r ->
                   Lwt.return {{ [<em (atts)>r] }});
    W.a_elem =
      (fun attribs _sp addr 
         (c : {{ [ Xhtmltypes_duce.a_content* ] }} Lwt.t list) -> 
           let atts = parse_common_attribs attribs in
           Lwt_util.map_serial (fun x -> x) c >>= fun c ->
           Lwt.return
             {{ [ <a ({href={: Ocamlduce.Utf8.make addr :}}++atts)>{: element2 c :} ] }});
    W.make_href =
      (fun sp addr ->
         match servpage, is_absolute_link addr with
           | (Some servpage, false) ->
               let addr =
                 Ocsigen_lib.remove_slash_at_beginning
                   (Ocsigen_lib.remove_dotdot (Neturl.split_path addr))
               in
               Eliom_predefmod.Xhtml.make_string_uri servpage sp addr
           | _ -> addr);
    W.br_elem = (fun attribs -> 
                   let atts = parse_common_attribs attribs in
                   Lwt.return {{ [<br (atts)>[]] }});
    W.img_elem =
      (fun attribs addr alt -> 
         let atts = parse_common_attribs attribs in
         Lwt.return 
           {{ [<img
                  ({src={: Ocamlduce.Utf8.make addr :} 
                    alt={: Ocamlduce.Utf8.make alt :}}
                   ++
                    atts)
                  >[] ] }});
    W.tt_elem = (fun attribs a ->
                   let atts = parse_common_attribs attribs in
                   element a >>= fun r ->
                   Lwt.return {{ [<tt (atts)>r ] }});
    W.nbsp = Lwt.return {{" "}};
    W.p_elem = (fun attribs a -> 
                  let atts = parse_common_attribs attribs in
                  element a >>= fun r ->
                  Lwt.return {{ [<p (atts)>r] }});
    W.pre_elem = (fun attribs a ->
       let atts = parse_common_attribs attribs in
       Lwt.return
         {{ [<pre (atts)>{:Ocamlduce.Utf8.make (String.concat "" a):}] }});
    W.h1_elem = (fun attribs a ->
                   let atts = parse_common_attribs attribs in
                   element a >>= fun r ->
                   Lwt.return {{ [<h1 (atts)>r] }});
    W.h2_elem = (fun attribs a ->
                   let atts = parse_common_attribs attribs in
                   element a >>= fun r ->
                   Lwt.return {{ [<h2 (atts)>r] }});
    W.h3_elem = (fun attribs a ->
                   let atts = parse_common_attribs attribs in
                   element a >>= fun r ->
                   Lwt.return {{ [<h3 (atts)>r] }});
    W.h4_elem = (fun attribs a ->
                   let atts = parse_common_attribs attribs in
                   element a >>= fun r ->
                   Lwt.return {{ [<h4 (atts)>r] }});
    W.h5_elem = (fun attribs a ->
                   let atts = parse_common_attribs attribs in
                   element a >>= fun r ->
                   Lwt.return {{ [<h5 (atts)>r] }});
    W.h6_elem = (fun attribs a ->
                   let atts = parse_common_attribs attribs in
                   element a >>= fun r ->
                   Lwt.return {{ [<h6 (atts)>r] }});
    W.ul_elem = (fun attribs a ->
                   let atts = parse_common_attribs attribs in
                   list_builder a >>= fun r ->
                   Lwt.return {{ [<ul (atts)>r] }});
    W.ol_elem = (fun attribs a ->
                   let atts = parse_common_attribs attribs in
                   list_builder a >>= fun r ->
                   Lwt.return {{ [<ol (atts)>r] }});
    W.hr_elem = (fun attribs -> 
                   let atts = parse_common_attribs attribs in
                   Lwt.return {{ [<hr (atts)>[]] }});
    W.table_elem =
      (fun attribs l ->
         let atts = parse_common_attribs attribs in
         match l with
         | [] -> Lwt.return {{ [] }}
         | row::rows ->
             let f (h, attribs, c) =
               let atts = parse_common_attribs attribs in
               element c >>= fun r ->
               Lwt.return
                 (if h 
                 then {{ <th (atts)>r }}
                 else {{ <td (atts)>r }})
             in
             let f2 (row, attribs) = match row with
               | [] -> Lwt.return {{ <tr>[<td>[]] }} (*VVV ??? *)
               | a::l -> 
                   let atts = parse_common_attribs attribs in
                   f a >>= fun r ->
                   Lwt_util.map_serial f l >>= fun l ->
                   Lwt.return {{ <tr (atts)>[ r !{: l :} ] }}
             in
             f2 row >>= fun row ->
             Lwt_util.map_serial f2 rows >>= fun rows ->
             Lwt.return {{ [<table (atts)>[<tbody>[ row !{: rows :} ] ] ] }});
    W.inline = (fun x -> x >>= fun x -> Lwt.return x);
    W.block_plugin = 
      (fun name -> Hashtbl.find block_extension_table name wiki_id);
    W.link_plugin =
      (fun name -> Hashtbl.find link_extension_table name wiki_id);
    W.a_content_plugin =
      (fun name param args content -> 
         let f = 
           try Hashtbl.find a_content_extension_table name
           with Not_found -> 
             (fun _ _ _ _ ->
                Lwt.return
                  {{ [ <b>[<i>[ 'Wiki error: Unknown extension '
                                  !{: name :} ] ] ] }})
         in 
         f wiki_id param args content);
    W.plugin_action = (fun _ _ _ _ _ _ -> ());
    W.error = (fun s -> Lwt.return {{ [ <b>{: s :} ] }});
  }

let xml_of_wiki wiki_id bi s = 
  Lwt_util.map_serial
    (fun x -> x)
    (Wikicreole.from_string bi.Wiki_widgets_interface.bi_sp bi
       (builder wiki_id) s)
  >>= fun r ->
  Lwt.return {{ (map {: r :} with i -> i) }}

let inline_of_wiki wiki_id bi s : Xhtmltypes_duce.inlines Lwt.t = 
  match Wikicreole.from_string bi.Wiki_widgets_interface.bi_sp
    bi
    (builder wiki_id) s
  with
    | [] -> Lwt.return {{ [] }}
    | a::_ -> a >>= (function
                       | {{ [ <p>l _* ] }} -> Lwt.return l
(*VVV What can I do with trailing data? *)
                       | {{ _ }} -> Lwt.return {{ [ <b>"error" ] }})

let a_content_of_wiki wiki_id bi s = 
  inline_of_wiki wiki_id bi s >>= fun r ->
  Lwt.return
    {{ map r with
         |  <a (Xhtmltypes_duce.a_attrs)>l -> l
         | p -> [p] }}



let string_of_extension name args content =
  "<<"^name^
    (List.fold_left
       (fun beg (n, v) -> beg^" "^n^"='"^v^"'") "" args)^
    (match content with
       | None -> "" 
       | Some content -> "|"^content)^">>"

(*********************************************************************)

(* Used for conditions of the form <<cond http_code= >> *)
type page_displayable =
  | Page_displayable
  | Page_404
  | Page_403

let page_displayable_key : page_displayable Polytables.key =
  Polytables.make_key ()

let page_displayable sd =
  try Polytables.get ~table:sd ~key:page_displayable_key
  with Not_found -> Page_displayable

let set_page_displayable sd pd =
  Polytables.set ~table:sd ~key:page_displayable_key ~value:pd


(*********************************************************************)

let _ =

  add_block_extension "div"
    (fun wiki_id bi args c -> 
       let content = match c with
         | Some c -> c
         | None -> ""
       in
       xml_of_wiki wiki_id bi content >>= fun content ->
       let classe = 
         try
           let a = List.assoc "class" args in
           {{ { class={: a :} } }} 
         with Not_found -> {{ {} }} 
       in
       let id = 
         try
           let a = List.assoc "id" args in
           {{ { id={: a :} } }} 
         with Not_found -> {{ {} }} 
       in
       Lwt.return 
         {{ [ <div (classe ++ id) >content ] }}
    );

  Wiki_filter.add_preparser_extension "div"
(*VVV may be done automatically for all extensions with wiki content
  (with an optional parameter of add_*_extension?) *)
    (fun w param args -> function
       | None -> Lwt.return None
       | Some c ->
           Wiki_filter.preparse_extension param w c >>= fun c ->
           Lwt.return (Some (string_of_extension "div" args (Some c)))
    )
  ;

  add_a_content_extension "span"
    (fun wiki_id bi args c -> 
       let content = match c with
         | Some c -> c
         | None -> ""
       in
       inline_of_wiki wiki_id bi content >>= fun content ->
       let classe = 
         try
           let a = List.assoc "class" args in
           {{ { class={: a :} } }} 
         with Not_found -> {{ {} }} 
       in
       let id = 
         try
           let a = List.assoc "id" args in
           {{ { id={: a :} } }} 
         with Not_found -> {{ {} }} 
       in
       Lwt.return 
         {{ [ <span (classe ++ id) >content ] }}
    );

  Wiki_filter.add_preparser_extension "span"
(*VVV may be done automatically for all extensions with wiki content
  (with an optional parameter of add_*_extension?) *)
    (fun w param args -> function
       | None -> Lwt.return None
       | Some c ->
           Wiki_filter.preparse_extension param w c >>= fun c ->
           Lwt.return (Some (string_of_extension "span" args (Some c)))
    )
  ;

  add_a_content_extension "wikiname"
    (fun wiki_id _ _ _ ->
       Wiki_sql.get_wiki_by_id wiki_id
       >>= fun wiki_info ->
       let s =  wiki_info.Wiki_sql.descr in
       Lwt.return {{ {: Ocamlduce.Utf8.make s :} }});


  add_a_content_extension "raw"
    (fun _ _ args content ->
       let s = string_of_extension "raw" args content in
       Lwt.return {{ [ <b>{: s :} ] }});

  add_a_content_extension ""
    (fun _ _ _ _ ->
       Lwt.return {{ [] }}
    );

  add_block_extension "content"
    (fun _ bi args _ -> 
       let classe = 
         try
           let a = List.assoc "class" args in
           {{ { class={: a :} } }} 
         with Not_found -> {{ {} }} 
       in
       let id = 
         try
           let a = List.assoc "id" args in
           {{ { id={: a :} } }} 
         with Not_found -> {{ {} }} 
       in
       match bi.Wiki_widgets_interface.bi_subbox with
         | None -> Lwt.return {{ [ <div (classe ++ id) >
                                     [<strong>[<em>"<<content>>"]]] }}
         | Some subbox -> Lwt.return {{ [ <div (classe ++ id) >subbox ] }}
    );

  add_block_extension "menu"
    (fun wiki_id bi args _ -> 
       let classe = 
         let c =
           "wikimenu"^
             (try
                " "^(List.assoc "class" args)
              with Not_found -> "")
         in {{ { class={: c :} } }} 
       in
       let id = 
         try
           let a = List.assoc "id" args in
           {{ { id={: a :} } }} 
         with Not_found -> {{ {} }} 
       in
       let f ?classe s =
         let link, text = 
           try 
             Ocsigen_lib.sep '|' s 
           with Not_found -> s, s
         in
         a_content_of_wiki wiki_id bi text >>= fun text2 ->
         if Eliom_sessions.get_current_sub_path_string
           bi.Wiki_widgets_interface.bi_sp = link
         then 
           let classe = match classe with
             | None -> {{ { class="wikimenu_current" } }}
             | Some c -> 
                 let c = Ocamlduce.Utf8.make ("wikimenu_current "^c) in
                 {{ { class=c } }}
           in
           Lwt.return {{ <li (classe)>text2}}
         else
           let href = 
             if is_absolute_link link
             then link
             else 
               match Wiki_services.find_servpage wiki_id with
                 | Some servpage -> 
                     let path =
                       Ocsigen_lib.remove_slash_at_beginning
                         (Ocsigen_lib.remove_dotdot (Neturl.split_path link))
                     in
                     Eliom_duce.Xhtml.make_uri
                       ~service:servpage
                       ~sp:bi.Wiki_widgets_interface.bi_sp
                       path
                 | _ -> link
           in
           let link2 = Ocamlduce.Utf8.make href in
           let classe = match classe with
             | None -> {{ {} }}
             | Some c -> 
                 let c = Ocamlduce.Utf8.make c in
                 {{ { class=c } }}
           in
           Lwt.return {{ <li (classe)>[<a href=link2>text2]}}
       in
       let rec mapf = function
           | [] -> Lwt.return []
           | [a] -> f ~classe:"wikimenu_last" a >>= fun b -> Lwt.return [b]
           | a::ll -> f a >>= fun b -> mapf ll >>= fun l -> Lwt.return (b::l)
       in
       match
         List.rev
           (List.fold_left
              (fun beg (n, v) -> if n="item" then v::beg else beg)
              [] args)
       with
         | [] -> Lwt.return {: [] :}
         | [a] ->  
             f ~classe:"wikimenu_first wikimenu_last" a >>= fun first ->
             Lwt.return {{ [ <ul (classe ++ id) >[ {: first :} ] ] }}
         | a::ll -> 
             f ~classe:"wikimenu_first" a >>= fun first ->
             mapf ll >>= fun poi ->
             Lwt.return 
               {{ [ <ul (classe ++ id) >[ first !{: poi :} ] ] }}
    );


  add_block_extension "cond"
    (fun wiki_id bi args c -> 
       let sp = bi.Wiki_widgets_interface.bi_sp in
       let sd = bi.Wiki_widgets_interface.bi_sd in
       let content = match c with
         | Some c -> c
         | None -> ""
       in
       (let rec eval_cond = function
          | ("error", "autherror") ->
              Lwt.return
                (List.exists
                   (fun e -> e = Users.BadPassword || e = Users.BadUser)
                   (Eliom_sessions.get_exn sp))
          | ("ingroup", g) ->
              Lwt.catch
                (fun () ->
                   Users.get_user_id_by_name g >>= fun group ->
                   Users.in_group ~sp ~sd ~group ())
                (function _ -> Lwt.return false)
          | ("http_code", "404") ->
              Lwt.return (page_displayable sd = Page_404)
          | ("http_code", "403") ->
              Lwt.return (page_displayable sd = Page_403)
          | ("http_code", "40?") ->
              Lwt.return (page_displayable sd <> Page_displayable)
         | (err, value) when String.length err >= 3 &&
             String.sub err 0 3 = "not" ->
             let cond' = (String.sub err 3 (String.length err - 3), value) in
             eval_cond cond' >>=
             fun b -> Lwt.return (not b)
         | _ -> Lwt.return false
        in
        (match args with
          | [c] -> eval_cond c
          | _ -> Lwt.return false)
        >>= function
          | true -> xml_of_wiki wiki_id bi content
          | false -> Lwt.return {{ [] }}
       )
    );

  Wiki_filter.add_preparser_extension "cond"
(*VVV may be done automatically for all extensions with wiki content 
  (with an optional parameter of add_*_extension?) *)
    (fun w param args -> function
       | None -> Lwt.return None
       | Some c ->
           Wiki_filter.preparse_extension param w c >>= fun c ->
           Lwt.return (Some (string_of_extension "cond" args (Some c)))
    )
  ;

