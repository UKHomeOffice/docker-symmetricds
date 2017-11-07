CREATE TABLE "test"
(
  "id" SERIAL PRIMARY KEY,
  "name" VARCHAR(256),
  "date" DATE
);

INSERT INTO "test"
(
  "name",
  "date"
)
VALUES
(
  'foo',
  '2017-07-24'
),
(
  'bar',
  '2017-05-31'
),
(
  'baz',
  '1958-09-29'
),
(
  'quz',
  '1913-07-06'
);


CREATE TABLE "other_table"
(
  "id" SERIAL PRIMARY KEY,
  "name" VARCHAR(256),
  "date" DATE
);

INSERT INTO "other_table"
(
  "name",
  "date"
)
VALUES
(
  'foo',
  '1900-07-24'
),
(
  'bar',
  '1900-05-31'
),
(
  'baz',
  '1900-09-29'
),
(
  'quz',
  '1900-07-06'
);
