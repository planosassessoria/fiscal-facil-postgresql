-- This file contains the SQL query for inserting a roadmap event into the history.roadmap_events table.
-- It is used to log significant actions and changes related to the roadmap, such as creation, updates, and deletions of roadmap items, along with relevant metadata for auditing and tracking purposes.
INSERT INTO history.roadmap_events (
	tenant_id,
	user_email,
	tax_id,
	est_id,
	category,
	action_type,
	description,
	payload_before,
	payload_after,
	metadata,
	event_scope
)
VALUES (
	$1,
	$2,
	$3,
	$4,
	$5,
	$6,
	$7,
	$8,
	$9,
	$10,
	$11
);
