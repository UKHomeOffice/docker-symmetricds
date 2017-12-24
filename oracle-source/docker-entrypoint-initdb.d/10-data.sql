WHENEVER SQLERROR EXIT;

COLUMN v NEW_VALUE username
  SELECT COALESCE(SYS.GET_ENV('ORACLE_USER'), 'oracle') AS v
  FROM DUAL;

ALTER SESSION SET current_schema = &username;

CREATE TABLE test
(
  id NUMBER PRIMARY KEY,
  name VARCHAR2(256),
  "date" DATE
);

INSERT INTO test
(
  id,
  name,
  "date"
)
VALUES
(
  1,
  'foo',
  date '2017-07-24'
);

INSERT INTO test
(
  id,
  name,
  "date"
)
VALUES
(
  2,
  'bar',
  date '2017-05-31'
);

INSERT INTO test
(
  id,
  name,
  "date"
)
VALUES
(
  3,
  'baz',
  date '1958-09-29'
);

INSERT INTO test
(
  id,
  name,
  "date"
)
VALUES
(
  4,
  'quz',
  date '1913-07-06'
);
