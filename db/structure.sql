SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: aggregated_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.aggregated_metrics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    avg double precision,
    bucket timestamp(6) without time zone NOT NULL,
    count double precision,
    dimensions jsonb DEFAULT '{}'::jsonb,
    granularity character varying NOT NULL,
    max double precision,
    min double precision,
    name character varying NOT NULL,
    p50 double precision,
    p95 double precision,
    p99 double precision,
    project_id uuid NOT NULL,
    sum double precision
);


--
-- Name: alert_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alert_notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    alert_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    error_message text,
    notification_channel_id uuid NOT NULL,
    sent_at timestamp(6) without time zone,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: alert_rule_channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alert_rule_channels (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    alert_rule_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    notification_channel_id uuid NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: alert_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alert_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    aggregation character varying DEFAULT 'avg'::character varying,
    cooldown_minutes integer DEFAULT 60,
    created_at timestamp(6) without time zone NOT NULL,
    description text,
    enabled boolean DEFAULT true,
    endpoint character varying,
    environment character varying,
    last_checked_at timestamp(6) without time zone,
    last_triggered_at timestamp(6) without time zone,
    metric_name character varying,
    metric_type character varying NOT NULL,
    name character varying NOT NULL,
    operator character varying NOT NULL,
    project_id uuid NOT NULL,
    severity character varying DEFAULT 'warning'::character varying,
    status character varying DEFAULT 'ok'::character varying,
    threshold double precision NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    window_minutes integer DEFAULT 5
);


--
-- Name: alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alerts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    alert_rule_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    endpoint character varying,
    environment character varying,
    message text,
    metric_type character varying NOT NULL,
    operator character varying NOT NULL,
    project_id uuid NOT NULL,
    resolved_at timestamp(6) without time zone,
    severity character varying NOT NULL,
    status character varying DEFAULT 'firing'::character varying NOT NULL,
    threshold double precision NOT NULL,
    triggered_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    value double precision NOT NULL
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: metric_points; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metric_points (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    metric_id uuid NOT NULL,
    project_id uuid NOT NULL,
    tags jsonb DEFAULT '{}'::jsonb,
    "timestamp" timestamp(6) without time zone NOT NULL,
    value double precision NOT NULL
);


--
-- Name: metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metrics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    description text,
    kind character varying DEFAULT 'gauge'::character varying NOT NULL,
    name character varying NOT NULL,
    project_id uuid NOT NULL,
    tags jsonb DEFAULT '{}'::jsonb,
    unit character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notification_channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_channels (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    enabled boolean DEFAULT true,
    failure_count integer DEFAULT 0,
    kind character varying NOT NULL,
    last_used_at timestamp(6) without time zone,
    name character varying NOT NULL,
    project_id uuid NOT NULL,
    success_count integer DEFAULT 0,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    apdex_t double precision DEFAULT 0.5,
    created_at timestamp(6) without time zone NOT NULL,
    environment character varying DEFAULT 'live'::character varying,
    name character varying,
    platform_project_id character varying NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: spans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    data jsonb DEFAULT '{}'::jsonb,
    duration_ms double precision,
    ended_at timestamp(6) without time zone,
    error boolean DEFAULT false,
    error_class character varying,
    error_message text,
    kind character varying NOT NULL,
    name character varying NOT NULL,
    parent_span_id character varying,
    project_id uuid NOT NULL,
    span_id character varying NOT NULL,
    started_at timestamp(6) without time zone NOT NULL,
    trace_id uuid NOT NULL
);


--
-- Name: traces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traces (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action character varying,
    commit character varying,
    controller character varying,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    db_duration_ms double precision DEFAULT 0.0,
    duration_ms double precision,
    ended_at timestamp(6) without time zone,
    environment character varying,
    error boolean DEFAULT false,
    error_class character varying,
    error_message text,
    executions integer DEFAULT 1,
    external_duration_ms double precision DEFAULT 0.0,
    host character varying,
    job_class character varying,
    job_id character varying,
    kind character varying DEFAULT 'request'::character varying NOT NULL,
    name character varying NOT NULL,
    project_id uuid NOT NULL,
    queue character varying,
    queue_wait_ms double precision,
    request_id character varying,
    request_method character varying,
    request_path character varying,
    span_count integer DEFAULT 0,
    started_at timestamp(6) without time zone NOT NULL,
    status integer,
    trace_id character varying NOT NULL,
    user_id character varying,
    view_duration_ms double precision DEFAULT 0.0
);


--
-- Name: aggregated_metrics aggregated_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.aggregated_metrics
    ADD CONSTRAINT aggregated_metrics_pkey PRIMARY KEY (id);


--
-- Name: alert_notifications alert_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_notifications
    ADD CONSTRAINT alert_notifications_pkey PRIMARY KEY (id);


--
-- Name: alert_rule_channels alert_rule_channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_rule_channels
    ADD CONSTRAINT alert_rule_channels_pkey PRIMARY KEY (id);


--
-- Name: alert_rules alert_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_rules
    ADD CONSTRAINT alert_rules_pkey PRIMARY KEY (id);


--
-- Name: alerts alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alerts
    ADD CONSTRAINT alerts_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: metric_points metric_points_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metric_points
    ADD CONSTRAINT metric_points_pkey PRIMARY KEY (id);


--
-- Name: metrics metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics
    ADD CONSTRAINT metrics_pkey PRIMARY KEY (id);


--
-- Name: notification_channels notification_channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_channels
    ADD CONSTRAINT notification_channels_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: spans spans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spans
    ADD CONSTRAINT spans_pkey PRIMARY KEY (id);


--
-- Name: traces traces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traces
    ADD CONSTRAINT traces_pkey PRIMARY KEY (id);


--
-- Name: idx_agg_metrics_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agg_metrics_lookup ON public.aggregated_metrics USING btree (project_id, name, bucket, granularity);


--
-- Name: idx_alert_notifications_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_alert_notifications_unique ON public.alert_notifications USING btree (alert_id, notification_channel_id);


--
-- Name: idx_alert_rule_channels_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_alert_rule_channels_unique ON public.alert_rule_channels USING btree (alert_rule_id, notification_channel_id);


--
-- Name: idx_traces_job_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_traces_job_queue ON public.traces USING btree (project_id, queue, started_at);


--
-- Name: idx_traces_project_kind_started; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_traces_project_kind_started ON public.traces USING btree (project_id, kind, started_at);


--
-- Name: index_aggregated_metrics_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_aggregated_metrics_on_project_id ON public.aggregated_metrics USING btree (project_id);


--
-- Name: index_alert_notifications_on_alert_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alert_notifications_on_alert_id ON public.alert_notifications USING btree (alert_id);


--
-- Name: index_alert_notifications_on_notification_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alert_notifications_on_notification_channel_id ON public.alert_notifications USING btree (notification_channel_id);


--
-- Name: index_alert_notifications_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alert_notifications_on_status ON public.alert_notifications USING btree (status);


--
-- Name: index_alert_rule_channels_on_alert_rule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alert_rule_channels_on_alert_rule_id ON public.alert_rule_channels USING btree (alert_rule_id);


--
-- Name: index_alert_rule_channels_on_notification_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alert_rule_channels_on_notification_channel_id ON public.alert_rule_channels USING btree (notification_channel_id);


--
-- Name: index_alert_rules_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alert_rules_on_project_id ON public.alert_rules USING btree (project_id);


--
-- Name: index_alert_rules_on_project_id_and_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alert_rules_on_project_id_and_enabled ON public.alert_rules USING btree (project_id, enabled);


--
-- Name: index_alert_rules_on_project_id_and_metric_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alert_rules_on_project_id_and_metric_type ON public.alert_rules USING btree (project_id, metric_type);


--
-- Name: index_alert_rules_on_project_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alert_rules_on_project_id_and_status ON public.alert_rules USING btree (project_id, status);


--
-- Name: index_alerts_on_alert_rule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alerts_on_alert_rule_id ON public.alerts USING btree (alert_rule_id);


--
-- Name: index_alerts_on_alert_rule_id_and_triggered_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alerts_on_alert_rule_id_and_triggered_at ON public.alerts USING btree (alert_rule_id, triggered_at);


--
-- Name: index_alerts_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alerts_on_project_id ON public.alerts USING btree (project_id);


--
-- Name: index_alerts_on_project_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alerts_on_project_id_and_status ON public.alerts USING btree (project_id, status);


--
-- Name: index_alerts_on_project_id_and_triggered_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_alerts_on_project_id_and_triggered_at ON public.alerts USING btree (project_id, triggered_at);


--
-- Name: index_metric_points_on_metric_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_metric_points_on_metric_id ON public.metric_points USING btree (metric_id);


--
-- Name: index_metric_points_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_metric_points_on_project_id ON public.metric_points USING btree (project_id);


--
-- Name: index_metric_points_on_project_id_and_metric_id_and_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_metric_points_on_project_id_and_metric_id_and_timestamp ON public.metric_points USING btree (project_id, metric_id, "timestamp");


--
-- Name: index_metrics_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_metrics_on_project_id ON public.metrics USING btree (project_id);


--
-- Name: index_metrics_on_project_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_metrics_on_project_id_and_name ON public.metrics USING btree (project_id, name);


--
-- Name: index_notification_channels_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_channels_on_project_id ON public.notification_channels USING btree (project_id);


--
-- Name: index_notification_channels_on_project_id_and_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_channels_on_project_id_and_enabled ON public.notification_channels USING btree (project_id, enabled);


--
-- Name: index_notification_channels_on_project_id_and_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_channels_on_project_id_and_kind ON public.notification_channels USING btree (project_id, kind);


--
-- Name: index_notification_channels_on_project_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notification_channels_on_project_id_and_name ON public.notification_channels USING btree (project_id, name);


--
-- Name: index_projects_on_platform_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_platform_project_id ON public.projects USING btree (platform_project_id);


--
-- Name: index_spans_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spans_on_project_id ON public.spans USING btree (project_id);


--
-- Name: index_spans_on_span_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spans_on_span_id ON public.spans USING btree (span_id);


--
-- Name: index_spans_on_trace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spans_on_trace_id ON public.spans USING btree (trace_id);


--
-- Name: index_spans_on_trace_id_and_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spans_on_trace_id_and_started_at ON public.spans USING btree (trace_id, started_at);


--
-- Name: index_traces_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traces_on_project_id ON public.traces USING btree (project_id);


--
-- Name: index_traces_on_project_id_and_name_and_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traces_on_project_id_and_name_and_started_at ON public.traces USING btree (project_id, name, started_at);


--
-- Name: index_traces_on_project_id_and_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traces_on_project_id_and_started_at ON public.traces USING btree (project_id, started_at);


--
-- Name: index_traces_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traces_on_request_id ON public.traces USING btree (request_id);


--
-- Name: index_traces_on_trace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_traces_on_trace_id ON public.traces USING btree (trace_id);


--
-- Name: alert_rules fk_rails_0b3fcf55ac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_rules
    ADD CONSTRAINT fk_rails_0b3fcf55ac FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: alert_rule_channels fk_rails_26122be083; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_rule_channels
    ADD CONSTRAINT fk_rails_26122be083 FOREIGN KEY (alert_rule_id) REFERENCES public.alert_rules(id);


--
-- Name: metrics fk_rails_68c661ff7b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metrics
    ADD CONSTRAINT fk_rails_68c661ff7b FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: alerts fk_rails_7814415382; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alerts
    ADD CONSTRAINT fk_rails_7814415382 FOREIGN KEY (alert_rule_id) REFERENCES public.alert_rules(id);


--
-- Name: spans fk_rails_9fb60f666f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spans
    ADD CONSTRAINT fk_rails_9fb60f666f FOREIGN KEY (trace_id) REFERENCES public.traces(id);


--
-- Name: alert_rule_channels fk_rails_afbb1dd2e3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_rule_channels
    ADD CONSTRAINT fk_rails_afbb1dd2e3 FOREIGN KEY (notification_channel_id) REFERENCES public.notification_channels(id);


--
-- Name: notification_channels fk_rails_d6ab742d00; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_channels
    ADD CONSTRAINT fk_rails_d6ab742d00 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: alert_notifications fk_rails_da77c26538; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_notifications
    ADD CONSTRAINT fk_rails_da77c26538 FOREIGN KEY (notification_channel_id) REFERENCES public.notification_channels(id);


--
-- Name: alerts fk_rails_dd195b3421; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alerts
    ADD CONSTRAINT fk_rails_dd195b3421 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: spans fk_rails_e847520880; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spans
    ADD CONSTRAINT fk_rails_e847520880 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: traces fk_rails_e84c752022; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traces
    ADD CONSTRAINT fk_rails_e84c752022 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: alert_notifications fk_rails_ee7a462e3e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alert_notifications
    ADD CONSTRAINT fk_rails_ee7a462e3e FOREIGN KEY (alert_id) REFERENCES public.alerts(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20251229062459'),
('20251223200000'),
('20251223023220'),
('20251223020446'),
('20251223015307'),
('20251223015233'),
('20251223015215'),
('20241222000002'),
('20241222000001'),
('20241221000006'),
('20241221000005'),
('20241221000004'),
('20241221000003'),
('20241221000002'),
('20241221000001');

