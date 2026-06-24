drop trigger if exists "set_incident_status_cache_updated_at" on "public"."incident_status_cache";

drop trigger if exists "update_troubleshooting_entry_date_updated_trigger" on "public"."troubleshooting_entries";

drop policy "Anyone can insert feedback" on "public"."feedback";

drop policy "Allow public read access" on "public"."launch_weeks";

drop policy "Allow anybody to select all meetups" on "public"."meetups";

drop policy "Enable read access for anon and authenticated" on "public"."page";

drop policy "anon can read page_nimbus" on "public"."page_nimbus";

drop policy "authenticated can read page_nimbus" on "public"."page_nimbus";

drop policy "Enable read access for anon and authenticated" on "public"."page_section";

drop policy "anon can read page_section_nimbus" on "public"."page_section_nimbus";

drop policy "authenticated can read page_section_nimbus" on "public"."page_section_nimbus";

drop policy "Allow authenticated user to update its own ticket" on "public"."tickets";

drop policy "Allow insert for authenticated users only" on "public"."tickets";

drop policy "Allow user to select own ticket" on "public"."tickets";

drop policy "anon_read_troubleshooting_entries" on "public"."troubleshooting_entries";

drop policy "authenticated_read_troubleshooting_entries" on "public"."troubleshooting_entries";

revoke delete on table "public"."feedback" from "anon";

revoke insert on table "public"."feedback" from "anon";

revoke references on table "public"."feedback" from "anon";

revoke select on table "public"."feedback" from "anon";

revoke trigger on table "public"."feedback" from "anon";

revoke truncate on table "public"."feedback" from "anon";

revoke update on table "public"."feedback" from "anon";

revoke delete on table "public"."feedback" from "authenticated";

revoke insert on table "public"."feedback" from "authenticated";

revoke references on table "public"."feedback" from "authenticated";

revoke select on table "public"."feedback" from "authenticated";

revoke trigger on table "public"."feedback" from "authenticated";

revoke truncate on table "public"."feedback" from "authenticated";

revoke update on table "public"."feedback" from "authenticated";

revoke delete on table "public"."feedback" from "service_role";

revoke insert on table "public"."feedback" from "service_role";

revoke references on table "public"."feedback" from "service_role";

revoke select on table "public"."feedback" from "service_role";

revoke trigger on table "public"."feedback" from "service_role";

revoke truncate on table "public"."feedback" from "service_role";

revoke update on table "public"."feedback" from "service_role";

revoke delete on table "public"."incident_status_cache" from "service_role";

revoke insert on table "public"."incident_status_cache" from "service_role";

revoke references on table "public"."incident_status_cache" from "service_role";

revoke select on table "public"."incident_status_cache" from "service_role";

revoke trigger on table "public"."incident_status_cache" from "service_role";

revoke truncate on table "public"."incident_status_cache" from "service_role";

revoke update on table "public"."incident_status_cache" from "service_role";

revoke delete on table "public"."last_changed" from "service_role";

revoke insert on table "public"."last_changed" from "service_role";

revoke references on table "public"."last_changed" from "service_role";

revoke select on table "public"."last_changed" from "service_role";

revoke trigger on table "public"."last_changed" from "service_role";

revoke truncate on table "public"."last_changed" from "service_role";

revoke update on table "public"."last_changed" from "service_role";

revoke delete on table "public"."launch_weeks" from "anon";

revoke insert on table "public"."launch_weeks" from "anon";

revoke references on table "public"."launch_weeks" from "anon";

revoke select on table "public"."launch_weeks" from "anon";

revoke trigger on table "public"."launch_weeks" from "anon";

revoke truncate on table "public"."launch_weeks" from "anon";

revoke update on table "public"."launch_weeks" from "anon";

revoke delete on table "public"."launch_weeks" from "authenticated";

revoke insert on table "public"."launch_weeks" from "authenticated";

revoke references on table "public"."launch_weeks" from "authenticated";

revoke select on table "public"."launch_weeks" from "authenticated";

revoke trigger on table "public"."launch_weeks" from "authenticated";

revoke truncate on table "public"."launch_weeks" from "authenticated";

revoke update on table "public"."launch_weeks" from "authenticated";

revoke delete on table "public"."launch_weeks" from "service_role";

revoke insert on table "public"."launch_weeks" from "service_role";

revoke references on table "public"."launch_weeks" from "service_role";

revoke select on table "public"."launch_weeks" from "service_role";

revoke trigger on table "public"."launch_weeks" from "service_role";

revoke truncate on table "public"."launch_weeks" from "service_role";

revoke update on table "public"."launch_weeks" from "service_role";

revoke delete on table "public"."meetups" from "anon";

revoke insert on table "public"."meetups" from "anon";

revoke references on table "public"."meetups" from "anon";

revoke select on table "public"."meetups" from "anon";

revoke trigger on table "public"."meetups" from "anon";

revoke truncate on table "public"."meetups" from "anon";

revoke update on table "public"."meetups" from "anon";

revoke delete on table "public"."meetups" from "authenticated";

revoke insert on table "public"."meetups" from "authenticated";

revoke references on table "public"."meetups" from "authenticated";

revoke select on table "public"."meetups" from "authenticated";

revoke trigger on table "public"."meetups" from "authenticated";

revoke truncate on table "public"."meetups" from "authenticated";

revoke update on table "public"."meetups" from "authenticated";

revoke delete on table "public"."meetups" from "service_role";

revoke insert on table "public"."meetups" from "service_role";

revoke references on table "public"."meetups" from "service_role";

revoke select on table "public"."meetups" from "service_role";

revoke trigger on table "public"."meetups" from "service_role";

revoke truncate on table "public"."meetups" from "service_role";

revoke update on table "public"."meetups" from "service_role";

revoke delete on table "public"."page" from "anon";

revoke insert on table "public"."page" from "anon";

revoke references on table "public"."page" from "anon";

revoke select on table "public"."page" from "anon";

revoke trigger on table "public"."page" from "anon";

revoke truncate on table "public"."page" from "anon";

revoke update on table "public"."page" from "anon";

revoke delete on table "public"."page" from "authenticated";

revoke insert on table "public"."page" from "authenticated";

revoke references on table "public"."page" from "authenticated";

revoke select on table "public"."page" from "authenticated";

revoke trigger on table "public"."page" from "authenticated";

revoke truncate on table "public"."page" from "authenticated";

revoke update on table "public"."page" from "authenticated";

revoke delete on table "public"."page" from "service_role";

revoke insert on table "public"."page" from "service_role";

revoke references on table "public"."page" from "service_role";

revoke select on table "public"."page" from "service_role";

revoke trigger on table "public"."page" from "service_role";

revoke truncate on table "public"."page" from "service_role";

revoke update on table "public"."page" from "service_role";

revoke delete on table "public"."page_nimbus" from "anon";

revoke insert on table "public"."page_nimbus" from "anon";

revoke references on table "public"."page_nimbus" from "anon";

revoke select on table "public"."page_nimbus" from "anon";

revoke trigger on table "public"."page_nimbus" from "anon";

revoke truncate on table "public"."page_nimbus" from "anon";

revoke update on table "public"."page_nimbus" from "anon";

revoke delete on table "public"."page_nimbus" from "authenticated";

revoke insert on table "public"."page_nimbus" from "authenticated";

revoke references on table "public"."page_nimbus" from "authenticated";

revoke select on table "public"."page_nimbus" from "authenticated";

revoke trigger on table "public"."page_nimbus" from "authenticated";

revoke truncate on table "public"."page_nimbus" from "authenticated";

revoke update on table "public"."page_nimbus" from "authenticated";

revoke delete on table "public"."page_nimbus" from "service_role";

revoke insert on table "public"."page_nimbus" from "service_role";

revoke references on table "public"."page_nimbus" from "service_role";

revoke select on table "public"."page_nimbus" from "service_role";

revoke trigger on table "public"."page_nimbus" from "service_role";

revoke truncate on table "public"."page_nimbus" from "service_role";

revoke update on table "public"."page_nimbus" from "service_role";

revoke delete on table "public"."page_section" from "anon";

revoke insert on table "public"."page_section" from "anon";

revoke references on table "public"."page_section" from "anon";

revoke select on table "public"."page_section" from "anon";

revoke trigger on table "public"."page_section" from "anon";

revoke truncate on table "public"."page_section" from "anon";

revoke update on table "public"."page_section" from "anon";

revoke delete on table "public"."page_section" from "authenticated";

revoke insert on table "public"."page_section" from "authenticated";

revoke references on table "public"."page_section" from "authenticated";

revoke select on table "public"."page_section" from "authenticated";

revoke trigger on table "public"."page_section" from "authenticated";

revoke truncate on table "public"."page_section" from "authenticated";

revoke update on table "public"."page_section" from "authenticated";

revoke delete on table "public"."page_section" from "service_role";

revoke insert on table "public"."page_section" from "service_role";

revoke references on table "public"."page_section" from "service_role";

revoke select on table "public"."page_section" from "service_role";

revoke trigger on table "public"."page_section" from "service_role";

revoke truncate on table "public"."page_section" from "service_role";

revoke update on table "public"."page_section" from "service_role";

revoke delete on table "public"."page_section_nimbus" from "anon";

revoke insert on table "public"."page_section_nimbus" from "anon";

revoke references on table "public"."page_section_nimbus" from "anon";

revoke select on table "public"."page_section_nimbus" from "anon";

revoke trigger on table "public"."page_section_nimbus" from "anon";

revoke truncate on table "public"."page_section_nimbus" from "anon";

revoke update on table "public"."page_section_nimbus" from "anon";

revoke delete on table "public"."page_section_nimbus" from "authenticated";

revoke insert on table "public"."page_section_nimbus" from "authenticated";

revoke references on table "public"."page_section_nimbus" from "authenticated";

revoke select on table "public"."page_section_nimbus" from "authenticated";

revoke trigger on table "public"."page_section_nimbus" from "authenticated";

revoke truncate on table "public"."page_section_nimbus" from "authenticated";

revoke update on table "public"."page_section_nimbus" from "authenticated";

revoke delete on table "public"."page_section_nimbus" from "service_role";

revoke insert on table "public"."page_section_nimbus" from "service_role";

revoke references on table "public"."page_section_nimbus" from "service_role";

revoke select on table "public"."page_section_nimbus" from "service_role";

revoke trigger on table "public"."page_section_nimbus" from "service_role";

revoke truncate on table "public"."page_section_nimbus" from "service_role";

revoke update on table "public"."page_section_nimbus" from "service_role";

revoke delete on table "public"."tickets" from "anon";

revoke insert on table "public"."tickets" from "anon";

revoke references on table "public"."tickets" from "anon";

revoke select on table "public"."tickets" from "anon";

revoke trigger on table "public"."tickets" from "anon";

revoke truncate on table "public"."tickets" from "anon";

revoke update on table "public"."tickets" from "anon";

revoke delete on table "public"."tickets" from "authenticated";

revoke insert on table "public"."tickets" from "authenticated";

revoke references on table "public"."tickets" from "authenticated";

revoke select on table "public"."tickets" from "authenticated";

revoke trigger on table "public"."tickets" from "authenticated";

revoke truncate on table "public"."tickets" from "authenticated";

revoke update on table "public"."tickets" from "authenticated";

revoke delete on table "public"."tickets" from "service_role";

revoke insert on table "public"."tickets" from "service_role";

revoke references on table "public"."tickets" from "service_role";

revoke select on table "public"."tickets" from "service_role";

revoke trigger on table "public"."tickets" from "service_role";

revoke truncate on table "public"."tickets" from "service_role";

revoke update on table "public"."tickets" from "service_role";

revoke delete on table "public"."troubleshooting_entries" from "anon";

revoke insert on table "public"."troubleshooting_entries" from "anon";

revoke references on table "public"."troubleshooting_entries" from "anon";

revoke select on table "public"."troubleshooting_entries" from "anon";

revoke trigger on table "public"."troubleshooting_entries" from "anon";

revoke truncate on table "public"."troubleshooting_entries" from "anon";

revoke update on table "public"."troubleshooting_entries" from "anon";

revoke delete on table "public"."troubleshooting_entries" from "authenticated";

revoke insert on table "public"."troubleshooting_entries" from "authenticated";

revoke references on table "public"."troubleshooting_entries" from "authenticated";

revoke select on table "public"."troubleshooting_entries" from "authenticated";

revoke trigger on table "public"."troubleshooting_entries" from "authenticated";

revoke truncate on table "public"."troubleshooting_entries" from "authenticated";

revoke update on table "public"."troubleshooting_entries" from "authenticated";

revoke delete on table "public"."troubleshooting_entries" from "service_role";

revoke insert on table "public"."troubleshooting_entries" from "service_role";

revoke references on table "public"."troubleshooting_entries" from "service_role";

revoke select on table "public"."troubleshooting_entries" from "service_role";

revoke trigger on table "public"."troubleshooting_entries" from "service_role";

revoke truncate on table "public"."troubleshooting_entries" from "service_role";

revoke update on table "public"."troubleshooting_entries" from "service_role";

revoke delete on table "public"."validation_history" from "anon";

revoke insert on table "public"."validation_history" from "anon";

revoke references on table "public"."validation_history" from "anon";

revoke select on table "public"."validation_history" from "anon";

revoke trigger on table "public"."validation_history" from "anon";

revoke truncate on table "public"."validation_history" from "anon";

revoke update on table "public"."validation_history" from "anon";

revoke delete on table "public"."validation_history" from "authenticated";

revoke insert on table "public"."validation_history" from "authenticated";

revoke references on table "public"."validation_history" from "authenticated";

revoke select on table "public"."validation_history" from "authenticated";

revoke trigger on table "public"."validation_history" from "authenticated";

revoke truncate on table "public"."validation_history" from "authenticated";

revoke update on table "public"."validation_history" from "authenticated";

revoke delete on table "public"."validation_history" from "service_role";

revoke insert on table "public"."validation_history" from "service_role";

revoke references on table "public"."validation_history" from "service_role";

revoke select on table "public"."validation_history" from "service_role";

revoke trigger on table "public"."validation_history" from "service_role";

revoke truncate on table "public"."validation_history" from "service_role";

revoke update on table "public"."validation_history" from "service_role";

alter table "public"."incident_status_cache" drop constraint "incident_status_cache_incident_id_key";

alter table "public"."incident_status_cache" drop constraint "incident_status_cache_shortlink_key";

alter table "public"."last_changed" drop constraint "last_changed_parent_page_heading_key";

alter table "public"."meetups" drop constraint "meetups_launch_week_fkey";

alter table "public"."page" drop constraint "page_path_key";

alter table "public"."page_nimbus" drop constraint "page_nimbus_path_key";

alter table "public"."page_section" drop constraint "page_section_page_id_fkey";

alter table "public"."page_section_nimbus" drop constraint "page_section_nimbus_page_id_fkey";

alter table "public"."tickets" drop constraint "public_tickets_id_fkey";

alter table "public"."tickets" drop constraint "tickets_email_key";

alter table "public"."tickets" drop constraint "tickets_launch_week_fkey";

alter table "public"."tickets" drop constraint "tickets_ticket_number_key";

alter table "public"."tickets" drop constraint "tickets_user_id_fkey";

alter table "public"."tickets" drop constraint "tickets_username_key";

alter table "public"."troubleshooting_entries" drop constraint "troubleshooting_api_check";

alter table "public"."troubleshooting_entries" drop constraint "troubleshooting_errors_check";

drop view if exists "metrics"."feedback_response_aggregate";

drop function if exists "public"."match_embedding"(embedding public.vector, match_threshold double precision, max_results integer);

drop function if exists "public"."match_embedding_nimbus"(embedding public.vector, match_threshold double precision, max_results integer);

drop function if exists "public"."match_page_sections_v2"(embedding public.vector, match_threshold double precision, min_content_length integer);

drop function if exists "public"."match_page_sections_v2_nimbus"(embedding public.vector, match_threshold double precision, min_content_length integer);

drop view if exists "public"."tickets_view";

alter table "public"."feedback" drop constraint "feedback_pkey";

alter table "public"."incident_status_cache" drop constraint "incident_status_cache_pkey";

alter table "public"."last_changed" drop constraint "last_changed_pkey";

alter table "public"."launch_weeks" drop constraint "launch_weeks_pkey";

alter table "public"."meetups" drop constraint "meetups_pkey";

alter table "public"."page" drop constraint "page_pkey";

alter table "public"."page_nimbus" drop constraint "page_nimbus_pkey";

alter table "public"."page_section" drop constraint "page_section_pkey";

alter table "public"."page_section_nimbus" drop constraint "page_section_nimbus_pkey";

alter table "public"."tickets" drop constraint "tickets_pkey";

alter table "public"."troubleshooting_entries" drop constraint "troubleshooting_entries_pkey";

alter table "public"."validation_history" drop constraint "validation_history_pkey";

drop index if exists "public"."feedback_pkey";

drop index if exists "public"."fts_search_index_content_nimbus";

drop index if exists "public"."fts_search_index_page";

drop index if exists "public"."fts_search_index_title";

drop index if exists "public"."fts_search_index_title_nimbus";

drop index if exists "public"."idx_incident_status_cache_incident_id";

drop index if exists "public"."idx_incident_status_cache_shortlink";

drop index if exists "public"."idx_last_changed_parent_page_btree";

drop index if exists "public"."idx_troubleshooting_checksum";

drop index if exists "public"."incident_status_cache_incident_id_key";

drop index if exists "public"."incident_status_cache_pkey";

drop index if exists "public"."incident_status_cache_shortlink_key";

drop index if exists "public"."last_changed_parent_page_heading_key";

drop index if exists "public"."last_changed_pkey";

drop index if exists "public"."launch_weeks_pkey";

drop index if exists "public"."meetups_pkey";

drop index if exists "public"."page_nimbus_path_key";

drop index if exists "public"."page_nimbus_pkey";

drop index if exists "public"."page_path_key";

drop index if exists "public"."page_pkey";

drop index if exists "public"."page_section_nimbus_pkey";

drop index if exists "public"."page_section_pkey";

drop index if exists "public"."tickets_email_key";

drop index if exists "public"."tickets_pkey";

drop index if exists "public"."tickets_ticket_number_key";

drop index if exists "public"."tickets_username_key";

drop index if exists "public"."troubleshooting_entries_pkey";

drop index if exists "public"."validation_history_pkey";

drop index if exists "public"."validation_history_tag_created_at_idx";

drop table "public"."feedback";

drop table "public"."incident_status_cache";

drop table "public"."last_changed";

drop table "public"."launch_weeks";

drop table "public"."meetups";

drop table "public"."page";

drop table "public"."page_nimbus";

drop table "public"."page_section";

drop table "public"."page_section_nimbus";

drop table "public"."tickets";

drop table "public"."troubleshooting_entries";

drop table "public"."validation_history";

drop sequence if exists "public"."page_id_seq";

drop sequence if exists "public"."page_section_id_seq";


