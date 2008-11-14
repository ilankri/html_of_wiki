(*-*-coding: utf-8;-*-*)

(*

XXXX

EDITEURS
- Preview
- Adapter au type d'événement ?
- Valeurs par défaut
- Comment (?)

LOAD
- check access rights...

CATEGORIES
- active ou non
- Droit de lecture et d'écriture par catégorie
- Valeurs par défaut : description, salle, horaire, durée ...
- peut contenir des événements ou non

FLUX
- Flux pas juste de séminaires/groupe de travail
- Prendre en compte modification, création, destruction
  (tentative, confirmed, cancelled)
- Afficher les horaires et salles inhabituels

CALENDRIER
- Afficher les intervalles de date
   jeudi 5 avril de 16h00 à 18h00
   du jeudi 6 avril 16h00 au vendredi 15 avril 17h30
  Afficher le lieu, la salle
- Afficher différemment les événements longs et les événements courts
- Vacances et jours fériés

SEMINAIRE
- Afficher salles et horaires inhabituels
- Séances communes ???

EVENEMENT
- Evenement appartenant à plusieurs catégories
  (exposé commun, par exemple)

PRESENTATION
- calendrier au format ICAL

LOW-LEVEL
- Comment faire en cas d'erreur SQL ?
  (par exemple, redémarrage du serveur)
*)

module P = Eliom_parameters
module M = Eliom_duce.Xhtml
open CalendarLib

let (>>=) = Lwt.(>>=)
let ( ** ) = P.( ** )
let str = Ocamlduce.Utf8.make

open Event_sql.Event

(****)

let default_category = "Ensemble des exposés"

(****)

let talks_path p = "talks" :: p

(****)

let format_entry abs sp sd em ev =
  Event_sql.find_speakers ev.id >>= fun speakers ->
  Event_sql.find_description ev.id >>= fun abstract ->
  let strong x = if em then {{[<strong>(x)]}}  else x in
  begin if em then
    Event.format_description sp sd abstract >>= fun abstract ->
    Lwt.return {{ [ abstract ] }}
  else
    Lwt.return {{ [] }}
  end >>= fun abstract ->
  Lwt.return
   {{[<dt>{:strong (str (Event.format_date_and_speakers ev.start speakers)):}
      <dd>[{:M.a abs sp (str ev.title) (Int32.to_string ev.id):} !abstract]]}}

(****)

let feed =
  Eliom_services.new_service
     ~path:(talks_path ["atom"])
     ~get_params:(P.suffix (P.all_suffix "category")) ()

let feed_link sp category =
  Event_sql.find_category_name category >>= fun cat_name ->
  let url = M.make_string_uri feed sp category in
  Lwt.return
    {{ <link rel="alternate"
        type="application/atom+xml" title={:str cat_name:} href={:str url:}>
          [] }}

let rec feed_links_rec sp rem category : {{ [Xhtmltypes_duce.link *] }} Lwt.t =
  begin match rem with
    [] | [""] -> Lwt.return {{ [] }}
  | s :: r    -> feed_links_rec sp r (s :: category)
  end >>= fun l ->
  Lwt.try_bind
    (fun () -> feed_link sp (List.rev category))
    (fun l1 -> Lwt.return {{ [l1 !l] }})
    (fun e  -> match e with Not_found -> Lwt.return l | _ -> raise e)

let feed_links sp category = feed_links_rec sp category []

(****)

let ical =
  Eliom_services.new_service
     ~path:(talks_path ["icalendar"])
     ~get_params:(P.suffix (P.all_suffix "category")) ()

let calendar_link sp category =
  let img = M.make_uri ~service:(Eliom_services.static_dir sp)
                               ~sp ["stock_calendar.png"] in
  M.a ical sp
    {{[<img alt="Calendar" src={:str img:}>[] !" Calendrier"]}} category

(****)

let dl def l =
  Common.opt def (fun x r ->{{ [<dl>[!x !(map {:r:} with s -> s)]] }}) l

let archives =
  let path = talks_path ["archives"] in
  M.register_new_service
    ~path ~get_params:(P.suffix (P.int "year" ** P.all_suffix "category"))
    (fun sp (year, category) () ->
       feed_links sp category >>= fun l ->
       Common.wiki_page path sp l
         (fun sp sd ->
            let dates = Format.sprintf "%d-%d" year (year + 1) in
            let start = Date.lmake ~year ~month:8 () in
            let finish = Date.next start `Year in
            let start = Calendar.create start Common.midnight in
            let finish = Calendar.create finish Common.midnight in
            Seminaire_sql.find_in_interval category start finish
              >>= fun rows ->
            Common.lwt_map (format_entry Event.events sp sd false) rows
                >>= fun l1 ->
            Event_sql.find_category_name category >>= fun cat_name ->
            Lwt.return
              (str (cat_name ^ " - " ^ dates),
               {{ [ <h1>[!(str cat_name)]
                    <h2>[!{:str ("Exposés " ^ dates):}]
                    !(dl {:{{[ ]}}:} l1) ] }})))

let year_of_date d =
  let month = Date.month d in
  Date.year d - if month < Date.Aug then 1 else 0

let ul_arch l =
  Common.opt {{[]}} (fun x r ->{{ [<ul class="archives">[x !{:r:}]] }}) l

let archive_list sp category =
  Seminaire_sql.archive_start_date category >>= fun start_date ->
  let finish_year = year_of_date (Date.today ()) in
  let start_year =
    match start_date with
      Some d -> year_of_date (Calendar.to_date d)
    | None   -> finish_year + 1
  in
  Lwt.return
    (ul_arch
       (List.map
          (fun y ->
             {{<li>[{:M.a archives sp
                       (str (Format.sprintf "%d-%d" y (y + 1)))
                       (y, category):}]}})
          (List.rev (Common_sql.seq start_year finish_year))))

(****)

let rec previous_day wd d =
  if Date.day_of_week d = wd then d else previous_day wd (Date.prev d `Day)

let summary_contents category sp sd =
  let today = Date.today () in
  let start = previous_day Date.Sat today in
  let finish = Date.next start `Week in
  let start = Calendar.create start Common.midnight in
  let finish = Calendar.create finish Common.midnight in
  Seminaire_sql.find_in_interval category start finish >>= fun rows ->
  Common.lwt_map (format_entry Event.events sp sd true) rows >>= fun l1 ->
  Seminaire_sql.find_after category finish >>= fun rows ->
  Common.lwt_map (format_entry Event.events sp sd false) rows >>= fun l2 ->
  Seminaire_sql.find_before category start 10L >>= fun rows ->
  Common.lwt_map (format_entry Event.events sp sd false) rows >>= fun l3 ->
  archive_list sp category >>= fun archives ->
  Event_sql.find_category_name category >>= fun cat_name ->
  Lwt.return
    (str cat_name,
     {{ [ <h1>{:str cat_name:}
          <p>[{:calendar_link sp category:}]
          <h2>{:str "Cette semaine":}
          !(dl [<p>{:str "Pas d'exposé cette semaine.":}] l1)
          <h2>{:str "À venir":}
          !(dl [<p>{:str "Pas d'exposé programmé pour l'instant.":}]
               l2)
          <h2>{:str "Passé":}
          !(dl {:{{[]}}:} l3)
          <h2>{:str "Archives":}
          !archives ] }})

let summary_page path sp category =
  feed_links sp category >>= fun l ->
  Common.wiki_page path sp l (summary_contents category)

let summary =
  let path = talks_path ["summary"] in
  M.register_new_service
    ~path
    ~get_params:(P.suffix (P.all_suffix "category"))
    (fun sp category () -> summary_page path sp category)

let ul l = Common.opt {{[]}} (fun x r ->{{ [<ul>[x !{:r:}]] }}) l

let groupes =
  let path = talks_path [""] in
  M.register_new_service
    ~path ~get_params:P.unit
    (fun sp () () ->
       Common.wiki_page path sp {{ [] }}
         (fun sp sd ->
            Seminaire_sql.find_talk_categories () >>= fun cat ->
            let l =
              List.map
                (fun (_, uniq_name, name) ->
                   let uniq_name = Str.split (Str.regexp "/") uniq_name in
                   let item = M.a summary sp (str name) uniq_name in
                   {{ <li>[item] }})
                cat
            in
            Lwt.return
              (str "Séminaire et groupes de travail",
               {{ [ <h1>{:str "Séminaire et groupes de travail":}
                    !(ul l) ] }})))

(****)

let opt_enc f v = match v with None -> "" | Some v -> f v
let opt_dec f s = match s with "" -> None | _ -> Some (f s)
let opt_map f v = match v with None -> None | Some v -> Some (f v)

let date_input date (hour_nm, (min_nm, (day_nm, (month_nm, year_nm)))) =
  let int a name value =
    M.int_input ~a ~input_type:{{"text"}} ~name ~value () in
  let min = Calendar.minute date in
  let hour = Calendar.hour date in
  let day = Calendar.day_of_month date in
  let month = Date.int_of_month (Calendar.month date) in
  let year = Calendar.year date in
  {{[(int {size = "2"} day_nm day)
     !{:str "/":}
     (int {size = "2"} month_nm month)
     !{:str "/":}
     (int {size = "4"} year_nm year)
     !{:str " à ":}
     (int {size = "2"} hour_nm hour)
     !{:str "h":}
     (int {size = "2"} min_nm min)]}}

let date_params s =
  let f s' = P.int (Format.sprintf "%s/%s" s s') in
  f "hour" ** f "min" ** f "day" ** f "month" ** f "year"

let date_rebuild (hour, (min, (day, (month, year)))) =
  Calendar.make year month day hour min 0

(*XXXXXXXXXXXXXXXXXXXXXX
let talk_editor =
  Eliom_services.new_service ~path:(talks_path ["edit"])
    ~get_params:(P.suffix (P.string "id"))
    ()

let talk_editor_action =
  M.register_new_post_coservice ~fallback:talk_editor
    ~post_params:(date_params "date" ** P.int "duration" **
                  P.string "location" ** P.string "room" **
                  P.string "speaker" ** P.string "aff" **
                  P.string "title" ** P.string "abstract" **
                  P.string "action")
    (fun sp id (date, (duration, (location, (room, (speaker,
                (affiliation, (title, (abstract, action)))))))) ->
       let id = opt_dec Int32.of_string id in
       let start = date_rebuild date in
       let finish = Calendar.add start (Calendar.Period.minute duration) in
       if action = "validate" then begin
         (match id with
              None ->
                (*XXX*)
                Event_sql.find_category_name "seminaire"
                    >>= fun (sem_category, _) ->
                insert_talk
                  sem_category start finish location room
                  speaker affiliation title abstract
            | Some id ->
                update_talk
                  id start finish location room
                  speaker affiliation title abstract >>= fun () ->
                Lwt.return id) >>= fun id ->
         Lwt.return
           {{<html>[
               {:Common.head sp "":}
               <body>[<p>[{:M.a Event.events sp
                              {{[<em>{:str title:}]}}
                              (Int32.to_string id):}]]]}}
       end else if action = "delete" && id <> None then begin
         begin match id with
           None    -> assert false
         | Some id -> delete_talk id
         end >>= fun () ->
         Lwt.return
           {{<html>[
              {:Common.head sp "":}
              <body>[<p>{:str ("Exposé supprimé : " ^ title):}]] }}
       end else
         (*XXX ??? *)
         Lwt.return
           {{ <html>[{:Common.head sp "":} <body>[]] }})
(*
           (H.html (H.head (H.title (H.pcdata "")) [])
            (H.body [H.p [H.pcdata (opt_enc Int32.to_string id)];
                     H.p [H.pcdata (Printer.Calendar.to_string start)];
                     H.p [H.pcdata (Printer.Calendar.to_string finish)];
                     H.p [H.pcdata speaker];
                     H.p [H.pcdata affiliation];
                     H.p [H.pcdata title];
                     H.p [H.pcdata abstract];
                     H.p [H.pcdata action]])))
*)

let create_form
      id start finish location room speaker affiliation title abstract
      (date_nm, (dur_nm, (location_nm, (room_nm, (speaker_nm,
       (affiliation_nm, (title_nm, (abstract_nm, action_nm)))))))) =
    let int a name value =
      M.int_input ~a ~input_type:{{"text"}} ~name ~value () in
    let text a name value =
      M.string_input ~a ~input_type:{{"text"}} ~name ~value () in
    let button name value txt =
      M.string_button ~name ~value txt in
    let hidden name value =
      M.string_input ~input_type:{{"hidden"}} ~name ~value ()
    in
    let duration =
      truncate
        (Time.Period.to_minutes
           (Calendar.Period.to_time (Calendar.sub finish start)) +. 0.5)
    in
    {{[
      <p>[!{:str "Date : ":} !(date_input start date_nm)
          !{:str " — durée : ":} (int {size = "3"} dur_nm duration)
          !{:str "min":}]
      <p>[!{:str "Salle : ":}
          (text {} room_nm room)
          (hidden location_nm location)]
      <p>[!{:str "Orateur : ":}
          (text {} speaker_nm speaker)
          !{:str " — affiliation : ":}
          (text {} affiliation_nm affiliation)]
      <p>[!{:str "Titre : ":}
          (text {size = "60"} title_nm title)]
      <p>[!{:str "Résumé : ":} <br>[]
          {:M.textarea ~cols:80 ~rows:20 ~name:abstract_nm
              ~value:(str abstract) ():}]
      <p>[{:button action_nm "validate" (str "Valider"):}
          !{:match id with
               None    ->
                 {{ [] }}
             | Some id ->
                 {{ [{:button action_nm "delete" (str "Supprimer"):}] }}:}]]}}

let form =
  M.register talk_editor
(*
  M.register_new_service ~path:(talks_path ["edit"])
    ~get_params:(P.suffix (P.string "id"))
*)
    (fun sp id () ->
       let id = opt_dec Int32.of_string id in
         (*XXX Validate *)
       (match id with
          Some id ->
            Event_sql.find_event id
        | None ->
            (*XXX Use default time, default duration and default room *)
            let start = Calendar.create (Date.today ()) (Time.now ()) in
            let finish =
              Calendar.add start (Calendar.Period.minute 90) in
            Lwt.return (0l, start, finish, "", "", "", "", ""))
           >>= fun (_, start, finish, room, speaker,
                    affiliation, title, abstract) ->
       let f =
         M.post_form ~service:talk_editor_action ~sp
           (create_form
              id start finish "" room speaker affiliation title abstract)
           (opt_enc Int32.to_string id)
       in
       Lwt.return
         {{<html>[{:Common.head sp "":} <body>[f]]}})
*)

let talk_editor =
  Eliom_services.new_service ~path:(talks_path ["edit"])
    ~get_params:(P.suffix (P.string "id"))
    ()

open Xform.Ops

let _ =
  M.register talk_editor
    (fun sp arg () ->
       let id = opt_dec Int32.of_string arg in
         (*XXX Validate *)
       (match id with
          Some id ->
            Event_sql.find_event id
                >>= fun {category = cat; start= (start, _); finish = (finish, _); room = room; title = title; description = desc; status = status} ->
            Event_sql.find_speakers id >>= fun speakers ->
            Wiki_sql.get_wikibox_data ~wikibox:(Common.wiki_id, desc) ()
                >>= fun desc ->
            let desc = match desc with None -> "" | Some (_, _, d, _, _) -> d in
            Lwt.return (cat, start, finish, room, title, speakers, desc, status)
        | _(*None*) ->
            (*XXX Use default time, default duration and default room *)
            let start = Calendar.create (Date.today ()) (Time.now ()) in
            let finish =
              Calendar.add start (Calendar.Period.minute 90) in
            Lwt.return (0l, start, finish, "", "", [("", "")], "", Confirmed))
           >>= fun (_, start, finish, room, title, speakers, abstract, status) ->
       let duration =
         truncate
           (Time.Period.to_minutes
              (Calendar.Period.to_time (Calendar.sub finish start)) +. 0.5)
       in
       let location = "" in
       let page sp arg error form =
         let txt = if error then "Erreur" else "Nouvel événement" in
         Lwt.return
           {{<html>[
                {:Common.head sp txt:}
                 <body>[<h1>(str txt) form]]}}
       in
       let form =
         Xform.form talk_editor arg page sp
           (Xform.p
              (Xform.text "Date : " @+ Xform.date_input start @@
               Xform.text " — Durée : " @+
               Xform.bounded_int_input 0 1440 duration +@
               Xform.text "min")
                  @@
            Xform.p
              (Xform.text "Salle : " @+ Xform.string_input room @@
               Xform.text " — Lieu : " @+ Xform.string_input location)
                  @@
            Xform.extensible_list "Ajouter un orateur supplémentaire"
              ("", "") speakers
              (fun (speaker, aff) ->
                Xform.p
                  (Xform.text "Orateur : " @+ Xform.string_input speaker @@
                   Xform.text " — Affiliation : "@+ Xform.string_input aff))
                 @@
            Xform.p
              (Xform.text "Titre : " @+
               Xform.check (Xform.string_input ~a:{{ {size = "60"} }} title)
                 (fun s -> if s = "" then Some ("nécessaire") else None))
                  @@
            Xform.p
              (Xform.text "Résumé :" @+ [{{<br>[]}}] @+
               Xform.text_area ~cols:80 ~rows:20 abstract)
                  @@
            (let l =
               List.map (fun (nm, s) -> (nm, Event_sql.string_of_status s))
                 Event_sql.status_list in
             Xform.p
               (Xform.text "État : " @+
                Xform.select_single l (Event_sql.string_of_status status)))
                  @@
            Xform.p
               (Xform.submit_button "Valider")
             |> (fun _ sp ->
                   Lwt.return
                     {{<html>[{:Common.head sp "":}
                              <body>[<p>{:(str "OK"):}]] }}))
       in
       page sp arg false form)

(****)

(**** Atom feed ****)

let _ =
  Eliom_atom.register feed
    (fun sp category () ->
       let sd = Ocsimore_common.get_sd sp in
       let today = Date.today () in
       let date = Date.prev today `Month in
       let date = Calendar.create date Common.midnight in
       Seminaire_sql.find_after category date >>= fun rows ->
       Common.lwt_map
         (fun ev ->
            Event_sql.find_category ev.category >>= fun (_, cat_name) ->
            Event_sql.find_speakers ev.id >>= fun speakers ->
            Event_sql.find_description ev.id >>= fun abstract ->
            Event.format_description sp sd abstract >>= fun abstract ->
            let p =
              M.make_full_string_uri Event.events sp (Int32.to_string ev.id) in
            let identity =
              { Atom_feed.id = p ^ "#" ^ Int32.to_string ev.version;
                Atom_feed.link = p;
                Atom_feed.updated = ev.last_updated;
                Atom_feed.title =
                  Event.format_date_and_speakers ev.start speakers ^ " — " ^
                  ev.title }
            in
            Lwt.return
              { Atom_feed.e_id = identity; Atom_feed.author = cat_name;
                Atom_feed.content = {{ [ abstract ] }} })
         rows
           >>= fun el ->
       let p = M.make_full_string_uri summary sp category in
       Event_sql.last_update () >>= fun d ->
       let d =
         match d with
           Some d -> d
         | None   -> Time_Zone.on Calendar.from_unixfloat Time_Zone.UTC
                       (Unix.gettimeofday ())
       in
       Event_sql.find_category_name category >>= fun cat_name ->
       Lwt.return
         (M.make_full_string_uri feed sp category,
          { Atom_feed.id = p; Atom_feed.link = p;
            Atom_feed.updated = d; Atom_feed.title = cat_name }, el))

(**** iCalendar publishing ****)

let _ =
  Eliom_icalendar.register ical
    (fun sp category () ->
       let sd = Ocsimore_common.get_sd sp in
       let today = Date.today () in
       let date = Date.prev today `Month in
       let date = Calendar.create date Common.midnight in
       Seminaire_sql.find_after category date >>= fun rows ->
       Event_sql.last_update () >>= fun stamp ->
       let stamp =
         match stamp with
           Some d -> d
         | None   -> Time_Zone.on Calendar.from_unixfloat Time_Zone.UTC
                       (Unix.gettimeofday ())
       in
       let hostname = Eliom_sessions.get_hostname ~sp in
       Common.lwt_map
         (fun ev ->
            Event_sql.find_category ev.category >>= fun (_, cat_name) ->
            Event_sql.find_speakers ev.id >>= fun speakers ->
            Event_sql.find_description ev.id >>= fun abstract ->
            Event.format_description sp sd abstract >>= fun abstract ->
            let p =
              M.make_full_string_uri Event.events sp (Int32.to_string ev.id) in
            let loc = Event.format_location ev.room ev.location in
            Lwt.return
              { Icalendar.dtstart = Common.utc_time ev.start;
                Icalendar.event_end =
                  Some (Icalendar.Dtend (Common.utc_time ev.finish));
                Icalendar.dtstamp = stamp;
                Icalendar.uid =
                   Format.sprintf "event%ld@@%s" ev.id hostname;
                Icalendar.summary =
                   cat_name ^ " — " ^
                   (if speakers = [] then "" else
                    (Event.format_speakers speakers ^ " — ")) ^
                   ev.title;
                Icalendar.description = None; (*XXX Need a text description*)
                Icalendar.comment = [];
                Icalendar.location = if loc = "" then None else Some loc;
                Icalendar.sequence = Some (Int32.to_int ev.version);
                Icalendar.status = None; (*XXX*)
                Icalendar.transp = Icalendar.Opaque;
                Icalendar.created = None;
                Icalendar.last_modified = Some ev.last_updated;
                Icalendar.url = Some p })
         rows
           >>= fun el ->
       Event_sql.find_category_name category >>= fun cat_name ->
       Lwt.return
         { Icalendar.prodid = "-//PPS//Events//EN"; (*???*)
           Icalendar.calname = Some cat_name;
           Icalendar.caldesc = None;
           Icalendar.events = el })
