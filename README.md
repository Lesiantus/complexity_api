ruby 3.4.1

Dictionary Complexity Score API – Documentation
Overview

Calculates a “complexity score” for words using definitions, synonyms, and antonyms from a dictionary API.
Processing is asynchronous: HTTP request triggers a Sidekiq worker that handles batching, retries, and rate-limit handling.

Endpoints
POST /complexity_score

Accepts JSON array of words.

Returns immediately:

{ "job_id": 123 }


Worker handles computation asynchronously.

Invalid input → 400 Bad Request.

GET /complexity_score/:id

Returns job status and results:
In Progress:

{ "status": "in_progress", "processed": 4, "total": 10 }


Completed:

{ "status": "completed", "result": { "cat": 1.0, "book": 0.75 }, "completed_at": "2025-10-28T15:00:00Z" }


Failed:

{ "status": "failed", "error": "API unreachable", "completed_at": "2025-10-28T15:05:00Z" }

Architecture

Controller: validates input, creates job, triggers Sidekiq worker.

Worker: processes words in batches, calls DictionaryClient, computes scores, updates DB, handles rate-limits.

DictionaryClient: pure HTTP + JSON parsing, no blocking or retries.

Database: stores job status, input, results.

Client: polls GET endpoint for status/results.

Scoring
score = (synonyms + antonyms) / definitions


Rounded to 2 decimal places.

Words with zero definitions → score 0.

Efficiency & Reliability

Batching reduces API load.

Delayed retries handle rate-limits.
